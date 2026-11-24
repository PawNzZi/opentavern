import 'dart:convert';

import '../data/demo.dart';
import 'models.dart';
import 'store.dart';

/// 世界书「状态栏」（MVU 风格变量系统）。
///
/// 一些角色卡的世界书用一棵嵌套变量树 `stat_data` 记录时间、角色状态等，
/// 初始值放在 `[InitVar]` 条目里，模型则在每条回复末尾追加
/// `<UpdateVariable><JSONPatch>[…]</JSONPatch></UpdateVariable>` 来更新变量。
///
/// 这里负责：解析初始值、应用 JSON-Patch 更新、从正文里剥离状态块（正文与
/// 状态栏分开显示），以及把当前变量格式化回 prompt。状态栏的「标签形态」
/// （文字描述 / 标签 / 数值进度）由 UI 按值类型自适应渲染。
class StatusBar {
  static final _updateBlock = RegExp(
    r'<UpdateVariable>[\s\S]*?</UpdateVariable>',
    caseSensitive: false,
  );
  static final _jsonPatch = RegExp(
    r'<JSONPatch>([\s\S]*?)</JSONPatch>',
    caseSensitive: false,
  );

  /// 从正文中剥离状态/变量更新块，只留下故事内容（用于显示与发送）。
  static String strip(String text) {
    if (!text.contains('<')) return text;
    var result = text.replaceAll(_updateBlock, '');
    // 流式输出时状态块可能尚未闭合：把末尾未闭合的 <UpdateVariable>… 也去掉，
    // 避免原始标签在气泡里闪现。
    final idx = result.lastIndexOf(RegExp(r'<UpdateVariable>', caseSensitive: false));
    if (idx >= 0) result = result.substring(0, idx);
    return result.trimRight();
  }

  /// 回复里是否带有状态更新块。
  static bool hasUpdate(String text) => _updateBlock.hasMatch(text);

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
