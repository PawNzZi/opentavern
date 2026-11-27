import 'dart:async';
import 'dart:convert';

import '../llm.dart';
import '../models.dart';
import 'novel_types.dart';

/// L2 归并后的一个人物档案。
class MergedCharacter {
  MergedCharacter({
    required this.name,
    Set<String>? aliases,
    this.mentions = 0,
    List<String>? appearance,
    List<String>? personality,
    List<String>? relationship,
    List<String>? speechStyle,
    this.role = '',
  })  : aliases = aliases ?? <String>{},
        appearance = appearance ?? [],
        personality = personality ?? [],
        relationship = relationship ?? [],
        speechStyle = speechStyle ?? [];

  final String name;
  final Set<String> aliases;

  /// 被多少个块提到（戏份权重）。
  int mentions;
  final List<String> appearance;
  final List<String> personality;
  final List<String> relationship;
  final List<String> speechStyle;
  String role;

  String get profileText {
    String join(List<String> parts) {
      final seen = <String>{};
      final out = <String>[];
      for (final p in parts) {
        final t = p.trim();
        if (t.isEmpty || seen.contains(t)) continue;
        seen.add(t);
        out.add(t);
        if (out.join('；').length > 400) break;
      }
      return out.join('；');
    }

    return [
      '姓名：$name',
      if (aliases.isNotEmpty) '别名/称谓：${aliases.take(8).join('、')}',
      if (role.isNotEmpty) '定位：$role',
      if (appearance.isNotEmpty) '外貌：${join(appearance)}',
      if (personality.isNotEmpty) '性格：${join(personality)}',
      if (relationship.isNotEmpty) '关系：${join(relationship)}',
      if (speechStyle.isNotEmpty) '说话风格：${join(speechStyle)}',
      '出场块数：$mentions',
    ].join('\n');
  }
}

/// L2 归并后的一条世界设定。
class MergedLore {
  MergedLore({
    required this.topic,
    Set<String>? keys,
    List<String>? contents,
    this.category = '',
    this.constant = false,
    this.mentions = 0,
  })  : keys = keys ?? <String>{},
        contents = contents ?? [];

  final String topic;
  final Set<String> keys;
  final List<String> contents;
  String category;
  bool constant;
  int mentions;

  String get content {
    final seen = <String>{};
    final out = <String>[];
    for (final c in contents) {
      final t = c.trim();
      if (t.isEmpty || seen.contains(t)) continue;
      seen.add(t);
      out.add(t);
      if (out.join('\n').length > 600) break;
    }
    return out.join('\n');
  }
}

/// 小说 → 角色卡/世界书 的生成引擎。
///
/// 三段式：L1 逐块抽取（随文件线性增长）→ L2 本地归并去重（规模固定）
/// → L3 成稿（规模固定）。所有 LLM 调用都强制 JSON 输出并带容错解析与退避重试。
class NovelGenerator {
  NovelGenerator({required AppSettings settings, LLMClient? client})
      : _client = client ?? LLMClient(),
        // 聊天用的 maxTokens（常见 512）远不够写卡，这里强制放大。
        _settings = settings.copyWith(
          api: settings.api.copyWith(
            maxTokens: settings.api.maxTokens < 4096 ? 4096 : settings.api.maxTokens,
            temperature: 0.7,
          ),
        );

  final LLMClient _client;
  final AppSettings _settings;

  /// 累计消耗 tokens（估算值，用于进度面板显示）。
  int tokensUsed = 0;

  AppSettings get settings => _settings;

  // ---------------------------------------------------------------- L1

  /// 抽取单块。失败会重试；彻底失败抛异常，由编排层记为失败块并继续。
  Future<BlockExtraction> extractBlock({
    required String blockId,
    required int chapterIndex,
    required String chapterTitle,
    required String text,
    String extraInstruction = '',
    bool Function()? shouldStop,
  }) async {
    final prompt = StringBuffer()
      ..writeln('你是小说设定分析器。只输出 JSON，不要任何解释或 Markdown 以外的文字。')
      ..writeln('从下面的小说片段中抽取客观存在的设定：')
      ..writeln('1) characters：出场人物，最多 8 个。字段 name, aliases(数组), '
          'appearance, personality, relationship, speechStyle, role(主角/配角/反派等)。')
      ..writeln('2) lore：世界设定，最多 6 条。字段 topic, keys(触发关键词数组), '
          'content, category(地点/组织/物品/规则/时间线), constant(是否世界观常驻,布尔)。')
      ..writeln('3) summary：本片段剧情，80 字以内。')
      ..writeln('要求：只写片段中确有依据的信息，不要推测；无依据的字段留空字符串；'
          'content 用陈述句写实；人名保留原文用字。')
      ..writeln('输出格式：{"characters":[...],"lore":[...],"summary":"..."}');
    if (extraInstruction.trim().isNotEmpty) {
      prompt.writeln('附加要求：${extraInstruction.trim()}');
    }

    final messages = [
      {'role': 'system', 'content': prompt.toString()},
      {
        'role': 'user',
        'content': '【${chapterTitle.isEmpty ? '第$chapterIndex段' : chapterTitle}】\n$text',
      },
    ];

    final json = await _callJson(messages, shouldStop: shouldStop);
    final chars = <ExtractedCharacter>[];
    for (final raw in (json['characters'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final c = ExtractedCharacter.fromJson(Map<String, dynamic>.from(raw));
      if (c.name.isNotEmpty) chars.add(c);
    }
    final lore = <ExtractedLore>[];
    for (final raw in (json['lore'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final l = ExtractedLore.fromJson(Map<String, dynamic>.from(raw));
      if (l.topic.isNotEmpty && l.content.isNotEmpty) lore.add(l);
    }
    return BlockExtraction(
      blockId: blockId,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      characters: chars,
      lore: lore,
      summary: (json['summary'] ?? '').toString(),
    );
  }

  // ---------------------------------------------------------------- L2

  /// 本地归并：按名字/别名合并同一人物，按主题合并同一设定，并统计戏份。
  /// 纯本地、零 API，规模与文件大小无关。
  static List<MergedCharacter> mergeCharacters(List<BlockExtraction> blocks) {
    final byKey = <String, MergedCharacter>{};

    String norm(String s) => s
        .replaceAll(RegExp(r'''[「」『』“”"'\s]'''), '')
        .trim();

    for (final block in blocks) {
      for (final c in block.characters) {
        final key = norm(c.name);
        if (key.isEmpty) continue;
        // 命中已有条目的名字或别名 → 视为同一人。
        MergedCharacter? target = byKey[key];
        if (target == null) {
          for (final m in byKey.values) {
            if (m.aliases.contains(key) ||
                c.aliases.map(norm).contains(m.name)) {
              target = m;
              break;
            }
          }
        }
        target ??= byKey[key] = MergedCharacter(name: c.name.trim());
        target.mentions++;
        for (final a in c.aliases) {
          final n = norm(a);
          if (n.isNotEmpty && n != key) target.aliases.add(a.trim());
        }
        if (c.appearance.trim().isNotEmpty) target.appearance.add(c.appearance);
        if (c.personality.trim().isNotEmpty) target.personality.add(c.personality);
        if (c.relationship.trim().isNotEmpty) {
          target.relationship.add(c.relationship);
        }
        if (c.speechStyle.trim().isNotEmpty) target.speechStyle.add(c.speechStyle);
        if (target.role.isEmpty && c.role.trim().isNotEmpty) {
          target.role = c.role.trim();
        }
      }
    }

    final out = byKey.values.toList()
      ..sort((a, b) {
        final byMentions = b.mentions.compareTo(a.mentions);
        return byMentions != 0 ? byMentions : a.name.compareTo(b.name);
      });
    return out;
  }

  static List<MergedLore> mergeLore(List<BlockExtraction> blocks) {
    final byKey = <String, MergedLore>{};
    String norm(String s) => s.replaceAll(RegExp(r'[\s《》「」]'), '').trim();

    for (final block in blocks) {
      for (final l in block.lore) {
        final key = norm(l.topic);
        if (key.isEmpty) continue;
        final target = byKey[key] ??= MergedLore(topic: l.topic.trim());
        target.mentions++;
        target.keys.addAll(l.keys.where((k) => k.trim().isNotEmpty));
        target.keys.add(l.topic.trim());
        if (l.content.trim().isNotEmpty) target.contents.add(l.content);
        if (target.category.isEmpty) target.category = l.category;
        target.constant = target.constant || l.constant;
      }
    }

    final out = byKey.values.toList()
      ..sort((a, b) {
        final byConst = (b.constant ? 1 : 0).compareTo(a.constant ? 1 : 0);
        if (byConst != 0) return byConst;
        final byMentions = b.mentions.compareTo(a.mentions);
        return byMentions != 0 ? byMentions : a.topic.compareTo(b.topic);
      });
    return out;
  }

  // ---------------------------------------------------------------- L3

  /// 成稿一张角色卡。LLM 失败时用归并档案本地兜底，保证用户总能拿到结果。
  Future<DraftCard> composeCard({
    required MergedCharacter character,
    required String worldSummary,
    String extraInstruction = '',
    String avatarPath = '',
    bool Function()? shouldStop,
  }) async {
    final prompt = StringBuffer()
      ..writeln('你是 SillyTavern 角色卡作者。只输出 JSON，不要解释。')
      ..writeln('根据人物档案与世界观，写一张可直接用于角色扮演的中文角色卡。')
      ..writeln('字段：name, description(角色设定,400-800字), personality(性格,150字内), '
          'scenario(场景,100字内), first_mes(开场白,300-600字,带动作与心理描写), '
          'mes_example(对话示例,用 <START> 分隔,2-3 组), '
          'alternate_greetings(数组,2 条不同情境的开场白), '
          'system_prompt(可留空), tags(数组,3-5 个中文标签)。')
      ..writeln('要求：忠于原设定，不要新增无依据的设定；可用 {{user}} 指代用户、'
          '{{char}} 指代角色；开场白用第二人称视角把 {{user}} 带入场景；'
          '不要输出状态栏/变量脚本。')
      ..writeln('输出格式：{"name":"...","description":"...","personality":"...",'
          '"scenario":"...","first_mes":"...","mes_example":"...",'
          '"alternate_greetings":["..."],"system_prompt":"","tags":["..."]}');
    if (extraInstruction.trim().isNotEmpty) {
      prompt.writeln('附加要求：${extraInstruction.trim()}');
    }

    final messages = [
      {'role': 'system', 'content': prompt.toString()},
      {
        'role': 'user',
        'content': '【人物档案】\n${character.profileText}\n\n'
            '【世界观摘要】\n${worldSummary.isEmpty ? '（无）' : worldSummary}',
      },
    ];

    try {
      final json = await _callJson(messages, shouldStop: shouldStop);
      final name = (json['name'] ?? '').toString().trim();
      return DraftCard(
        name: name.isEmpty ? character.name : name,
        description: (json['description'] ?? '').toString(),
        personality: (json['personality'] ?? '').toString(),
        scenario: (json['scenario'] ?? '').toString(),
        firstMes: (json['first_mes'] ?? '').toString(),
        mesExample: (json['mes_example'] ?? '').toString(),
        alternateGreetings: (json['alternate_greetings'] as List? ?? const [])
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList(),
        systemPrompt: (json['system_prompt'] ?? '').toString(),
        creatorNotes: '由小说自动生成',
        tags: (json['tags'] as List? ?? const [])
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .take(6)
            .toList(),
        avatarPath: avatarPath,
      );
    } catch (_) {
      // 兜底：直接用归并档案拼一张可用的卡。
      return DraftCard(
        name: character.name,
        description: character.profileText,
        personality: character.personality.take(3).join('；'),
        scenario: worldSummary.length > 200
            ? worldSummary.substring(0, 200)
            : worldSummary,
        firstMes: character.relationship.isNotEmpty
            ? character.relationship.first
            : '${character.name}看着你。',
        creatorNotes: '由小说自动生成（成稿失败，已用抽取档案兜底）',
        tags: const ['小说生成'],
        avatarPath: avatarPath,
      );
    }
  }

  /// 把归并后的世界设定整成世界书条目。LLM 失败时本地映射兜底。
  Future<List<DraftLoreEntry>> composeLore({
    required List<MergedLore> lore,
    required int maxEntries,
    String extraInstruction = '',
    bool Function()? shouldStop,
  }) async {
    final picked = lore.take(maxEntries).toList();
    if (picked.isEmpty) return const [];

    List<DraftLoreEntry> localFallback() => [
          for (var i = 0; i < picked.length; i++)
            DraftLoreEntry(
              name: picked[i].topic,
              keys: picked[i].keys.take(8).toList(),
              content: picked[i].content,
              constant: picked[i].constant,
              order: picked[i].constant ? 10 : 100 + i,
              position: 'before',
            ),
        ];

    final prompt = StringBuffer()
      ..writeln('你是 SillyTavern 世界书编辑。只输出 JSON，不要解释。')
      ..writeln('把给定设定整理成世界书条目：合并重复、补全触发关键词、'
          '把世界观级设定标为常驻。')
      ..writeln('字段：name, keys(触发关键词数组,含别名/简称), secondary_keys(数组,可空), '
          'content(条目正文,写实陈述,120字内), constant(布尔), order(整数,常驻用10,其余100起)。')
      ..writeln('输出格式：{"entries":[...]}')
      ..writeln('最多 $maxEntries 条，按重要性排序。');
    if (extraInstruction.trim().isNotEmpty) {
      prompt.writeln('附加要求：${extraInstruction.trim()}');
    }

    final source = picked
        .map((l) => '- 主题：${l.topic}｜类别：${l.category}｜关键词：'
            '${l.keys.take(6).join('、')}｜常驻：${l.constant}\n  内容：${l.content}')
        .join('\n');

    try {
      final json = await _callJson([
        {'role': 'system', 'content': prompt.toString()},
        {'role': 'user', 'content': source},
      ], shouldStop: shouldStop);
      final entries = <DraftLoreEntry>[];
      for (final raw in (json['entries'] as List? ?? const [])) {
        if (raw is! Map) continue;
        final m = Map<String, dynamic>.from(raw);
        final content = (m['content'] ?? '').toString().trim();
        final name = (m['name'] ?? '').toString().trim();
        if (content.isEmpty || name.isEmpty) continue;
        entries.add(DraftLoreEntry(
          name: name,
          keys: (m['keys'] as List? ?? const [])
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .take(10)
              .toList(),
          secondaryKeys: (m['secondary_keys'] as List? ?? const [])
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .take(6)
              .toList(),
          content: content,
          constant: m['constant'] == true,
          order: (m['order'] as num?)?.toInt() ?? 100,
        ));
        if (entries.length >= maxEntries) break;
      }
      return entries.isEmpty ? localFallback() : entries;
    } catch (_) {
      return localFallback();
    }
  }

  // ------------------------------------------------------------- 内部

  /// 调一次模型并解析 JSON。带指数退避重试（429/5xx/网络抖动）。
  Future<Map<String, dynamic>> _callJson(
    List<Map<String, dynamic>> messages, {
    bool Function()? shouldStop,
    int attempts = 3,
  }) async {
    Object? lastError;
    for (var i = 0; i < attempts; i++) {
      if (shouldStop != null && shouldStop()) {
        throw const NovelStoppedException();
      }
      try {
        final buffer = StringBuffer();
        await for (final chunk in _client.stream(
          settings: _settings,
          messages: messages,
        )) {
          if (shouldStop != null && shouldStop()) {
            throw const NovelStoppedException();
          }
          buffer.write(chunk);
        }
        final text = buffer.toString();
        tokensUsed += estimateNovelTokens(text) +
            messages.fold<int>(
              0,
              (a, m) => a + estimateNovelTokens((m['content'] ?? '').toString()),
            );
        final parsed = parseLooseJson(text);
        if (parsed == null) throw LLMException('模型没有返回可解析的 JSON');
        return parsed;
      } catch (e) {
        if (e is NovelStoppedException) rethrow;
        lastError = e;
        if (i < attempts - 1) {
          // 指数退避：1s / 2s / 4s，避开 429 限流。
          await Future<void>.delayed(Duration(seconds: 1 << i));
        }
      }
    }
    throw lastError ?? LLMException('生成失败');
  }
}

/// 生成过程被取消/暂停时抛出，编排层据此干净退出。
class NovelStoppedException implements Exception {
  const NovelStoppedException();

  @override
  String toString() => '生成已停止';
}

/// 宽松 JSON 解析：剥 Markdown 围栏、截取首个 JSON 对象、去尾逗号。
/// 模型偶尔会包 ```json 或加前后废话，这里尽量救回来。
Map<String, dynamic>? parseLooseJson(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;

  // 去掉 ```json ... ``` 围栏。
  final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
  if (fence != null) text = (fence.group(1) ?? '').trim();

  Map<String, dynamic>? tryDecode(String s) {
    try {
      final decoded = jsonDecode(s);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  final direct = tryDecode(text);
  if (direct != null) return direct;

  // 截取第一个 { 到最后一个 } 之间的内容。
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start >= 0 && end > start) {
    final slice = text.substring(start, end + 1);
    final sliced = tryDecode(slice);
    if (sliced != null) return sliced;
    // 去掉对象/数组结尾多余的逗号后再试。
    final repaired = slice.replaceAllMapped(
      RegExp(r',\s*([}\]])'),
      (m) => m.group(1) ?? '',
    );
    final fixed = tryDecode(repaired);
    if (fixed != null) return fixed;
  }
  return null;
}

/// 与主 App 一致的粗估：CJK 1 字≈1 token，其它 4 字符≈1 token。
int estimateNovelTokens(String text) {
  var cjk = 0;
  var other = 0;
  for (final rune in text.runes) {
    if ((rune >= 0x2E80 && rune <= 0x9FFF) ||
        (rune >= 0xF900 && rune <= 0xFAFF) ||
        (rune >= 0x3040 && rune <= 0x30FF)) {
      cjk++;
    } else {
      other++;
    }
  }
  return cjk + (other / 4).ceil();
}
