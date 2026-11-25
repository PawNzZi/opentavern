import 'dart:convert';

import '../data/demo.dart';
import 'models.dart';
import 'store.dart';

/// 世界书「状态栏」——兼容多种角色卡格式。
///
/// 调研社区常见写法后归纳为几类：
///  * MVU 变量更新：`<UpdateVariable><JSONPatch>[…]</JSONPatch></UpdateVariable>`，
///    初始值在世界书 `[InitVar]`，输出的是差分，需要累积到变量树。
///  * 包裹标签整段状态：`<state>`/`<status>`/`<status_bar>`/`<StatusBar>`/
///    `<状态栏>`/`<角色状态>` 等，里面是 YAML/键值/管道表，输出的是完整状态。
///  * 代码块状态栏：``` 围栏里的键值或 `| 健康: 90 | 理智: 80 |` 管道表。
///  * 非 MVU 变量：`{{setvar}}`/`{{getvar}}`/`{{addvar}}` 宏（由 MacroEngine 处理）。
///
/// 这里负责：识别并剥离各种状态块（正文与状态栏分开显示）、把整段状态解析成
/// 字段、应用 MVU 差分、解析初始值，以及把当前变量格式化回 prompt。标签形态
/// （文字描述 / 标签 / 数值进度）由 UI 按值类型自适应渲染。
class StatusBar {
  static final _updateBlock = RegExp(
    r'<UpdateVariable(?:variable)?>[\s\S]*?</UpdateVariable(?:variable)?>',
    caseSensitive: false,
  );
  static final _jsonPatch = RegExp(
    r'<JSONPatch>([\s\S]*?)</JSONPatch>',
    caseSensitive: false,
  );

  /// 常见的「整段状态」包裹标签（大小写不敏感，含中文标签）。
  /// 含常见下划线变体（Status_block / status_block / FullVariableUpdate 等）。
  static final _displayBlock = RegExp(
    r'<(status_block|status_bar|statusbar|statusblock|status_top|status_top_bar|character_status|status_panel|statuspanel|fullvariableupdate|variableupdate|status|state|状态栏|角色状态|当前状态|状态)(?:\s[^>]*)?>([\s\S]*?)</\1>',
    caseSensitive: false,
  );

  /// MVU 前端占位符与阶段路由标记：只剥离，不作为状态展示。
  static final _placeholder = RegExp(r'<StatusPlaceHolderImpl\s*/>', caseSensitive: false);
  static final _routeState = RegExp(r'<route_state>[\s\S]*?</route_state>', caseSensitive: false);

  static final _codeFence = RegExp(r'```[a-zA-Z]*\n?([\s\S]*?)```');

  /// 任意包裹标签块（标签名不限，含中文标签），用于适配白名单之外的自定义状态标签。
  static final _anyTagBlock = RegExp(
    r'<([A-Za-z_\u4e00-\u9fff][\w\u4e00-\u9fff-]*)[^>]*>([\s\S]*?)</\1>',
  );

  /// 这些标签由专门逻辑处理，generic 检测时跳过。
  static const _specialTags = {
    'updatevariable', 'updatevariablevariable', 'route_state', 'jsonpatch',
    'analysis', 'start', 'user', 'char', 'system', 'assistant',
  };

  /// 从角色卡自带的 regex_scripts 提取 findRegex 模式。
  ///
  /// 调研结论：状态栏的识别规则写在卡自己的 `data.extensions.regex_scripts`
  /// 里，硬编码标签白名单永远追不上新卡。这里把卡作者定义的匹配模式拿来用，
  /// 才能对任意卡自适应。rawJson 为整卡 JSON（DemoCharacter.rawJson）。
  static List<RegExp> cardPatterns(Map<String, dynamic>? rawJson) {
    if (rawJson == null) return const [];
    final data = rawJson['data'] is Map ? rawJson['data'] as Map : rawJson;
    final ext = data['extensions'];
    dynamic scripts;
    if (ext is Map) scripts = ext['regex_scripts'];
    scripts ??= data['regex_scripts'];
    if (scripts is! List) return const [];
    final out = <RegExp>[];
    for (final s in scripts) {
      if (s is! Map) continue;
      final re = _compileFind((s['findRegex'] ?? '').toString());
      if (re != null) out.add(re);
    }
    return out;
  }

  /// 按角色名取卡自带状态识别模式（带缓存），供显示层剥离使用。
  static final Map<String, List<RegExp>> _nameCache = {};
  static List<RegExp> patternsForCharacterName(String name) {
    final cached = _nameCache[name];
    if (cached != null) return cached;
    DemoCharacter? c;
    for (final ch in AppStore.instance.characters) {
      if (ch.name == name) {
        c = ch;
        break;
      }
    }
    final patterns = cardPatterns(c?.rawJson);
    _nameCache[name] = patterns;
    return patterns;
  }

  static RegExp? _compileFind(String find) {    var pattern = find.trim();
    if (pattern.isEmpty) return null;
    var flags = '';
    if (pattern.startsWith('/') && pattern.lastIndexOf('/') > 0) {
      final last = pattern.lastIndexOf('/');
      flags = pattern.substring(last + 1);
      pattern = pattern.substring(1, last);
    }
    try {
      return RegExp(
        pattern,
        caseSensitive: !flags.contains('i'),
        multiLine: flags.contains('m'),
        dotAll: flags.contains('s'),
      );
    } catch (_) {
      return null;
    }
  }

  /// 去掉单层外层包裹标签，取内部内容。
  static String _unwrap(String block) {
    final t = block.trim();
    final m = RegExp(
      r'^<([A-Za-z_\u4e00-\u9fff][\w\u4e00-\u9fff-]*)[^>]*>([\s\S]*?)</\1>$',
    ).firstMatch(t);
    return m != null ? (m.group(2) ?? t) : t;
  }

  /// 内容是否「富文本」状态栏（含 HTML 结构或代码围栏），这类无法拆成简单字段，
  /// 按原文展示更忠实。
  static bool _isRichContent(String content) {
    if (content.contains('```')) return true;
    return RegExp(
      r'</?(details|summary|div|span|br|ul|ol|li|table|tr|td|th|p|b|i|strong|em|section)\b',
      caseSensitive: false,
    ).hasMatch(content);
  }

  /// 清掉富文本里的 HTML 标签/代码围栏，得到可读的状态栏文本。
  static String _sanitizeRaw(String content) {
    var c = content;
    c = c.replaceAll(RegExp(r'```[a-zA-Z]*\n?'), '').replaceAll('```', '');
    c = c.replaceAllMapped(
      RegExp(r'<summary>([\s\S]*?)</summary>', caseSensitive: false),
      (m) => m.group(1) ?? '',
    );
    c = c.replaceAll(RegExp(r'<[^>]+>'), '');
    final lines = c
        .split('\n')
        .map((l) => l.trimRight())
        .where((l) => l.trim().isNotEmpty)
        .toList();
    return lines.join('\n').trim();
  }

  /// 判断一段匹配文本是否为状态块：富文本或能解析出 ≥2 个字段都算。
  static bool _isStatusContent(String inner) {
    final c = _unwrap(inner);
    if (_isRichContent(c)) return true;
    final parsed = parseContent(c);
    return parsed != null && parsed.length >= 2;
  }

  /// 把状态块内容转成展示数据：富文本/无法解析 → `{'__raw__': 文本}`，
  /// 否则返回解析出的字段树。没有内容返回 null。
  static Map<String, dynamic>? _statusFromContent(String content) {
    final c = content.trim();
    if (c.isEmpty) return null;
    if (_isRichContent(c)) return {'__raw__': _sanitizeRaw(c)};
    final parsed = parseContent(c);
    if (parsed != null && parsed.length >= 2) return parsed;
    return {'__raw__': _sanitizeRaw(c)};
  }

  /// 从正文中剥离各种状态块，只留下故事内容（用于显示与发送）。
  /// [cardPatterns] 为角色卡自带 regex_scripts 的匹配模式（可选）。
  static String strip(String text, {List<RegExp> cardPatterns = const []}) {
    if (!text.contains('<') && !text.contains('```') && !text.contains('|')) {
      return text;
    }
    var result = text
        .replaceAll(_updateBlock, '')
        .replaceAll(_displayBlock, '')
        .replaceAll(_placeholder, '')
        .replaceAll(_routeState, '');
    // 卡自带规则：只剥离匹配出来确属状态块的部分，避免误删正文。
    for (final re in cardPatterns) {
      result = result.replaceAllMapped(re, (m) {
        final matched = m.group(0) ?? '';
        return _isStatusContent(matched) ? '' : matched;
      });
    }
    // 任意自定义标签的状态块（白名单之外）。
    result = result.replaceAllMapped(_anyTagBlock, (m) {
      final tag = (m.group(1) ?? '').toLowerCase();
      if (_specialTags.contains(tag)) return m.group(0)!;
      return _isStatusContent(m.group(2) ?? '') ? '' : m.group(0)!;
    });
    result = _stripStatusFences(result);
    result = _stripTrailingPipe(result);
    // 流式输出时状态块可能尚未闭合：把末尾未闭合的包裹标签也去掉，避免闪现。
    final open = RegExp(
      r'<(UpdateVariable(?:variable)?|status_block|status_bar|statusbar|statusblock|status_top|character_status|statuspanel|fullvariableupdate|variableupdate|status|state|状态栏|角色状态|当前状态|状态)(?:\s[^>]*)?>',
      caseSensitive: false,
    );
    final idx = result.lastIndexOf(open);
    if (idx >= 0) result = result.substring(0, idx);
    return result.trimRight();
  }

  /// 回复里是否带有 MVU 变量更新块。
  static bool hasUpdate(String text) => _updateBlock.hasMatch(text);

  /// 提取「整段状态」（非 MVU）：卡自带规则 / 包裹标签 / 任意自定义标签 /
  /// 状态代码块 / 末尾管道表。返回解析出的字段树；无可识别状态块时返回 null。
  static Map<String, dynamic>? extractStatus(
    String text, {
    List<RegExp> cardPatterns = const [],
  }) {
    // 1) 卡自带 regex 规则优先（最贴合该卡）。
    for (final re in cardPatterns) {
      final m = re.firstMatch(text);
      if (m == null) continue;
      final matched = m.group(0) ?? '';
      final inner = m.groupCount >= 1 ? (m.group(1) ?? matched) : matched;
      final result = _statusFromContent(_unwrap(inner));
      if (result != null) return result;
    }
    // 2) 常见包裹标签。
    final m = _displayBlock.firstMatch(text);
    if (m != null) {
      final result = _statusFromContent(m.group(2) ?? '');
      if (result != null) return result;
    }
    // 3) 任意自定义标签（内容像状态）。
    for (final t in _anyTagBlock.allMatches(text)) {
      final tag = (t.group(1) ?? '').toLowerCase();
      if (_specialTags.contains(tag)) continue;
      final content = t.group(2) ?? '';
      if (!_isStatusContent(content)) continue;
      final result = _statusFromContent(content);
      if (result != null) return result;
    }
    // 4) 状态代码块。
    for (final f in _codeFence.allMatches(text)) {
      final content = f.group(1) ?? '';
      if (_looksLikeStatus(content)) {
        final parsed = parseContent(content);
        if (parsed != null && parsed.isNotEmpty) return parsed;
      }
    }
    // 5) 末尾管道表。
    final pipe = _trailingPipeFields(text);
    if (pipe.length >= 2) return pipe;
    return null;
  }

  /// 把状态块内部文本解析成字段树：JSON / 管道表 / 内嵌 <键>值</键> / YAML 键值。
  static Map<String, dynamic>? parseContent(String content) {
    final c = content.trim();
    if (c.isEmpty) return null;
    if (c.startsWith('{')) {
      try {
        final d = jsonDecode(c);
        if (d is Map && d.isNotEmpty) return Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    if (c.contains('|')) {
      final pipe = _parsePipe(c);
      if (pipe.isNotEmpty) return pipe;
    }
    final tagFields = <String, dynamic>{};
    for (final m in RegExp(r'<([\w\u4e00-\u9fff]+)>([^<]*)</\1>').allMatches(c)) {
      final v = m.group(2)!.trim();
      if (v.isNotEmpty) tagFields[m.group(1)!] = _parseScalar(v);
    }
    if (tagFields.isNotEmpty) return tagFields;
    // 【键】值 / [键] 值 形式。
    final bracket = <String, dynamic>{};
    for (final m in RegExp(r'[【\[]([^】\]\n]+)[】\]]\s*[:：=]?\s*([^\n【\[]+)')
        .allMatches(c)) {
      final v = m.group(2)!.trim();
      if (v.isNotEmpty) bracket[m.group(1)!.trim()] = _parseScalar(v);
    }
    if (bracket.length >= 2) return bracket;
    final yaml = parseInit(c);
    if (yaml.isNotEmpty) return yaml;
    final flat = _parseFlat(c);
    if (flat.length >= 2) return flat;
    return null;
  }

  static String _stripStatusFences(String text) {
    return text.replaceAllMapped(_codeFence, (m) {
      final content = m.group(1) ?? '';
      return _looksLikeStatus(content) ? '' : m.group(0)!;
    });
  }

  static String _stripTrailingPipe(String text) {
    final fields = _trailingPipeFields(text);
    if (fields.length < 2) return text;
    final lines = text.trimRight().split('\n');
    var end = lines.length;
    while (end > 0) {
      final l = lines[end - 1].trim();
      if (l.isEmpty) {
        end--;
      } else if (l.contains('|') && _parsePipe(l).isNotEmpty) {
        end--;
      } else {
        break;
      }
    }
    return lines.sublist(0, end).join('\n').trimRight();
  }

  static Map<String, dynamic> _trailingPipeFields(String text) {
    final lines = text.trimRight().split('\n');
    final pipeLines = <String>[];
    for (var i = lines.length - 1; i >= 0; i--) {
      final l = lines[i].trim();
      if (l.isEmpty) continue;
      if (l.contains('|') && _parsePipe(l).isNotEmpty) {
        pipeLines.insert(0, l);
      } else {
        break;
      }
    }
    return pipeLines.isEmpty ? {} : _parsePipe(pipeLines.join('\n'));
  }

  static Map<String, dynamic> _parsePipe(String content) {
    final fields = <String, dynamic>{};
    for (final line in content.split('\n')) {
      if (!line.contains('|')) continue;
      final cells = line
          .split('|')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (cells.isEmpty) continue;
      // 跳过 markdown 分隔行（--- / :--:）。
      if (cells.every((e) => RegExp(r'^[-:\s]+$').hasMatch(e))) continue;
      // 两列 markdown 表：| 键 | 值 |。
      if (cells.length == 2 &&
          _splitKeyValue(cells[0]) == null &&
          _splitKeyValue(cells[1]) == null) {
        fields[cells[0]] = _parseScalar(cells[1]);
        continue;
      }
      for (final cell in cells) {
        final kv = _splitKeyValue(cell);
        if (kv != null) fields[kv.$1] = _parseScalar(kv.$2);
      }
    }
    return fields;
  }

  static (String, String)? _splitKeyValue(String s) {
    if (s.isEmpty) return null;
    for (final sep in [':', '：', '=']) {
      final i = s.indexOf(sep);
      if (i > 0) {
        final key = s.substring(0, i).trim();
        final val = s.substring(i + sep.length).trim();
        if (key.isNotEmpty && val.isNotEmpty) return (key, val);
      }
    }
    return null;
  }

  /// 扁平行解析：`键: 值` / `键：值` / `键=值` / `- 键: 值`，忽略缩进。
  static Map<String, dynamic> _parseFlat(String content) {
    final fields = <String, dynamic>{};
    for (final raw in content.split('\n')) {
      var line = raw.trim();
      if (line.startsWith('- ')) line = line.substring(2).trim();
      if (line.startsWith('* ')) line = line.substring(2).trim();
      final kv = _splitKeyValue(line);
      if (kv != null) fields[kv.$1] = _parseScalar(kv.$2);
    }
    return fields;
  }

  /// 保守判断一段代码围栏内容是否像状态栏（避免误删普通代码）：
  /// 管道表 ≥2 字段，或含中文键的键值对 ≥2 个。
  static bool _looksLikeStatus(String content) {
    final c = content.trim();
    if (c.isEmpty) return false;
    if (c.contains('|') && _parsePipe(c).length >= 2) return true;
    final parsed = parseContent(c);
    if (parsed == null || parsed.length < 2) return false;
    bool hasCjk(String s) => s.runes.any((r) => r >= 0x4E00 && r <= 0x9FFF);
    return parsed.keys.any(hasCjk);
  }

  /// 提取回复中的 JSON-Patch 操作数组（无则返回空）。
  static List<Map<String, dynamic>> extractOps(String text) {
    final block = _updateBlock.firstMatch(text);
    if (block == null) return const [];
    final patch = _jsonPatch.firstMatch(block.group(0)!);
    if (patch == null) return const [];
    var raw = patch.group(1)!.trim();
    // 模型可能再包一层 ```json 代码围栏。
    raw = raw
        .replaceAll(RegExp(r'^```[a-zA-Z]*\s*'), '')
        .replaceAll(RegExp(r'\s*```$'), '')
        .trim();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  /// 把 JSON-Patch 操作应用到嵌套变量树，返回新的树（不修改入参）。
  /// 支持 replace / delta / insert / remove / move；跳过 `_` 开头的只读字段。
  static Map<String, dynamic> applyOps(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> ops,
  ) {
    final root = _deepCopy(data);
    for (final op in ops) {
      final kind = (op['op'] ?? '').toString().toLowerCase();
      // move 的目的地写在 `to`，其余操作写在 `path`。
      final pathStr = kind == 'move'
          ? (op['to']?.toString() ?? '')
          : (op['path']?.toString() ?? '');
      final segments = _segments(pathStr);
      if (segments.isEmpty) continue;
      if (segments.any((s) => s.startsWith('_'))) continue;
      switch (kind) {
        case 'replace':
        case 'insert':
          _setPath(root, segments, op['value']);
        case 'delta':
          final delta = _asNum(op['value']);
          if (delta == null) break;
          final cur = _asNum(_getPath(root, segments));
          _setPath(root, segments, (cur ?? 0) + delta);
        case 'remove':
          _removePath(root, segments);
        case 'move':
          final from = _segments(op['from']?.toString() ?? '');
          if (from.isEmpty) break;
          final val = _getPath(root, from);
          _removePath(root, from);
          _setPath(root, segments, val);
      }
    }
    return root;
  }

  /// 解析 `[InitVar]` 的缩进式 YAML 初始值为嵌套 Map。
  static Map<String, dynamic> parseInit(String content) {
    final root = <String, dynamic>{};
    final stack = <(int, Map<String, dynamic>)>[(-1, root)];
    for (final rawLine in content.split('\n')) {
      final line = rawLine.replaceAll('\t', '  ');
      if (line.trim().isEmpty || line.trim().startsWith('#')) continue;
      final indent = line.length - line.trimLeft().length;
      final trimmed = line.trim();
      final colon = trimmed.indexOf(':');
      if (colon <= 0) continue;
      final key = trimmed.substring(0, colon).trim();
      final value = trimmed.substring(colon + 1).trim();
      while (stack.length > 1 && stack.last.$1 >= indent) {
        stack.removeLast();
      }
      final parent = stack.last.$2;
      if (value.isEmpty) {
        final child = <String, dynamic>{};
        parent[key] = child;
        stack.add((indent, child));
      } else {
        parent[key] = _parseScalar(value);
      }
    }
    return root;
  }

  /// 从「变量更新规则」里提取每个数值字段的范围（path → max），供进度条使用。
  static Map<String, num> parseRanges(String content) {
    final ranges = <String, num>{};
    final stack = <(int, String)>[(-1, '')];
    String? pendingPath;
    for (final rawLine in content.split('\n')) {
      final line = rawLine.replaceAll('\t', '  ');
      if (line.trim().isEmpty) continue;
      final indent = line.length - line.trimLeft().length;
      final trimmed = line.trim();
      final colon = trimmed.indexOf(':');
      if (colon <= 0) continue;
      final key = trimmed.substring(0, colon).trim();
      final value = trimmed.substring(colon + 1).trim();
      while (stack.length > 1 && stack.last.$1 >= indent) {
        stack.removeLast();
      }
      final parentPath = stack.last.$2;
      final path = parentPath.isEmpty ? key : '$parentPath/$key';
      if (value.isEmpty) {
        stack.add((indent, path));
        pendingPath = path;
      } else if (key == 'range') {
        final m = RegExp(r'(\d+)\s*[~～-]\s*(\d+)').firstMatch(value);
        if (m != null && pendingPath != null) {
          ranges[pendingPath] = num.parse(m.group(2)!);
        }
      }
    }
    // 规则文本通常包一层根键（如「变量更新规则:」），去掉这层前缀，
    // 使路径与 stat_data 数据树（郑怡云/攻略阶段…）对齐。
    final roots = ranges.keys.map((k) => k.split('/').first).toSet();
    if (roots.length == 1 && ranges.isNotEmpty) {
      final prefix = '${roots.first}/';
      final normalized = <String, num>{};
      ranges.forEach((k, v) {
        normalized[k.startsWith(prefix) ? k.substring(prefix.length) : k] = v;
      });
      return normalized;
    }
    return ranges;
  }

  /// 把变量树格式化为缩进文本，注入 prompt（{{format_message_variable::stat_data}}）。
  static String format(Map<String, dynamic> data) {
    // 富文本状态栏直接返回原文。
    final raw = data['__raw__'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    final buffer = StringBuffer();
    void walk(Map<String, dynamic> node, int depth) {
      node.forEach((key, value) {
        final pad = '  ' * depth;
        if (value is Map) {
          buffer.writeln('$pad$key:');
          walk(Map<String, dynamic>.from(value), depth + 1);
        } else {
          buffer.writeln('$pad$key: $value');
        }
      });
    }

    walk(data, 0);
    return buffer.toString().trimRight();
  }

  /// 在角色绑定的世界书里查找 [InitVar] 初始值条目（含被停用的初始化条目）。
  static String? findInitContent(DemoCharacter character) {
    for (final book in AppStore.instance.lorebooks) {
      if (!_inScope(character, book)) continue;
      for (final e in book.entries) {
        if ('${e.name} ${e.comment}'.contains('InitVar')) {
          return e.content;
        }
      }
    }
    return null;
  }

  /// 查找「变量更新规则」条目，用于解析数值范围。
  static String? findRulesContent(DemoCharacter character) {
    for (final book in AppStore.instance.lorebooks) {
      if (!_inScope(character, book)) continue;
      for (final e in book.entries) {
        if ('${e.name} ${e.comment}'.contains('变量更新规则')) {
          return e.content;
        }
      }
    }
    return null;
  }

  static bool _inScope(DemoCharacter character, Lorebook book) {
    if (book.isGlobal) return true;
    final linked = (book.linked ?? '').trim();
    if (linked.isNotEmpty && linked == character.name) return true;
    final bound = character.lorebook.trim();
    if (bound.isEmpty || bound == '未绑定') return false;
    return bound == book.name || bound == book.id;
  }

  // ---- 内部工具 ----

  static List<String> _segments(String path) {
    var parts = path.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.isNotEmpty && parts.first == 'stat_data') {
      parts = parts.sublist(1);
    }
    return parts;
  }

  static Map<String, dynamic> _deepCopy(Map<String, dynamic> src) {
    final out = <String, dynamic>{};
    src.forEach((k, v) {
      out[k] = v is Map ? _deepCopy(Map<String, dynamic>.from(v)) : v;
    });
    return out;
  }

  static dynamic _getPath(Map<String, dynamic> root, List<String> segs) {
    dynamic node = root;
    for (final s in segs) {
      if (node is Map && node.containsKey(s)) {
        node = node[s];
      } else {
        return null;
      }
    }
    return node;
  }

  static void _setPath(Map<String, dynamic> root, List<String> segs, dynamic value) {
    var node = root;
    for (var i = 0; i < segs.length - 1; i++) {
      final next = node[segs[i]];
      if (next is Map<String, dynamic>) {
        node = next;
      } else if (next is Map) {
        final cast = Map<String, dynamic>.from(next);
        node[segs[i]] = cast;
        node = cast;
      } else {
        final child = <String, dynamic>{};
        node[segs[i]] = child;
        node = child;
      }
    }
    node[segs.last] = value;
  }

  static void _removePath(Map<String, dynamic> root, List<String> segs) {
    var node = root;
    for (var i = 0; i < segs.length - 1; i++) {
      final next = node[segs[i]];
      if (next is Map<String, dynamic>) {
        node = next;
      } else if (next is Map) {
        final cast = Map<String, dynamic>.from(next);
        node[segs[i]] = cast;
        node = cast;
      } else {
        return;
      }
    }
    node.remove(segs.last);
  }

  static num? _asNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse('$v');
  }

  static dynamic _parseScalar(String value) {
    final v = value.trim();
    if (v == 'true') return true;
    if (v == 'false') return false;
    final n = num.tryParse(v);
    if (n != null) return n;
    if ((v.startsWith('"') && v.endsWith('"')) ||
        (v.startsWith("'") && v.endsWith("'"))) {
      return v.substring(1, v.length - 1);
    }
    return v;
  }
}
