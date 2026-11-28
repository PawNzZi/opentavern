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
    this.gender = '',
    Set<String>? blockIds,
    List<String>? quotes,
  })  : aliases = aliases ?? <String>{},
        appearance = appearance ?? [],
        personality = personality ?? [],
        relationship = relationship ?? [],
        speechStyle = speechStyle ?? [],
        blockIds = blockIds ?? <String>{},
        quotes = quotes ?? [];

  final String name;
  final Set<String> aliases;

  /// 被多少个块提到（戏份权重）。
  int mentions;
  final List<String> appearance;
  final List<String> personality;
  final List<String> relationship;
  final List<String> speechStyle;
  String role;

  /// 男 / 女 / 未知。
  String gender;

  /// 出现过该人物的块 id，成稿时用来回读原文做「证据包」。
  final Set<String> blockIds;

  /// 从原文摘录的原话，用来总结说话方式与示例。
  final List<String> quotes;

  String get profileText {
    String join(List<String> parts, {int max = 1500}) {
      final seen = <String>{};
      final out = <String>[];
      for (final p in parts) {
        final t = p.trim();
        if (t.isEmpty || seen.contains(t)) continue;
        seen.add(t);
        out.add(t);
        if (out.join('；').length > max) break;
      }
      return out.join('；');
    }

    final sample = quotes
        .map((q) => q.trim())
        .where((q) => q.isNotEmpty)
        .take(5)
        .toList();
    return [
      '姓名：$name',
      if (aliases.isNotEmpty) '别名/称谓：${aliases.take(10).join('、')}',
      if (role.isNotEmpty) '定位：$role',
      if (appearance.isNotEmpty) '外貌：${join(appearance)}',
      if (personality.isNotEmpty) '性格：${join(personality)}',
      if (relationship.isNotEmpty) '关系：${join(relationship)}',
      if (speechStyle.isNotEmpty) '说话风格：${join(speechStyle)}',
      if (sample.isNotEmpty)
        '原话示例：${sample.map((q) => '「$q」').join(' / ')}',
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
    Set<String>? blockIds,
  })  : keys = keys ?? <String>{},
        contents = contents ?? [],
        blockIds = blockIds ?? <String>{};

  final String topic;
  final Set<String> keys;
  final List<String> contents;
  String category;
  bool constant;
  int mentions;

  /// 出现过该设定的块 id，供成稿时回读原文补充细节。
  final Set<String> blockIds;

  /// 归并后的全部素材（不再在 600 字处截断，详细成稿需要完整依据）。
  String get content {
    final seen = <String>{};
    final out = <String>[];
    for (final c in contents) {
      final t = c.trim();
      if (t.isEmpty || seen.contains(t)) continue;
      seen.add(t);
      out.add(t);
      if (out.join('\n').length > 4000) break;
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

  /// 服务商真实上报的 token 用量（provider 支持时才有）。
  int _realTokens = 0;

  /// 服务商不报 usage 时的本地估算量。
  int _estTokens = 0;

  /// 该网关是否支持 usage 字段（遇到 400 就自动关掉，不影响生成）。
  bool _usageSupported = true;

  /// 累计消耗 tokens：真实值优先，缺失的调用用估算兜底。
  int get tokensUsed => _realTokens + _estTokens;

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
          'appearance, personality, relationship, speechStyle, gender(男/女/未知), '
          'role(主角/女主/男主/配角/反派；第一人称叙述者标为「主角（叙述者）」), '
          'quotes(数组：该人物在本片段中的原话，'
          '直接摘录引号里的对话，最多 3 句，不要改写或概括)。')
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
        target.blockIds.add(block.blockId);
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
        for (final quote in c.quotes) {
          final q = quote.trim();
          if (q.isEmpty || target.quotes.contains(q)) continue;
          target.quotes.add(q);
          if (target.quotes.length >= 12) break;
        }
        if (target.role.isEmpty && c.role.trim().isNotEmpty) {
          target.role = c.role.trim();
        }
        if (target.gender.isEmpty && c.gender.trim().isNotEmpty) {
          target.gender = c.gender.trim();
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
        target.blockIds.add(block.blockId);
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

  // ---------------------------------------------------------------- L2.5

  /// LLM 人物消歧：本地规则只能合并「名字/别名完全重合」的条目，
  /// 「秦芷柔 / 芷柔 / 小姨子」这类不同形的称谓要靠模型分组。
  ///
  /// 输入按戏份排序的人物候选，输出合并后的列表。失败/结果不可信时
  /// 原样返回输入（宁可保守也不合并错人）。
  Future<List<MergedCharacter>> resolveCharacterAliases(
    List<MergedCharacter> merged, {
    int maxCandidates = 30,
    bool Function()? shouldStop,
  }) async {
    if (merged.length < 2) return merged;
    final candidates = merged.take(maxCandidates).toList();
    final listing = StringBuffer();
    for (var i = 0; i < candidates.length; i++) {
      final c = candidates[i];
      listing.writeln('$i. ${c.name}'
          '${c.aliases.isEmpty ? '' : '（别名：${c.aliases.take(6).join('、')}）'}'
          ' — 出场 $c.mentions 块');
    }

    try {
      final json = await _callJson([
        {
          'role': 'system',
          'content': '你是小说人物消歧器。只输出 JSON。\n'
              '下面是同一部小说里抽出的不同人物名/称谓。把指代**同一个人**的'
              '编号分到同一组；不同的人绝不能合并；拿不准的保持单独一组。\n'
              '判断依据：称谓关系（如「小姨子」对「姓名」）、别名简称、'
              '同一上下文互换出现。输出格式：{"groups":[[0,3],[1],[2,5,6]]}，'
              '每个编号恰好出现一次，覆盖 0 到 ${candidates.length - 1}。',
        },
        {'role': 'user', 'content': listing.toString()},
      ], shouldStop: shouldStop);

      // 校验分组：编号必须唯一且在范围内，否则视为不可信。
      final groupsRaw = json['groups'];
      if (groupsRaw is! List) return merged;
      final seen = <int>{};
      final groups = <List<int>>[];
      for (final raw in groupsRaw) {
        if (raw is! List) return merged;
        final group = <int>[];
        for (final v in raw) {
          final idx = v is num ? v.toInt() : int.tryParse('$v');
          if (idx == null || idx < 0 || idx >= candidates.length) {
            return merged;
          }
          if (seen.contains(idx)) return merged;
          seen.add(idx);
          group.add(idx);
        }
        groups.add(group);
      }
      if (seen.length != candidates.length) return merged;
      // 没有任何多成员组 = 不改变结果，直接返回。
      if (!groups.any((g) => g.length > 1)) return merged;

      MergedCharacter merge(List<MergedCharacter> members) {
        final ordered = [...members]
          ..sort((a, b) => b.mentions.compareTo(a.mentions));
        final canonical = ordered.first;
        final out = MergedCharacter(
          name: canonical.name,
          aliases: {...canonical.aliases},
          mentions: members.fold<int>(0, (a, m) => a + m.mentions),
          appearance: [...canonical.appearance],
          personality: [...canonical.personality],
          relationship: [...canonical.relationship],
          speechStyle: [...canonical.speechStyle],
          role: canonical.role,
          gender: canonical.gender,
          blockIds: {...canonical.blockIds},
          quotes: [...canonical.quotes],
        );
        for (final m in ordered.skip(1)) {
          out.aliases.addAll(m.aliases);
          if (!out.aliases.contains(m.name)) out.aliases.add(m.name);
          out.blockIds.addAll(m.blockIds);
          if (out.gender.isEmpty) out.gender = m.gender;
          for (final q in m.quotes) {
            if (!out.quotes.contains(q)) out.quotes.add(q);
          }
          out.appearance.addAll(m.appearance);
          out.personality.addAll(m.personality);
          out.relationship.addAll(m.relationship);
          out.speechStyle.addAll(m.speechStyle);
          if (out.role.isEmpty) out.role = m.role;
        }
        out.aliases.remove(out.name);
        return out;
      }

      final out = <MergedCharacter>[
        for (final g in groups)
          if (g.length == 1) candidates[g.first] else merge([for (final i in g) candidates[i]]),
      ];
      // 未进候选列表的尾部人物原样保留。
      out.addAll(merged.skip(maxCandidates));
      return out;
    } catch (_) {
      return merged;
    }
  }

  // ---------------------------------------------------------------- L2.6

  /// 角色定位：从候选人物里判断「角色卡角色（{{char}}）」与
  /// 「玩家角色（{{user}}）」，其余人物作为配角写进世界书。
  ///
  /// 规则优先于模型的自由发挥：只能选 1 个 char / 1 个 user，且 char ≠ user。
  /// 失败时退回 [castFallback]，保证永远能给出可用的定位。
  Future<CastResolution> resolveCast({
    required String title,
    required String openingExcerpt,
    required List<CastCandidate> candidates,
    String worldSummary = '',
    String plotSummary = '',
    String charOverride = '',
    String userOverride = '',
    String userDescriptionOverride = '',
    String extraInstruction = '',
    bool Function()? shouldStop,
  }) async {
    if (candidates.isEmpty) {
      return castFallback(
        title: title,
        openingExcerpt: openingExcerpt,
        candidates: candidates,
        charOverride: charOverride,
        userOverride: userOverride,
        userDescriptionOverride: userDescriptionOverride,
      );
    }

    final listing = StringBuffer();
    for (var i = 0; i < candidates.length; i++) {
      final c = candidates[i];
      listing.writeln('$i. ${c.name}'
          '${c.aliases.isEmpty ? '' : '（称谓：${c.aliases.take(8).join('、')}）'}'
          '${c.role.isEmpty ? '' : '｜定位：${c.role}'}'
          '${c.gender.isEmpty ? '' : '｜性别：${c.gender}'}'
          '｜出场 ${c.mentions} 块'
          '${c.relationship.isEmpty ? '' : '\n   关系：${_clip(c.relationship, 160)}'}');
    }

    final prompt = StringBuffer()
      ..writeln('你是小说改编 SillyTavern 角色卡的角色定位器。只输出 JSON，不要解释。')
      ..writeln('这是一次「单卡」改编：玩家会扮演 {{user}}，与角色卡 {{char}} 互动。')
      ..writeln('从候选人物里选出：')
      ..writeln('1) char：角色卡角色。优先选书名/标题点名的核心人物、与 {{user}} '
          '对手戏最多、情感或剧情张力最强的人；')
      ..writeln('2) user：玩家扮演的人。优先选叙述视角/第一人称「我」/读者代入对象。')
      ..writeln('判断规则：')
      ..writeln('- char 是玩家要互动的对象（角色卡里那个人）；user 是玩家本人；'
          'char 与 user 不能是同一个人，两人都必须来自候选清单（名字或称谓）。')
      ..writeln('- 第一人称小说：user = 「我」；char = 与「我」关系最核心的人。'
          '如果候选里戏份最高的是叙述者本人（例如「小杰」「主角（叙述者）」），'
          '绝不能把他选成 char，要选与他关系最核心的另一人。')
      ..writeln('- 判断「叙述者的名字」：第一人称里别人对「我」的称呼、'
          '主角（叙述者）标记、以及开篇里与「我」对应的名字，都属于 user；'
          '把这些名字放进 user.aliases，并从 char/supporting 中排除。')
      ..writeln('- char 的描述只写 char 本人，不要写 user 的设定；user 的设定只放在 '
          'user.description。')
      ..writeln('- 第三人称双主角：把读者代入的一方给 user，另一方给 char；'
          '不按男女频硬编码性别，根据称谓、心理描写和剧情重心判断。')
      ..writeln('- 书名包含明确关系词（如「美母」「姐姐」「师尊」）且候选里有对应人物时，'
          '该人物优先做 char；书名候选不在清单时，用关系词（母/母亲/姐/姨等）'
          '匹配候选的 relationship/称谓。')
      ..writeln('- 其余角色全部放进 supporting，不要遗漏主要配角；'
          '已故/纯背景/群体角色可以重要性低，但不要塞进 char/user。')
      ..writeln('- 第一人称叙述者如果有名字或别人对他的称呼（如「小杰」「儿子」），'
          '放进 user.aliases；绝不能把 user 本人再放进 supporting。')
      ..writeln('- 每个 supporting 的 speech_style 概括其习惯说话方式（语气、用词、'
          '口头禅、称呼），speech_examples 尽量摘录原文原话（1~3 句）。')
      ..writeln('- user.description：给 {{user}} 用的角色级人格（150~400 字），'
          '写清身份、与 char 的关系、动机、说话/行为方式；第一人称且全书没出现真名时 '
          'user.name 用「我」。')
      ..writeln('候选清单：\n$listing');
    if (worldSummary.trim().isNotEmpty) {
      prompt.writeln('世界观摘要：${_clip(worldSummary, 1200)}');
    }
    if (plotSummary.trim().isNotEmpty) {
      prompt.writeln('剧情梗概：${_clip(plotSummary, 1600)}');
    }
    if (charOverride.trim().isNotEmpty) {
      prompt.writeln('用户指定角色卡对象：$charOverride（若在候选里必须遵守）');
    }
    if (userOverride.trim().isNotEmpty) {
      prompt.writeln('用户指定 {{user}}：$userOverride（若在候选里必须遵守）');
    }
    if (extraInstruction.trim().isNotEmpty) {
      prompt.writeln('附加要求：${extraInstruction.trim()}');
    }
    prompt.writeln('输出格式：{"pov":"first|third","confidence":0.0,'
        '"char":{"name":"","aliases":[],"reason":""},'
        '"user":{"name":"","aliases":[],"description":"","reason":""},'
        '"supporting":[{"name":"","aliases":[],"importance":1,'
        '"relation_to_char":"","relation_to_user":"","motivation":"",'
        '"secrets":"","speech_style":"","speech_examples":[""],'
        '"appearance":"","personality":""}],'
        '"reason":""}');

    try {
      final json = await _callJson([
        {'role': 'system', 'content': prompt.toString()},
        {
          'role': 'user',
          'content': '书名：$title\n\n开篇原文：\n${_clip(openingExcerpt, 3000)}',
        },
      ], shouldStop: shouldStop);

      final charRaw = json['char'] is Map
          ? Map<String, dynamic>.from(json['char'] as Map)
          : const <String, dynamic>{};
      final userRaw = json['user'] is Map
          ? Map<String, dynamic>.from(json['user'] as Map)
          : const <String, dynamic>{};

      var charName = (charRaw['name'] ?? '').toString().trim();
      final charMatch = _matchCandidate(charName, candidates);
      if (charMatch != null) charName = charMatch.name;
      if (charOverride.trim().isNotEmpty) {
        final overrideMatch = _matchCandidate(charOverride, candidates);
        charName = overrideMatch?.name ?? charOverride.trim();
      }
      if (charName.isEmpty) {
        throw StateError('没有识别出角色卡角色');
      }

      var userName = (userRaw['name'] ?? '').toString().trim();
      final userMatch = _matchCandidate(userName, candidates);
      if (userMatch != null) userName = userMatch.name;
      if (userOverride.trim().isNotEmpty) {
        final overrideMatch = _matchCandidate(userOverride, candidates);
        userName = overrideMatch?.name ?? userOverride.trim();
      }
      if (userName.isEmpty) {
        userName = _looksFirstPerson(openingExcerpt) ? '我' : '玩家';
      }
      if (_norm(charName) == _norm(userName)) {
        throw StateError('角色卡角色与用户角色是同一人');
      }

      final charCandidate = _matchCandidate(charName, candidates);
      final userAliases = _mergeAliases(
        _stringList(userRaw['aliases']),
        userMatch?.aliases ?? const [],
      );
      final userKeys = <String>{
        _norm(userName),
        ...userAliases.map(_norm),
        if (userMatch != null) _norm(userMatch.name),
      };
      if (charCandidate == null && charOverride.trim().isEmpty) {
        throw StateError('角色卡角色不在候选清单里');
      }
      if (userKeys.contains(_norm(charName))) {
        throw StateError('角色卡角色命中了 {{user}} 的名字/别名');
      }
      if (userMatch != null &&
          charCandidate != null &&
          _sameCandidate(userMatch, charCandidate)) {
        throw StateError('角色卡角色与用户角色是同一人');
      }
      if (_looksFirstPerson(openingExcerpt) && charCandidate != null) {
        if (charCandidate.role.contains('叙述者')) {
          throw StateError('第一人称把叙述者选成了角色卡');
        }
        final top = candidates.reduce(
          (a, b) => b.mentions > a.mentions ? b : a,
        );
        if (_sameCandidate(charCandidate, top) &&
            !_titleMatchesCandidate(title, charCandidate) &&
            (userMatch == null || _sameCandidate(userMatch, top))) {
          throw StateError('第一人称把戏份最高的叙述者选成了角色卡');
        }
      }

      var userDescription =
          (userRaw['description'] ?? '').toString().trim();
      if (userDescriptionOverride.trim().isNotEmpty) {
        userDescription = userDescriptionOverride.trim();
      }
      if (userDescription.isEmpty) {
        userDescription = _fallbackUserDescription(
          userName: userName,
          userMatch: userMatch,
          charName: charName,
          firstPerson:
              _looksFirstPerson(openingExcerpt) || userName == '我',
        );
      }

      final supporting = <SupportingCast>[];
      for (final raw in (json['supporting'] as List? ?? const [])) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final name = (map['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final matched = _matchCandidate(name, candidates);
        final canonical = matched?.name ?? name;
        if (_norm(canonical) == _norm(charName) ||
            _norm(canonical) == _norm(userName)) {
          continue;
        }
        supporting.add(SupportingCast(
          name: canonical,
          aliases: _mergeAliases(
            _stringList(map['aliases']),
            matched?.aliases ?? const [],
          ),
          importance: ((map['importance'] as num?)?.toInt() ?? 3).clamp(1, 5),
          relationToChar: (map['relation_to_char'] ?? '').toString().trim(),
          relationToUser: (map['relation_to_user'] ?? '').toString().trim(),
          motivation: (map['motivation'] ?? '').toString().trim(),
          secrets: (map['secrets'] ?? '').toString().trim(),
          speechStyle: (map['speech_style'] ?? '').toString().trim(),
          appearance: (map['appearance'] ?? '').toString().trim(),
          personality: (map['personality'] ?? '').toString().trim(),
          speechExamples: _stringList(map['speech_examples']).take(6).toList(),
        ));
      }

      final charMatch2 = charCandidate;
      return CastResolution(
        character: CastCharacter(
          name: charMatch2?.name ?? charName,
          aliases: charMatch2?.aliases ?? const [],
          reason: (charRaw['reason'] ?? '').toString(),
        ),
        user: CastUser(
          name: userName,
          aliases: userAliases
              .where((a) => _norm(a) != _norm(userName))
              .toList(),
          description: userDescription,
          reason: (userRaw['reason'] ?? '').toString(),
        ),
        pov: (json['pov'] ?? '').toString(),
        confidence:
            ((json['confidence'] as num?)?.toDouble() ?? .6).clamp(0.0, 1.0),
        reason: (json['reason'] ?? '').toString(),
        supporting: supporting,
        source: 'ai',
      );
    } catch (_) {
      return castFallback(
        title: title,
        openingExcerpt: openingExcerpt,
        candidates: candidates,
        charOverride: charOverride,
        userOverride: userOverride,
        userDescriptionOverride: userDescriptionOverride,
      );
    }
  }

  /// 本地规则兜底：不依赖 AI，也尽量选对「单卡」。
  static CastResolution castFallback({
    required String title,
    required String openingExcerpt,
    required List<CastCandidate> candidates,
    String charOverride = '',
    String userOverride = '',
    String userDescriptionOverride = '',
  }) {
    final sorted = [...candidates]
      ..sort((a, b) => b.mentions.compareTo(a.mentions));
    final fixedChar = charOverride.trim();
    final fixedUser = userOverride.trim();
    final firstPerson =
        _looksFirstPerson(openingExcerpt) || fixedUser == '我';

    CastCandidate? match(String raw) => _matchCandidate(raw, sorted);

    CastCandidate? byTitle() {
      CastCandidate? best;
      var bestLen = 0;
      for (final c in sorted) {
        for (final alias in [c.name, ...c.aliases]) {
          final a = alias.trim();
          if (a.length < 2) continue;
          if (title.contains(a) && a.length > bestLen) {
            best = c;
            bestLen = a.length;
          }
        }
      }
      if (best != null) return best;
      // 书名用关系词（美母/姐姐/师尊…）而不是人物本名时，按关系匹配候选。
      final term = _titleRelationTerm(title);
      if (term != null) {
        final synonyms = _relationSynonyms(term);
        for (final c in sorted) {
          final hay = '${c.name} ${c.aliases.join(' ')} ${c.role} ${c.relationship}';
          if (synonyms.any(hay.contains)) return c;
        }
      }
      return null;
    }

    CastCandidate? userPick = fixedUser.isEmpty ? null : match(fixedUser);
    CastCandidate? charPick = fixedChar.isEmpty ? null : match(fixedChar);

    if (firstPerson) {
      // 第一人称：先把叙述者（主角/男主）找出来做 user，char 必须排除他。
      userPick ??= _pickNarrator(sorted);
      final titleChar = byTitle();
      if (charPick == null &&
          titleChar != null &&
          !_sameCandidate(titleChar, userPick)) {
        charPick = titleChar;
      }
      charPick ??= _first(sorted.where((c) =>
          !_sameCandidate(c, userPick) &&
          !c.role.contains('叙述者') &&
          (c.role.contains('女主') ||
              c.relationship.contains('母') ||
              c.relationship.contains('妻') ||
              c.relationship.contains('姐'))));
      charPick ??= _first(sorted.where((c) =>
          !_sameCandidate(c, userPick) && !c.role.contains('叙述者')));
      charPick ??= _first(sorted.where((c) => !_sameCandidate(c, userPick)));
      userPick ??= _first(sorted.where(
        (c) => !_sameCandidate(c, charPick) && c.gender == '男',
      ));
      // 书名已经点名了 char 时，第一人称里戏份最高的另一位通常就是叙述者，
      // 用来补全 user 的别名/人格，避免把「我」本人写成配角。
      if (userPick == null &&
          charPick != null &&
          _titleMatchesCandidate(title, charPick)) {
        userPick = _first(sorted.where(
              (c) => !_sameCandidate(c, charPick) && c.gender == '男',
            )) ??
            _first(sorted.where((c) => !_sameCandidate(c, charPick)));
      }
    } else {
      charPick ??= byTitle() ??
          _first(sorted.where((c) =>
              _norm(c.name) != _norm(userPick?.name ?? '') &&
              (c.role.contains('女主') || c.role.contains('主角'))));
      userPick ??= _first(sorted.where((c) =>
          !_sameCandidate(c, charPick) &&
          (c.role.contains('男主') || c.role.contains('主角'))));
      userPick ??= _first(
        sorted.where((c) => !_sameCandidate(c, charPick)),
      );
      charPick ??= _first(
        sorted.where((c) => !_sameCandidate(c, userPick)),
      );
    }

    final charName = charPick?.name ?? fixedChar;
    var userName = fixedUser.isNotEmpty
        ? fixedUser
        : (firstPerson ? '我' : (userPick?.name ?? '玩家'));
    if (userName.isEmpty) userName = firstPerson ? '我' : '玩家';
    if (_norm(userName) == _norm(charName)) {
      userName = firstPerson ? '我' : '玩家';
    }

    final userDesc = userDescriptionOverride.trim().isNotEmpty
        ? userDescriptionOverride.trim()
        : _fallbackUserDescription(
            userName: userName,
            userMatch: userPick,
            charName: charName.isEmpty ? '角色卡角色' : charName,
            firstPerson: firstPerson,
          );

    final excluded = <String>{
      _norm(charName),
      if (charPick != null) ...charPick.aliases.map(_norm),
      _norm(userName),
      if (userPick != null) _norm(userPick.name),
      if (userPick != null) ...userPick.aliases.map(_norm),
    };
    final supporting = <SupportingCast>[
      for (final c in sorted)
        if (!excluded.contains(_norm(c.name)))
          SupportingCast(
            name: c.name,
            aliases: c.aliases.toList(),
            importance: c.mentions >= (sorted.first.mentions * .5)
                ? 5
                : c.mentions >= (sorted.first.mentions * .2)
                    ? 3
                    : 1,
            relationToChar: _clip(c.relationship, 300),
            speechStyle: c.role,
          ),
    ];

    return CastResolution(
      character: CastCharacter(
        name: charName.isEmpty ? '未命名角色' : charName,
        aliases: charPick?.aliases.toList() ?? const [],
        reason: '本地规则兜底：书名/第一人称/戏份判断',
      ),
      user: CastUser(
        name: userName,
        aliases: _mergeAliases(
          userPick?.aliases.toList() ?? const [],
          [if (userPick != null) userPick.name],
        ).where((a) => _norm(a) != _norm(userName)).toList(),
        description: userDesc,
        reason: firstPerson ? '第一人称叙述者' : '主角/代入角色',
      ),
      pov: firstPerson ? 'first' : 'third',
      confidence: .35,
      reason: '未使用 AI 或 AI 定位失败，已按书名与戏份规则判断',
      supporting: supporting,
      source: 'fallback',
    );
  }

  /// 把归并后的配角改成「世界书人物条目」所需的定位资料。
  ///
  /// 模型可能只返回部分配角，这里用全部归并人物补齐，保证「出现的角色都进书」。
  static List<SupportingCast> completeSupporting({
    required CastResolution cast,
    required List<MergedCharacter> merged,
    int limit = 30,
  }) {
    final byNorm = <String, SupportingCast>{};
    for (final s in cast.supporting) {
      byNorm[_norm(s.name)] = s;
    }
    final charKey = _norm(cast.character.name);
    final excluded = <String>{
      charKey,
      _norm(cast.user.name),
      ...cast.user.aliases.map(_norm),
    };
    var rank = 0;
    for (final m in merged) {
      final key = _norm(m.name);
      if (excluded.contains(key)) continue;
      rank++;
      final existing = byNorm[key];
      final importance = existing?.importance ??
          (cast.supporting.isEmpty
              ? (rank <= 3 ? 5 : rank <= 8 ? 4 : 3)
              : 3);
      byNorm[key] = SupportingCast(
        name: m.name,
        aliases: _mergeAliases(
          existing?.aliases ?? const [],
          m.aliases.toList(),
        ),
        importance: importance.clamp(1, 5),
        relationToChar: existing?.relationToChar.isNotEmpty == true
            ? existing!.relationToChar
            : _clip(m.relationship.join('；'), 300),
        relationToUser: existing?.relationToUser ?? '',
        motivation: existing?.motivation ?? '',
        secrets: existing?.secrets ?? '',
        speechStyle: existing?.speechStyle.isNotEmpty == true
            ? existing!.speechStyle
            : _clip(m.speechStyle.join('；'), 200),
        appearance: existing?.appearance.isNotEmpty == true
            ? existing!.appearance
            : _clip(m.appearance.join('；'), 300),
        personality: existing?.personality.isNotEmpty == true
            ? existing!.personality
            : _clip(m.personality.join('；'), 300),
        speechExamples: existing?.speechExamples.isNotEmpty == true
            ? existing!.speechExamples
            : _mergeAliases(m.quotes, const []).take(6).toList(),
      );
    }
    final out = byNorm.values.toList()
      ..sort((a, b) {
        final c = b.importance.compareTo(a.importance);
        if (c != 0) return c;
        return a.name.compareTo(b.name);
      });
    return out.take(limit).toList();
  }

  /// 世界书「人物关系总览」常驻条目（本地拼装，不花 token）。
  static DraftLoreEntry relationshipOverview({
    required CastResolution cast,
    required List<MergedCharacter> merged,
    int maxSupporting = 12,
  }) {
    final charProfile = _mergedByName(cast.character.name, merged);
    final charDetail = charProfile == null
        ? ''
        : '——${_clip(charProfile.profileText.replaceAll('\n', '；'), 500)}';
    final userDetail = cast.user.description.trim().isEmpty
        ? ''
        : '——${_clip(cast.user.description, 300)}';
    final buffer = StringBuffer()
      ..writeln('{{char}}：${cast.character.name}$charDetail')
      ..writeln('{{user}}：${cast.user.name}$userDetail')
      ..writeln()
      ..writeln('人物关系：');
    final support = [...cast.supporting]
      ..sort((a, b) => b.importance.compareTo(a.importance));
    for (final s in support.take(maxSupporting)) {
      if (buffer.length > 2200) break;
      final relation = [
        if (s.relationToChar.trim().isNotEmpty)
          '与{{char}}：${_clip(s.relationToChar, 150)}',
        if (s.relationToUser.trim().isNotEmpty)
          '与{{user}}：${_clip(s.relationToUser, 150)}',
        if (s.motivation.trim().isNotEmpty)
          '动机：${_clip(s.motivation, 100)}',
      ].join('；');
      buffer.writeln('- ${s.name}${relation.isEmpty ? '' : '：$relation'}');
    }
    return DraftLoreEntry(
      name: '人物关系总览',
      keys: [
        '人物关系',
        '关系图',
        '人物',
        '角色关系',
        cast.character.name,
        cast.user.name,
        ...cast.character.aliases.take(4),
        ...cast.user.aliases.take(4),
      ],
      content: buffer.toString().trim(),
      constant: true,
      order: 5,
      position: 'before',
    );
  }

  // ---------------------------------------------------------------- L3

  /// 成稿一张角色卡。LLM 失败时用归并档案本地兜底，保证用户总能拿到结果。
  Future<DraftCard> composeCard({
    required MergedCharacter character,
    required CastUser user,
    required String worldSummary,
    String plotSummary = '',
    String extraInstruction = '',
    String avatarPath = '',
    bool Function()? shouldStop,
  }) async {
    final prompt = StringBuffer()
      ..writeln('你是 SillyTavern 角色卡作者。只输出 JSON，不要解释。')
      ..writeln('这是一次「单卡」改编：{{char}} = ${character.name}，'
          '{{user}} = ${user.name}，玩家会以 {{user}} 的身份与 {{char}} 互动。')
      ..writeln('根据人物档案、玩家身份、世界观与剧情梗概，写一张可直接用于角色扮演的中文角色卡。')
      ..writeln('字段：name, description(角色设定,500-800字,必须写清身份/外貌/性格/'
          '与{{user}}的关系/秘密或心结), personality(性格,200字内), '
          'scenario(当前场景与关系状态,150-300字), '
          'speech_style(习惯的说话方式,120-250字:语气、句长、用词、口头禅、'
          '对{{user}}的称呼习惯), '
          'speech_examples(数组,3-5 句该人物原话/贴近原文的说话示例，必须体现口头禅与语气), '
          'first_mes(开场白,350-600字,第二人称把{{user}}带入具体场景,带动作与心理描写), '
          'mes_example(对话示例,用 <START> 分隔,2-3 组,必须体现{{user}}与{{char}}的关系), '
          'alternate_greetings(数组,2 条不同情境的开场白), '
          'system_prompt(可留空), tags(数组,3-5 个中文标签)。')
      ..writeln('要求：忠于原设定，不要新增无依据的设定；用 {{user}} 指代玩家、'
          '{{char}} 指代角色；description 只写 {{char}} 本人（身份/外貌/性格/'
          '与{{user}}的关系），不要写 {{user}} 的设定；不要把其他配角写成主角；'
          '开场白用第二人称视角把 {{user}} 带入场景；'
          '剧情梗概只用来把握人物经历与语气，不要把整段剧情复述进卡片；'
          '说话方式与示例必须能从书中原话/人物档案找到依据，不要凭空发明；'
          '不要输出状态栏/变量脚本。')
      ..writeln('输出格式：{"name":"...","description":"...","personality":"...",'
          '"scenario":"...","speech_style":"...","speech_examples":["..."],'
          '"first_mes":"...","mes_example":"...",'
          '"alternate_greetings":["..."],"system_prompt":"","tags":["..."]}');
    if (extraInstruction.trim().isNotEmpty) {
      prompt.writeln('附加要求：${extraInstruction.trim()}');
    }

    final messages = [
      {'role': 'system', 'content': prompt.toString()},
      {
        'role': 'user',
        'content': '【角色档案】\n${character.profileText}\n\n'
            '【玩家身份 {{user}}】\n${user.name}\n${user.description}\n\n'
            '【世界观摘要】\n${worldSummary.isEmpty ? '（无）' : worldSummary}'
            '${plotSummary.trim().isEmpty ? '' : '\n\n【剧情梗概】\n${plotSummary.trim()}'}',
      },
    ];

    try {
      final json = await _callJson(messages, shouldStop: shouldStop);
      final description = (json['description'] ?? '').toString().trim();
      final firstMes = (json['first_mes'] ?? '').toString().trim();
      // 字段缺失/模型返回空壳时不要生成一张空卡：直接走本地档案兜底。
      if (description.length < 40 || firstMes.isEmpty) {
        throw StateError('角色卡字段缺失');
      }
      return DraftCard(
        // 角色卡的名字必须是 {{char}}，不能用模型返回的 user 名字。
        name: character.name,
        description: description,
        personality: (json['personality'] ?? '').toString(),
        scenario: (json['scenario'] ?? '').toString(),
        firstMes: firstMes,
        mesExample: (json['mes_example'] ?? '').toString(),
        alternateGreetings: (json['alternate_greetings'] as List? ?? const [])
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList(),
        systemPrompt: (json['system_prompt'] ?? '').toString(),
        creatorNotes: '由小说自动生成 · 角色卡 {{char}} = ${character.name}，'
            '{{user}} = ${user.name}',
        tags: (json['tags'] as List? ?? const [])
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .take(6)
            .toList(),
        avatarPath: avatarPath,
        userName: user.name,
        userDescription: user.description,
        speechStyle: (json['speech_style'] ?? '').toString(),
        speechExamples: _stringList(json['speech_examples']).take(6).toList(),
      );
    } catch (_) {
      // 兜底：直接用归并档案拼一张可用的卡。
      return DraftCard(
        name: character.name,
        description: character.profileText,
        personality: character.personality.take(5).join('；'),
        scenario: worldSummary.length > 400
            ? worldSummary.substring(0, 400)
            : worldSummary,
        firstMes: character.relationship.isNotEmpty
            ? character.relationship.first
            : '${character.name}看着你。',
        creatorNotes: '由小说自动生成（成稿失败，已用抽取档案兜底）',
        tags: const ['小说生成'],
        avatarPath: avatarPath,
        userName: user.name,
        userDescription: user.description,
        speechStyle: character.speechStyle.take(8).join('；'),
        speechExamples: character.quotes.take(5).toList(),
      );
    }
  }

  /// 把配角写成详细的「世界书人物条目」。
  ///
  /// 每批 3~4 人，附带原文证据包；正文用 `{{char}}` / `{{user}}` 宏，
  /// 入库后无论用户怎么改人格名都能正确解析。
  Future<List<DraftLoreEntry>> composeCastLore({
    required List<SupportingCast> supporting,
    required Map<String, String> evidence,
    required String charName,
    required String userName,
    required String title,
    required String plotSummary,
    required String worldSummary,
    NovelDetail detail = NovelDetail.detailed,
    String extraInstruction = '',
    bool Function()? shouldStop,
  }) async {
    if (supporting.isEmpty) return const [];
    final detailed = detail == NovelDetail.detailed;
    final batchSize = 2;
    final target = detailed ? '1000~1500 字' : '1000~1200 字';
    final minChars = 1000;
    final results = <String, DraftLoreEntry>{};

    for (var start = 0; start < supporting.length; start += batchSize) {
      final end = (start + batchSize) > supporting.length
          ? supporting.length
          : start + batchSize;
      final batch = supporting.sublist(start, end);
      final fallback = <String, DraftLoreEntry>{};
      final source = StringBuffer();
      for (final s in batch) {
        final index = supporting.indexOf(s);
        fallback[_norm(s.name)] = _castLoreFallback(
          s,
          evidence[s.name] ?? '',
          order: 120 + index,
        );
        source
          ..writeln('### ${s.name}'
              '${s.aliases.isEmpty ? '' : '（称谓：${s.aliases.join('、')}）'}'
              '｜重要度 ${s.importance}/5')
          ..writeln('外貌：${_clip(s.appearance, 400)}')
          ..writeln('性格：${_clip(s.personality, 400)}')
          ..writeln('与角色卡角色（{{char}}）的关系：${_clip(s.relationToChar, 500)}')
          ..writeln('与玩家（{{user}}）的关系：${_clip(s.relationToUser, 500)}')
          ..writeln('动机：${_clip(s.motivation, 300)}')
          ..writeln('秘密/心结：${_clip(s.secrets, 300)}')
          ..writeln('说话方式：${_clip(s.speechStyle, 200)}')
          ..writeln('原话示例：${s.speechExamples.map((q) => '「${_clip(q, 160)}」').join(' / ')}');
        final ev = evidence[s.name] ?? '';
        if (ev.trim().isNotEmpty) {
          source.writeln('原文依据：${_clip(ev, 1200)}');
        }
        source.writeln();
      }

      final prompt = StringBuffer()
        ..writeln('你是 SillyTavern 世界书编辑。只输出 JSON，不要解释。')
        ..writeln('为下列配角写「人物条目」，供角色扮演时按关键词注入。'
            '必须写具体、详细、可直接用于扮演的内容，禁止只写一两句概括。')
        ..writeln('每条正文用中文小标题分行，包含：')
        ..writeln('【身份与外貌】年龄/身份/外貌/穿着；')
        ..writeln('【性格与习惯】行为习惯、口癖、情绪触发点；')
        ..writeln('【与{{char}}的关系】称呼、亲疏、情感、冲突、秘密；')
        ..writeln('【与{{user}}的关系】称呼、态度、期待或敌意、动机；')
        ..writeln('【目标与秘密】想要什么、害怕什么、隐瞒什么；')
        ..writeln('【习惯的说话方式】语气、用词、句长、口头禅、称呼习惯；')
        ..writeln('【说话示例】3~5 句该人物可能会说的话，优先直接引用/贴近原文原话，'
            '用「……」标注，体现其语气与口头禅；')
        ..writeln('【剧情锚点】与当前主线相关的已发生/正在发生的事。')
        ..writeln('正文目标长度：$target（重要角色取长）。'
            '必须使用 {{char}} 指角色卡角色、{{user}} 指玩家，不要写死名字。')
        ..writeln('忠于原文依据，不要编造原文没有的设定；信息不足的栏目可省略，'
            '但正文不得低于 $minChars 字，不要用空话凑字数。')
        ..writeln('keys 触发关键词必须包含姓名、称谓、别名与关系词。')
        ..writeln('输出格式：{"entries":[{"name":"","keys":[],'
            '"secondary_keys":[],"content":""}]}');
      if (extraInstruction.trim().isNotEmpty) {
        prompt.writeln('附加要求：${extraInstruction.trim()}');
      }

      final messages = [
        {'role': 'system', 'content': prompt.toString()},
        {
          'role': 'user',
          'content': '书名：$title\n角色卡：$charName｜玩家：$userName\n'
              '${worldSummary.trim().isEmpty ? '' : '\n世界观摘要：${_clip(worldSummary, 1200)}\n'}'
              '${plotSummary.trim().isEmpty ? '' : '\n剧情梗概：${_clip(plotSummary, 1600)}\n'}'
              '\n$source',
        },
      ];

      try {
        final json = await _callJson(messages, shouldStop: shouldStop);
        final batchEntries = <String, DraftLoreEntry>{};
        for (final raw in (json['entries'] as List? ?? const [])) {
          if (raw is! Map) continue;
          final map = Map<String, dynamic>.from(raw);
          final name = (map['name'] ?? '').toString().trim();
          final matched = _matchSupporting(name, batch);
          if (matched == null) continue;
          final content = (map['content'] ?? '').toString().trim();
          if (content.isEmpty) continue;
          final keys = _mergeAliases(
            _mergeAliases(
              _stringList(map['keys']),
              matched.aliases,
            ),
            [matched.name],
          );
          batchEntries[_norm(matched.name)] = DraftLoreEntry(
            name: matched.name,
            keys: keys,
            secondaryKeys:
                _stringList(map['secondary_keys']).take(8).toList(),
            content: content,
            constant: false,
            order: 120 + supporting.indexOf(matched),
            position: 'before',
          );
        }
        // 质量闸门：过短的条目再扩写一次，避免模型只写两三句。
        final short = batchEntries.values
            .where((e) => e.content.length < minChars)
            .toList();
        if (short.isNotEmpty) {
          final expanded = await _expandLoreEntries(
            entries: short,
            context: source.toString(),
            minChars: minChars,
            target: target,
            shouldStop: shouldStop,
          );
          for (final e in expanded) {
            batchEntries[_norm(e.name)] = e;
          }
        }
        results.addAll(batchEntries);
      } catch (_) {
        // 该批失败：下面用本地模板补齐，不影响其他批次。
      }
      for (final entry in fallback.entries) {
        final existing = results[entry.key];
        final minChars = detailed ? 300 : 150;
        if (existing == null || existing.content.length < minChars) {
          results[entry.key] = entry.value;
        }
      }
    }

    final out = <DraftLoreEntry>[];
    for (final s in supporting) {
      final entry = results[_norm(s.name)];
      if (entry != null) out.add(entry);
    }
    return out;
  }

  static DraftLoreEntry _castLoreFallback(
    SupportingCast s,
    String evidence, {
    required int order,
  }) {
    final parts = <String>[
      if (s.appearance.trim().isNotEmpty) '【身份与外貌】${s.appearance.trim()}',
      if (s.personality.trim().isNotEmpty) '【性格与习惯】${s.personality.trim()}',
      if (s.relationToChar.trim().isNotEmpty)
        '【与{{char}}的关系】${s.relationToChar.trim()}',
      if (s.relationToUser.trim().isNotEmpty)
        '【与{{user}}的关系】${s.relationToUser.trim()}',
      if (s.motivation.trim().isNotEmpty) '【目标与动机】${s.motivation.trim()}',
      if (s.secrets.trim().isNotEmpty) '【秘密与心结】${s.secrets.trim()}',
      if (s.speechStyle.trim().isNotEmpty)
        '【习惯的说话方式】${s.speechStyle.trim()}',
      if (s.speechExamples.isNotEmpty)
        '【说话示例】${s.speechExamples.take(5).map((q) => '「${q.trim()}」').join(' ')}',
      if (evidence.trim().isNotEmpty) '【原文依据】${_clip(evidence.trim(), 800)}',
    ];
    if (parts.isEmpty) {
      parts.add('【身份】${s.name}，小说中与{{char}}有交集的配角。');
    }
    return DraftLoreEntry(
      name: s.name,
      keys: _mergeAliases(s.aliases, [s.name]),
      content: parts.join('\n'),
      constant: false,
      order: order,
      position: 'before',
    );
  }

  /// 对过短的条目做一次扩写（只在质量闸门触发时调用）。
  Future<List<DraftLoreEntry>> _expandLoreEntries({
    required List<DraftLoreEntry> entries,
    required String context,
    required int minChars,
    required String target,
    bool Function()? shouldStop,
  }) async {
    if (entries.isEmpty) return entries;
    final listing = entries
        .map((e) => '- ${e.name}\n${_clip(e.content, 1200)}')
        .join('\n\n');
    try {
      final json = await _callJson([
        {
          'role': 'system',
          'content': '你是 SillyTavern 世界书编辑。只输出 JSON。\n'
              '下列条目的正文过短。请在不编造原文没有的事实的前提下扩写到 $target：'
              '补足身份/外貌、性格与习惯、与{{char}}及{{user}}的关系、动机与秘密、'
              '习惯的说话方式、3~5 句说话示例、剧情锚点。保留原条目名与原有事实，'
              '用 {{char}} 指角色卡角色、{{user}} 指玩家，不要写死名字。\n'
              '输出格式：{"entries":[{"name":"","content":""}]}',
        },
        {
          'role': 'user',
          'content': '【已有资料】\n${_clip(context, 4000)}\n\n'
              '【待扩写条目】\n$listing',
        },
      ], shouldStop: shouldStop, attempts: 2);
      final updated = <String, String>{};
      for (final raw in (json['entries'] as List? ?? const [])) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final name = (map['name'] ?? '').toString().trim();
        final content = (map['content'] ?? '').toString().trim();
        if (name.isEmpty || content.length < minChars) continue;
        updated[_norm(name)] = content;
      }
      if (updated.isEmpty) return entries;
      return [
        for (final e in entries)
          if (updated[_norm(e.name)] != null)
            e.copyWith(content: updated[_norm(e.name)]!)
          else
            e,
      ];
    } catch (_) {
      return entries;
    }
  }

  /// 把归并后的世界设定整成世界书条目。LLM 失败时本地映射兜底。
  Future<List<DraftLoreEntry>> composeLore({
    required List<MergedLore> lore,
    required int maxEntries,
    required String worldSummary,
    NovelDetail detail = NovelDetail.detailed,
    String plotSummary = '',
    String charName = '',
    String userName = '',
    Map<String, String> evidence = const {},
    String extraInstruction = '',
    bool Function()? shouldStop,
  }) async {
    final picked = lore.take(maxEntries).toList();
    if (picked.isEmpty) return const [];
    final detailed = detail == NovelDetail.detailed;
    final target = detailed ? '1000~1300 字' : '1000~1200 字';
    final minChars = 1000;
    // 按批成稿：一次让模型写几十条 × 1000 字会超出输出上限，JSON 被截断。
    final batchSize = 2;
    final out = <DraftLoreEntry>[];

    DraftLoreEntry fallbackFor(MergedLore l, int index) => DraftLoreEntry(
          name: l.topic,
          keys: _mergeAliases(
            l.keys.take(8).toList(),
            [l.topic],
          ),
          content: [
            l.content,
            if ((evidence[l.topic] ?? '').trim().isNotEmpty)
              '【原文依据】${_clip(evidence[l.topic]!, 800)}',
          ].where((s) => s.trim().isNotEmpty).join('\n'),
          constant: l.constant,
          order: l.constant ? 10 : 100 + index,
          position: 'before',
        );

    for (var start = 0; start < picked.length; start += batchSize) {
      if (out.length >= maxEntries) break;
      final end =
          (start + batchSize) > picked.length ? picked.length : start + batchSize;
      final batch = picked.sublist(start, end);
      final fallback = <DraftLoreEntry>[
        for (var i = 0; i < batch.length; i++)
          fallbackFor(batch[i], start + i),
      ];

      final prompt = StringBuffer()
        ..writeln('你是 SillyTavern 世界书编辑。只输出 JSON，不要解释。')
        ..writeln('把给定设定写成可直接用于角色扮演的世界书条目：合并重复、'
            '补全触发关键词、把世界观级设定标为常驻。')
        ..writeln('正文必须具体、详细，禁止只写一两句概括：写清地点/组织的样貌、'
            '规则、历史、与{{char}}/{{user}}的关系或影响。')
        ..writeln('正文目标长度：$target（重要设定取长）。'
            '可用 {{char}} 指角色卡角色、{{user}} 指玩家。')
        ..writeln('正文不得低于 $minChars 字；信息不足时结合原文依据补充细节，'
            '不要用空话凑字数。')
        ..writeln('字段：name, keys(触发关键词数组,含别名/简称), secondary_keys(数组,可空), '
            'content, constant(布尔), order(整数,常驻用10,其余100起)。')
        ..writeln('输出格式：{"entries":[{"name":"","keys":[],'
            '"secondary_keys":[],"content":"","constant":false,"order":100}]}')
        ..writeln('最多 ${batch.length} 条，按重要性排序。');
      if (extraInstruction.trim().isNotEmpty) {
        prompt.writeln('附加要求：${extraInstruction.trim()}');
      }

      final source = batch
          .map((l) => '- 主题：${l.topic}｜类别：${l.category}｜关键词：'
              '${l.keys.take(8).join('、')}｜常驻：${l.constant}\n'
              '  内容：${_clip(l.content, 1200)}'
              '${(evidence[l.topic] ?? '').trim().isEmpty ? '' : '\n  原文依据：${_clip(evidence[l.topic]!, 800)}'}')
          .join('\n');

      try {
        final json = await _callJson([
          {'role': 'system', 'content': prompt.toString()},
          {
            'role': 'user',
            'content': '角色卡：$charName｜玩家：$userName\n'
                '${worldSummary.trim().isEmpty ? '' : '世界观：${_clip(worldSummary, 1000)}\n'}'
                '${plotSummary.trim().isEmpty ? '' : '剧情梗概：${_clip(plotSummary, 1000)}\n'}'
                '\n$source',
          },
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
            keys: _mergeAliases(
              _stringList(m['keys']).take(12).toList(),
              [name],
            ),
            secondaryKeys: _stringList(m['secondary_keys']).take(6).toList(),
            content: content,
            constant: m['constant'] == true,
            order: (m['order'] as num?)?.toInt() ?? 100 + start + entries.length,
            position: 'before',
          ));
          if (entries.length >= batch.length) break;
        }
        if (entries.isEmpty) {
          out.addAll(fallback);
          continue;
        }
        final short = entries
            .where((e) => e.content.length < minChars)
            .toList();
        if (short.isNotEmpty) {
          final expanded = await _expandLoreEntries(
            entries: short,
            context: source,
            minChars: minChars,
            target: target,
            shouldStop: shouldStop,
          );
          final byName = {for (final e in expanded) _norm(e.name): e};
          for (var i = 0; i < entries.length; i++) {
            final next = byName[_norm(entries[i].name)];
            if (next != null) entries[i] = next;
          }
        }
        out.addAll(entries);
      } catch (_) {
        out.addAll(fallback);
      }
    }
    return out.take(maxEntries).toList();
  }

  // ------------------------------------------------------------- 内部

  /// 调一次模型并解析 JSON。带指数退避重试（429/5xx/网络抖动）。
  ///
  /// 支持真实用量回传（网关不认识 stream_options 报 400 时自动降级为纯估算，
  /// 不烧重试次数）；`shouldStop` 同时作为请求级中止信号传给底层 HTTP 客户端。
  Future<Map<String, dynamic>> _callJson(
    List<Map<String, dynamic>> messages, {
    bool Function()? shouldStop,
    int attempts = 3,
  }) async {
    Object? lastError;
    var failures = 0;
    while (failures < attempts) {
      if (shouldStop != null && shouldStop()) {
        throw const NovelStoppedException();
      }
      final wantUsage = _usageSupported;
      try {
        final buffer = StringBuffer();
        var usageReported = false;
        await for (final chunk in _client.stream(
          settings: _settings,
          messages: messages,
          onUsage: wantUsage
              ? (input, output) {
                  usageReported = true;
                  _realTokens += input + output;
                }
              : null,
          shouldAbort: shouldStop,
        )) {
          if (shouldStop != null && shouldStop()) {
            throw const NovelStoppedException();
          }
          buffer.write(chunk);
        }
        if (shouldStop != null && shouldStop()) {
          throw const NovelStoppedException();
        }
        final text = buffer.toString();
        if (!usageReported) {
          // 网关没报 usage 的调用：本地估算兜底。
          _estTokens += estimateNovelTokens(text) +
              messages.fold<int>(
                0,
                (a, m) =>
                    a + estimateNovelTokens((m['content'] ?? '').toString()),
              );
        }
        final parsed = parseLooseJson(text);
        if (parsed == null) throw LLMException('模型没有返回可解析的 JSON');
        return parsed;
      } catch (e) {
        if (e is NovelStoppedException) rethrow;
        // 有些自建网关不认识 stream_options 字段会直接 400：关掉再试，不计失败。
        if (wantUsage && e is LLMException && e.statusCode == 400) {
          _usageSupported = false;
          continue;
        }
        lastError = e;
        failures++;
        if (failures < attempts) {
          // 指数退避：1s / 2s / 4s，避开 429 限流。
          await Future<void>.delayed(Duration(seconds: 1 << (failures - 1)));
        }
      }
    }
    throw lastError ?? LLMException('生成失败');
  }
}

String _norm(String s) => s
    .replaceAll(RegExp(r'''[「」『』“”"'\s·・]'''), '')
    .trim()
    .toLowerCase();

T? _first<T>(Iterable<T> items) => items.isEmpty ? null : items.first;

bool _sameCandidate(CastCandidate? a, CastCandidate? b) {
  if (a == null || b == null) return false;
  final aKeys = <String>{_norm(a.name), ...a.aliases.map(_norm)};
  final bKeys = <String>{_norm(b.name), ...b.aliases.map(_norm)};
  return aKeys.any(bKeys.contains);
}

/// 第一人称下找叙述者：优先「主角（叙述者）」，其次主角/男主，最后男性候选。
CastCandidate? _pickNarrator(List<CastCandidate> sorted) {
  for (final c in sorted) {
    if (c.role.contains('叙述者')) return c;
  }
  for (final c in sorted) {
    if (c.role.contains('主角') || c.role.contains('男主')) return c;
  }
  return _first(sorted.where((c) => c.gender == '男'));
}

/// 书名里的关系词（从长到短）。
const List<String> _titleRelationTerms = [
  '美母', '母亲', '妈妈', '姐姐', '小姨', '阿姨', '妻子', '老婆', '媳妇',
  '师尊', '师父', '老师', '女儿', '妹妹', '嫂子', '婶婶', '婆婆', '娘',
];

String? _titleRelationTerm(String title) {
  for (final term in _titleRelationTerms) {
    if (title.contains(term)) return term;
  }
  return null;
}

bool _titleMatchesCandidate(String title, CastCandidate c) {
  for (final alias in [c.name, ...c.aliases]) {
    final a = alias.trim();
    if (a.length >= 2 && title.contains(a)) return true;
  }
  final term = _titleRelationTerm(title);
  if (term == null) return false;
  final synonyms = _relationSynonyms(term);
  final hay = '${c.name} ${c.aliases.join(' ')} ${c.role} ${c.relationship}';
  return synonyms.any(hay.contains);
}

List<String> _relationSynonyms(String term) {
  if (term.contains('母') || term == '娘' || term.contains('妈')) {
    return const ['母亲', '妈妈', '妈', '娘', '母'];
  }
  if (term.contains('姐')) return const ['姐姐', '姐'];
  if (term.contains('姨')) return const ['小姨', '姨', '阿姨'];
  if (term.contains('妻') || term.contains('老婆') || term.contains('媳妇')) {
    return const ['妻子', '老婆', '媳妇', '妻'];
  }
  if (term.contains('师尊') || term.contains('师父')) {
    return const ['师尊', '师父', '师傅'];
  }
  if (term.contains('老师')) return const ['老师', '教师'];
  if (term.contains('女儿')) return const ['女儿', '女'];
  if (term.contains('妹妹')) return const ['妹妹', '妹'];
  if (term.contains('嫂子')) return const ['嫂子', '嫂'];
  if (term.contains('婆婆')) return const ['婆婆', '婆'];
  return [term];
}

String _clip(String s, int max) {
  final text = s.trim();
  if (text.length <= max) return text;
  return '${text.substring(0, max)}…';
}

List<String> _stringList(dynamic raw) => raw is List
    ? raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList()
    : const <String>[];

List<String> _mergeAliases(List<String> a, List<String> b) {
  final out = <String>[];
  final seen = <String>{};
  for (final raw in [...a, ...b]) {
    final value = raw.trim();
    final key = _norm(value);
    if (value.isEmpty || key.isEmpty || seen.contains(key)) continue;
    seen.add(key);
    out.add(value);
  }
  return out;
}

CastCandidate? _matchCandidate(String raw, List<CastCandidate> list) {
  final key = _norm(raw);
  if (key.isEmpty) return null;
  for (final c in list) {
    if (_norm(c.name) == key) return c;
    for (final alias in c.aliases) {
      if (_norm(alias) == key) return c;
    }
  }
  for (final c in list) {
    final name = _norm(c.name);
    if (key.length >= 2 &&
        name.length >= 2 &&
        (name.contains(key) || key.contains(name))) {
      return c;
    }
    for (final alias in c.aliases) {
      final a = _norm(alias);
      if (key.length >= 2 &&
          a.length >= 2 &&
          (a.contains(key) || key.contains(a))) {
        return c;
      }
    }
  }
  return null;
}

SupportingCast? _matchSupporting(String raw, List<SupportingCast> list) {
  final key = _norm(raw);
  if (key.isEmpty) return null;
  for (final s in list) {
    if (_norm(s.name) == key) return s;
    for (final alias in s.aliases) {
      if (_norm(alias) == key) return s;
    }
  }
  for (final s in list) {
    final name = _norm(s.name);
    if (name.length >= 2 && (name.contains(key) || key.contains(name))) {
      return s;
    }
  }
  return null;
}

/// 判断开篇是否为第一人称叙述：去掉引号内对话后统计「我」与「他/她」。
bool _looksFirstPerson(String text) {
  final narration =
      text.replaceAll(RegExp(r'[「『“][\s\S]*?[」』”]'), '');
  int count(String ch) => ch.isEmpty ? 0 : narration.split(ch).length - 1;
  final wo = count('我');
  final other = count('他') + count('她');
  return wo >= 5 && wo > other;
}

String _fallbackUserDescription({
  required String userName,
  CastCandidate? userMatch,
  required String charName,
  required bool firstPerson,
}) {
  final role = userMatch?.role.trim() ?? '';
  final relation = userMatch?.relationship.trim() ?? '';
  return [
    if (firstPerson)
      '你是故事的第一人称叙述者「我」${userName == '我' ? '' : '（$userName）'}，'
          '以第一人称参与剧情。'
    else
      '你是故事中的「$userName」${role.isEmpty ? '' : '（$role）'}。',
    '你与「$charName」存在核心剧情关系。',
    if (relation.isNotEmpty) relation,
    '以你的身份、立场和关系回应 $charName；不要替 $charName 说话。',
  ].join('\n');
}

MergedCharacter? _mergedByName(
  String name,
  List<MergedCharacter> list,
) {
  final key = _norm(name);
  if (key.isEmpty) return null;
  for (final c in list) {
    if (_norm(c.name) == key) return c;
    for (final alias in c.aliases) {
      if (_norm(alias) == key) return c;
    }
  }
  return null;
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
