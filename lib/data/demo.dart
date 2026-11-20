import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Characters & chats (existing demo)
// ---------------------------------------------------------------------------

class DemoCharacter {
  const DemoCharacter({
    required this.name,
    required this.initial,
    required this.title,
    required this.tagline,
    required this.creator,
    required this.version,
    required this.description,
    required this.greeting,
    required this.tags,
    required this.lorebook,
    required this.preset,
    required this.chats,
    required this.tokens,
    required this.colors,
    this.favorite = false,
    this.unread = 0,
    this.personality = '',
    this.scenario = '',
    this.exampleDialogue = '',
    this.systemPrompt = '',
    this.postHistoryInstructions = '',
    this.alternateGreetings = const [],
    this.avatarBase64,
    this.rawJson,
    this.createdAt,
  });

  final String name;
  final String initial;
  final String title;
  final String tagline;
  final String creator;
  final String version;
  final String description;
  final String greeting;
  final List<String> tags;
  final String lorebook;
  final String preset;
  final int chats;
  final String tokens;
  final List<Color> colors;
  final bool favorite;
  final int unread;
  final String personality;
  final String scenario;
  final String exampleDialogue;
  final String systemPrompt;
  final String postHistoryInstructions;
  final List<String> alternateGreetings;
  final String? avatarBase64;
  final Map<String, dynamic>? rawJson;
  final int? createdAt;

  DemoCharacter copyWith({
    String? name,
    String? creator,
    String? version,
    String? title,
    String? tagline,
    String? description,
    String? greeting,
    List<String>? tags,
    String? lorebook,
    String? preset,
    int? chats,
    String? tokens,
    List<Color>? colors,
    bool? favorite,
    int? unread,
    String? personality,
    String? scenario,
    String? exampleDialogue,
    String? systemPrompt,
    String? postHistoryInstructions,
    List<String>? alternateGreetings,
    String? avatarBase64,
  }) {
    return DemoCharacter(
      name: name ?? this.name,
      initial: (name ?? this.name).isEmpty ? initial : (name ?? this.name).characters.first,
      title: title ?? this.title,
      tagline: tagline ?? this.tagline,
      creator: creator ?? this.creator,
      version: version ?? this.version,
      description: description ?? this.description,
      greeting: greeting ?? this.greeting,
      tags: tags ?? this.tags,
      lorebook: lorebook ?? this.lorebook,
      preset: preset ?? this.preset,
      chats: chats ?? this.chats,
      tokens: tokens ?? this.tokens,
      colors: colors ?? this.colors,
      favorite: favorite ?? this.favorite,
      unread: unread ?? this.unread,
      personality: personality ?? this.personality,
      scenario: scenario ?? this.scenario,
      exampleDialogue: exampleDialogue ?? this.exampleDialogue,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      postHistoryInstructions: postHistoryInstructions ?? this.postHistoryInstructions,
      alternateGreetings: alternateGreetings ?? this.alternateGreetings,
      avatarBase64: avatarBase64 ?? this.avatarBase64,
      rawJson: rawJson,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toCardJson() => {
        'spec': 'chara_card_v2',
        'spec_version': '2.0',
        'name': name,
        'description': description,
        'personality': personality,
        'scenario': scenario,
        'first_mes': greeting,
        'mes_example': exampleDialogue,
        'creatorcomment': tagline,
        'avatar': 'none',
        'talkativeness': 0.5,
        'fav': favorite,
        'tags': tags,
        'assets': const <Map<String, dynamic>>[],
        'group_only_greetings': const <String>[],
        'creation_date': DateTime.now().millisecondsSinceEpoch,
        'data': {
          'name': name,
          'description': description,
          'personality': personality,
          'scenario': scenario,
          'first_mes': greeting,
          'mes_example': exampleDialogue,
          'creator_notes': title,
          'system_prompt': systemPrompt,
          'post_history_instructions': postHistoryInstructions,
          'alternate_greetings': alternateGreetings,
          'tags': tags,
          'creator': creator,
          'character_version': version,
          'nickname': name,
          'creator_notes_multilingual': const <String, dynamic>{},
          'source': const <String>[],
          'group_only_greetings': const <String>[],
          'assets': const <Map<String, dynamic>>[],
          'creation_date': DateTime.now().millisecondsSinceEpoch,
          'modification_date': DateTime.now().millisecondsSinceEpoch,
          'extensions': {
            'talkativeness': 0.5,
            'fav': favorite,
            'world': lorebook == '未绑定' ? '' : lorebook,
          },
        },
      };

  Map<String, dynamic> toJson() => {
        'name': name,
        'initial': initial,
        'title': title,
        'tagline': tagline,
        'creator': creator,
        'version': version,
        'description': description,
        'greeting': greeting,
        'tags': tags,
        'lorebook': lorebook,
        'preset': preset,
        'chats': chats,
        'tokens': tokens,
        'colors': colors.map((c) => c.value).toList(),
        'favorite': favorite,
        'unread': unread,
        'personality': personality,
        'scenario': scenario,
        'exampleDialogue': exampleDialogue,
        'systemPrompt': systemPrompt,
        'postHistoryInstructions': postHistoryInstructions,
        'alternateGreetings': alternateGreetings,
        'avatarBase64': avatarBase64,
        'rawJson': rawJson,
        'createdAt': createdAt,
      };

  factory DemoCharacter.fromJson(Map<String, dynamic> json) {
    final colors = (json['colors'] as List?)
            ?.map((e) => Color((e as num).toInt()))
            .toList() ??
        _paletteFor((json['name'] ?? '?').toString());
    return DemoCharacter(
      name: (json['name'] ?? '未命名').toString(),
      initial: (json['initial'] ?? (json['name'] ?? '?').toString().characters.first).toString(),
      title: (json['title'] ?? '角色卡').toString(),
      tagline: (json['tagline'] ?? '').toString(),
      creator: (json['creator'] ?? '本地').toString(),
      version: (json['version'] ?? '1.0').toString(),
      description: (json['description'] ?? '').toString(),
      greeting: (json['greeting'] ?? '').toString(),
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      lorebook: (json['lorebook'] ?? '未绑定').toString(),
      preset: (json['preset'] ?? '默认').toString(),
      chats: (json['chats'] as num?)?.toInt() ?? 0,
      tokens: (json['tokens'] ?? '0').toString(),
      colors: colors,
      favorite: json['favorite'] == true,
      unread: (json['unread'] as num?)?.toInt() ?? 0,
      personality: (json['personality'] ?? '').toString(),
      scenario: (json['scenario'] ?? '').toString(),
      exampleDialogue: (json['exampleDialogue'] ?? '').toString(),
      systemPrompt: (json['systemPrompt'] ?? '').toString(),
      postHistoryInstructions: (json['postHistoryInstructions'] ?? '').toString(),
      alternateGreetings: (json['alternateGreetings'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      avatarBase64: json['avatarBase64']?.toString(),
      rawJson: json['rawJson'] is Map
          ? Map<String, dynamic>.from(json['rawJson'] as Map)
          : null,
      createdAt: (json['createdAt'] as num?)?.toInt(),
    );
  }

  /// Imports a SillyTavern V2/V3 card (already decoded from PNG or JSON).
  factory DemoCharacter.fromCardJson(
    Map<String, dynamic> json, {
    String? avatarBase64,
  }) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : <String, dynamic>{};
    final ext = data['extensions'] is Map
        ? Map<String, dynamic>.from(data['extensions'] as Map)
        : <String, dynamic>{};
    String pick(String key) =>
        (data[key] ?? json[key] ?? '').toString();
    final name = pick('name').trim().isEmpty ? '未命名' : pick('name').trim();
    final description = pick('description');
    final tags = _stringList(data['tags'] ?? json['tags']);
    final alt = _stringList(data['alternate_greetings']);
    final book = data['character_book'] is Map
        ? Map<String, dynamic>.from(data['character_book'] as Map)
        : null;
    return DemoCharacter(
      name: name,
      initial: name.characters.first,
      title: pick('creator_notes').trim().isEmpty
          ? '角色卡'
          : pick('creator_notes').trim(),
      tagline: description.split('\n').first,
      creator: pick('creator').trim().isEmpty ? '导入' : pick('creator'),
      version: pick('character_version').trim().isEmpty
          ? '1.0'
          : pick('character_version'),
      description: description,
      greeting: pick('first_mes'),
      tags: tags,
      lorebook: (ext['world'] ?? book?['name'] ?? '未绑定').toString(),
      preset: '默认',
      chats: 0,
      tokens: '${((description.length + pick('first_mes').length) / 2).round()}',
      colors: _paletteFor(name),
      personality: pick('personality'),
      scenario: pick('scenario'),
      exampleDialogue: pick('mes_example'),
      systemPrompt: pick('system_prompt'),
      postHistoryInstructions: pick('post_history_instructions'),
      alternateGreetings: alt,
      avatarBase64: avatarBase64,
      rawJson: json,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

List<Color> _paletteFor(String name) {
  const palettes = <List<Color>>[
    [Color(0xFF8C4A3F), Color(0xFFD98E5F), Color(0xFF3B1E2A)],
    [Color(0xFF2F4A46), Color(0xFF7FA893), Color(0xFF1A2624)],
    [Color(0xFF2A2E5C), Color(0xFF6F6BB0), Color(0xFF14152B)],
    [Color(0xFF3E5A3A), Color(0xFFB7C48A), Color(0xFF1C2A1B)],
    [Color(0xFF4A3520), Color(0xFFC99A5B), Color(0xFF24170C)],
  ];
  return palettes[name.codeUnits.fold<int>(0, (a, b) => a + b) % palettes.length];
}

class DemoMessage {
  const DemoMessage({
    required this.text,
    this.isUser = false,
    this.time,
    this.reasoning,
    this.swipeIndex,
    this.swipeCount,
  });

  final String text;
  final bool isUser;
  final String? time;
  final String? reasoning;
  final int? swipeIndex;
  final int? swipeCount;
}

class DemoChat {
  const DemoChat({
    required this.character,
    required this.snippet,
    required this.time,
    this.unread = 0,
    this.pinned = false,
    this.sessionId,
    this.title = '',
  });

  final DemoCharacter character;
  final String snippet;
  final String time;
  final int unread;
  final bool pinned;
  final String? sessionId;
  final String title;
}

class DemoLorebook {
  const DemoLorebook({
    required this.name,
    required this.entries,
    required this.linked,
    required this.updated,
    required this.color,
    this.isGlobal = false,
  });

  final String name;
  final int entries;
  final String? linked;
  final String updated;
  final Color color;
  final bool isGlobal;
}

const demoCharacters = <DemoCharacter>[
  DemoCharacter(
    name: 'Seraphina',
    initial: 'S',
    title: '王都的占星师',
    tagline: '王都的雨夜，和一位知道太多的占星师。',
    creator: 'Nyx',
    version: '1.2',
    description:
        '皇家占星院的异类。她不信命运，却靠解读星图谋生；说话很慢，像是在替每一句话挑选合适的落点。'
        '她记得所有来过塔顶的人，也记得他们没说出口的那部分。',
    greeting: '“你来得正好。我刚算到，今晚会有一位客人带着坏消息。”',
    tags: ['奇幻', '慢热', '剧情'],
    lorebook: 'Eldoria 王国设定',
    preset: '长夜 · 叙事',
    chats: 24,
    tokens: '1.8k',
    colors: [Color(0xFF8C4A3F), Color(0xFFD98E5F), Color(0xFF3B1E2A)],
    favorite: true,
    unread: 1,
  ),
  DemoCharacter(
    name: '沈砚',
    initial: '砚',
    title: '旧书店的守夜人',
    tagline: '凌晨两点，只卖旧书，也收留睡不着的人。',
    creator: '南枝',
    version: '1.0',
    description: '在城南开了一间没有招牌的旧书店。白天关门，夜里亮灯。他煮的茶很苦，但从不解释为什么。',
    greeting: '“那本书，我替你留着。不过你得先告诉我，为什么半夜来买它。”',
    tags: ['现代', '治愈', '日常'],
    lorebook: '旧书店怪谈',
    preset: '日常 · 温柔',
    chats: 8,
    tokens: '1.2k',
    colors: [Color(0xFF2F4A46), Color(0xFF7FA893), Color(0xFF1A2624)],
  ),
  DemoCharacter(
    name: 'Vesper',
    initial: 'V',
    title: '夜航船的领航员',
    tagline: '在星图之外航行，收费是一段好故事。',
    creator: 'Kite',
    version: '2.1',
    description: '她驾驶一艘没有编号的夜航船，往返于有人居住的星域之间。她说自己只认坐标，不认立场。',
    greeting: '“坐标确认。跃迁倒计时开始——你还有三十秒决定要不要上船。”',
    tags: ['科幻', '冒险', '轻松'],
    lorebook: '星图之外',
    preset: '远航 · 冒险',
    chats: 15,
    tokens: '2.4k',
    colors: [Color(0xFF2A2E5C), Color(0xFF6F6BB0), Color(0xFF14152B)],
    favorite: true,
  ),
  DemoCharacter(
    name: '阿箬',
    initial: '箬',
    title: '山里的采药人',
    tagline: '桂花开了，她有一整座山想讲给你听。',
    creator: '青禾',
    version: '1.3',
    description: '住在半山腰的木屋里，认识每一种草药的脾气。她不太会用手机，但会记得给你留一盏灯。',
    greeting: '“山里的桂花开了。你要是再不来，我就要把酿好的酒一个人喝完了。”',
    tags: ['古风', '陪伴', '慢节奏'],
    lorebook: '青崖山志',
    preset: '山居 · 舒缓',
    chats: 32,
    tokens: '2.0k',
    colors: [Color(0xFF3E5A3A), Color(0xFFB7C48A), Color(0xFF1C2A1B)],
  ),
  DemoCharacter(
    name: 'Kai',
    initial: 'K',
    title: '轨道站的机械师',
    tagline: '别碰红色阀门。真的，别碰。',
    creator: 'Mori',
    version: '1.1',
    description: '在第七轨道站负责维修一切会响的东西。话很多，手很巧，惹麻烦的本事和修东西的本事一样大。',
    greeting: '“别碰那个红色的阀门。……你碰了，对吧？行，我们现在有大概四分钟。”',
    tags: ['科幻', '轻松', '嘴硬'],
    lorebook: '第七轨道站',
    preset: '轻松 · 对话',
    chats: 5,
    tokens: '980',
    colors: [Color(0xFF1F4652), Color(0xFF5FB0B8), Color(0xFF102126)],
  ),
  DemoCharacter(
    name: '白塔',
    initial: '白',
    title: '塔中的守望者',
    tagline: '塔里没有钟，但所有人都知道时间在走。',
    creator: 'L',
    version: '1.0',
    description: '没有人知道她活了多久。她守着塔，也守着塔里那些不能被带出去的东西。',
    greeting: '“你迟到了。……不，不是今天。是很多年以前。”',
    tags: ['悬疑', '神秘', '克制'],
    lorebook: '白塔异闻',
    preset: '悬疑 · 低语',
    chats: 11,
    tokens: '1.5k',
    colors: [Color(0xFF4A4658), Color(0xFFA9A3BF), Color(0xFF1E1B26)],
  ),
];

final demoChats = <DemoChat>[
  DemoChat(
    character: demoCharacters[0],
    snippet: '“有些坏消息，只配在雨天说。”',
    time: '21:40',
    unread: 1,
    pinned: true,
  ),
  DemoChat(
    character: demoCharacters[1],
    snippet: '那本书，我替你留着。',
    time: '昨天',
  ),
  DemoChat(
    character: demoCharacters[2],
    snippet: '坐标确认，跃迁倒计时开始。',
    time: '昨天',
  ),
  DemoChat(
    character: demoCharacters[3],
    snippet: '山里的桂花开了。',
    time: '周一',
  ),
  DemoChat(
    character: demoCharacters[4],
    snippet: '别碰那个红色的阀门。',
    time: '上周',
  ),
  DemoChat(
    character: demoCharacters[5],
    snippet: '你迟到了。不是今天。',
    time: '11月2日',
  ),
];

final demoMessages = <DemoMessage>[
  const DemoMessage(
    text: '外面的雨好像更大了。',
    isUser: true,
    time: '21:38',
  ),
  const DemoMessage(
    text:
        '*她把最后一枚星图钉按进软木墙，转身时耳坠轻轻一晃。* 是啊。王都的雨，总在预言之后来。\n\n你来得正好——我刚算到，今晚会有一位客人，带着坏消息。',
    time: '21:39',
    reasoning: '先建立场景与神秘感；用动作替代直接陈述；在结尾抛出一个钩子。',
    swipeIndex: 2,
    swipeCount: 4,
  ),
  const DemoMessage(
    text: '那你还让我进来？',
    isUser: true,
    time: '21:39',
  ),
  const DemoMessage(
    text:
        '“因为坏消息也分种类。”\n\n她推来一杯还冒着热气的红茶，杯沿有一道细细的金边。\n\n“有些坏消息，只配在雨天说。”',
    time: '21:40',
    swipeIndex: 1,
    swipeCount: 2,
  ),
];

const demoLorebooks = <DemoLorebook>[
  DemoLorebook(
    name: 'Eldoria 王国设定',
    entries: 24,
    linked: 'Seraphina',
    updated: '2 天前',
    color: Color(0xFFD98E5F),
  ),
  DemoLorebook(
    name: '王都人物志',
    entries: 12,
    linked: 'Seraphina',
    updated: '5 天前',
    color: Color(0xFFEE9AA8),
  ),
  DemoLorebook(
    name: '星象与预言',
    entries: 8,
    linked: null,
    updated: '1 周前',
    color: Color(0xFFA9A0E8),
    isGlobal: true,
  ),
  DemoLorebook(
    name: '旧书店怪谈',
    entries: 6,
    linked: '沈砚',
    updated: '2 周前',
    color: Color(0xFF8FD0BE),
  ),
];

// ---------------------------------------------------------------------------
// Presets & prompt manager
// ---------------------------------------------------------------------------

class DemoPreset {
  const DemoPreset({
    required this.name,
    required this.kind,
    required this.meta,
    this.selected = false,
  });

  final String name;
  final String kind;
  final String meta;
  final bool selected;
}

const demoPresets = <DemoPreset>[
  DemoPreset(
    name: '长夜 · 叙事',
    kind: 'Chat Completion',
    meta: '温度 0.85 · 上下文 128k · 12 条提示词',
    selected: true,
  ),
  DemoPreset(
    name: '日常 · 温柔',
    kind: 'Chat Completion',
    meta: '温度 0.7 · 上下文 64k · 11 条提示词',
  ),
  DemoPreset(
    name: '冷静 · 推理',
    kind: 'Chat Completion',
    meta: '温度 0.3 · 上下文 200k · 13 条提示词',
  ),
  DemoPreset(
    name: 'Alpaca',
    kind: 'Instruct',
    meta: '### Instruction / ### Response',
  ),
  DemoPreset(
    name: 'Default',
    kind: 'Context',
    meta: 'Handlebars 模板 · 8 个变量',
  ),
  DemoPreset(
    name: 'DeepSeek R1',
    kind: 'Reasoning',
    meta: 'think 标签 · 自动解析',
  ),
];

class DemoPrompt {
  const DemoPrompt({
    required this.name,
    required this.identifier,
    required this.role,
    required this.tokens,
    this.enabled = true,
    this.injection = false,
    this.depth = 4,
    this.marker = false,
  });

  final String name;
  final String identifier;
  final String role;
  final int tokens;
  final bool enabled;
  final bool injection;
  final int depth;
  final bool marker;
}

const demoPrompts = <DemoPrompt>[
  DemoPrompt(name: 'Main Prompt', identifier: 'main', role: 'SYS', tokens: 28),
  DemoPrompt(
    name: 'World Info (before)',
    identifier: 'worldInfoBefore',
    role: 'SYS',
    tokens: 412,
    marker: true,
  ),
  DemoPrompt(
    name: 'Char Description',
    identifier: 'charDescription',
    role: 'SYS',
    tokens: 186,
    marker: true,
  ),
  DemoPrompt(
    name: 'Char Personality',
    identifier: 'charPersonality',
    role: 'SYS',
    tokens: 64,
    marker: true,
  ),
  DemoPrompt(
    name: 'Scenario',
    identifier: 'scenario',
    role: 'SYS',
    tokens: 52,
    marker: true,
  ),
  DemoPrompt(
    name: 'Auxiliary Prompt',
    identifier: 'nsfw',
    role: 'SYS',
    tokens: 18,
  ),
  DemoPrompt(
    name: 'World Info (after)',
    identifier: 'worldInfoAfter',
    role: 'SYS',
    tokens: 220,
    marker: true,
  ),
  DemoPrompt(
    name: 'Chat Examples',
    identifier: 'dialogueExamples',
    role: 'SYS',
    tokens: 640,
    marker: true,
  ),
  DemoPrompt(
    name: 'Chat History',
    identifier: 'chatHistory',
    role: 'SYS',
    tokens: 1840,
    marker: true,
  ),
  DemoPrompt(
    name: 'Post-History Instructions',
    identifier: 'jailbreak',
    role: 'SYS',
    tokens: 42,
  ),
  DemoPrompt(
    name: 'Author\'s Note',
    identifier: 'authorsNote',
    role: 'SYS',
    tokens: 36,
    injection: true,
    depth: 4,
  ),
  DemoPrompt(
    name: 'Summary',
    identifier: 'summary',
    role: 'SYS',
    tokens: 128,
    injection: true,
    depth: 2,
  ),
  DemoPrompt(
    name: 'Vector Memory',
    identifier: 'vectorsMemory',
    role: 'SYS',
    tokens: 96,
    injection: true,
    depth: 4,
    enabled: false,
  ),
];

// ---------------------------------------------------------------------------
// Personas, quick replies, regex, macros
// ---------------------------------------------------------------------------

class DemoPersona {
  const DemoPersona({
    required this.name,
    required this.initial,
    required this.description,
    required this.colors,
    this.isDefault = false,
    this.lockedTo,
  });

  final String name;
  final String initial;
  final String description;
  final List<Color> colors;
  final bool isDefault;
  final String? lockedTo;
}

const demoPersonas = <DemoPersona>[
  DemoPersona(
    name: '旅人',
    initial: '旅',
    description: '一个在各地旅行的记录者，习惯先观察再开口。',
    colors: [Color(0xFF6B4E3D), Color(0xFFC99A6B), Color(0xFF2A1E17)],
    isDefault: true,
  ),
  DemoPersona(
    name: '夜行者',
    initial: '夜',
    description: '沉默、克制，擅长在阴影里做事。',
    colors: [Color(0xFF2E3146), Color(0xFF7D82B8), Color(0xFF14151F)],
    lockedTo: '白塔',
  ),
  DemoPersona(
    name: '旁观者',
    initial: '观',
    description: '不参与剧情，只记录发生的一切。',
    colors: [Color(0xFF3F4A3A), Color(0xFF9FB08A), Color(0xFF1B211A)],
  ),
];

class DemoQuickSet {
  const DemoQuickSet({
    required this.name,
    required this.description,
    required this.buttons,
    this.active = false,
  });

  final String name;
  final String description;
  final List<String> buttons;
  final bool active;
}

const demoQuickSets = <DemoQuickSet>[
  DemoQuickSet(
    name: '日常对话',
    description: '4 个按钮 · 显示在输入框上方',
    buttons: ['继续', '换个说法', '描写环境', '推进剧情'],
    active: true,
  ),
  DemoQuickSet(
    name: '写作助手',
    description: '3 个按钮 · 仅上下文菜单',
    buttons: ['润色', '扩写', '压缩'],
  ),
  DemoQuickSet(
    name: '跑团',
    description: '5 个按钮 · 自动执行',
    buttons: ['掷骰', '检定', '战斗', '休息', '记录'],
  ),
];

class DemoRegex {
  const DemoRegex({
    required this.name,
    required this.find,
    required this.replace,
    required this.placement,
    required this.scope,
    this.enabled = true,
  });

  final String name;
  final String find;
  final String replace;
  final String placement;
  final String scope;
  final bool enabled;
}

const demoRegexes = <DemoRegex>[
  DemoRegex(
    name: '去除多余空行',
    find: r'/\n{3,}/g',
    replace: r'\n\n',
    placement: 'AI 输出',
    scope: '全局',
  ),
  DemoRegex(
    name: '清理 Markdown 标题',
    find: r'^#{1,3}\s',
    replace: '',
    placement: 'AI 输出 · 仅显示',
    scope: '全局',
  ),
  DemoRegex(
    name: '名字修正',
    find: r'Seraphina:',
    replace: '',
    placement: 'AI 输出',
    scope: 'Seraphina',
  ),
  DemoRegex(
    name: '翻译后处理',
    find: r'（译）',
    replace: '',
    placement: '显示',
    scope: '全局',
    enabled: false,
  ),
];

class DemoMacro {
  const DemoMacro({
    required this.name,
    required this.description,
    this.args = '',
  });

  final String name;
  final String description;
  final String args;
}

const demoMacros = <DemoMacro>[
  DemoMacro(name: 'user', description: '当前用户人格的名字'),
  DemoMacro(name: 'char', description: '当前角色名'),
  DemoMacro(name: 'time', description: '当前时间'),
  DemoMacro(name: 'date', description: '当前日期'),
  DemoMacro(name: 'random', description: '从参数中随机取一个', args: 'a::b::c'),
  DemoMacro(name: 'pick', description: '按聊天稳定随机', args: 'a::b::c'),
  DemoMacro(name: 'roll', description: '掷骰', args: '1d6'),
  DemoMacro(name: 'getvar', description: '读取局部变量', args: 'name'),
  DemoMacro(name: 'setvar', description: '设置局部变量', args: 'name::value'),
  DemoMacro(name: 'if', description: '条件分支', args: 'condition'),
  DemoMacro(name: 'lastMessage', description: '最后一条消息'),
  DemoMacro(name: 'maxPrompt', description: '提示词预算'),
  DemoMacro(name: 'outlet', description: '读取世界书出口', args: 'name'),
];

// ---------------------------------------------------------------------------
// Connections, models, media
// ---------------------------------------------------------------------------

class DemoConnection {
  const DemoConnection({
    required this.name,
    required this.provider,
    required this.model,
    required this.latency,
    this.active = false,
  });

  final String name;
  final String provider;
  final String model;
  final String latency;
  final bool active;
}

const demoConnections = <DemoConnection>[
  DemoConnection(
    name: 'Claude 长文',
    provider: 'Claude',
    model: 'Sonnet 4.5',
    latency: '820 ms',
    active: true,
  ),
  DemoConnection(
    name: '本地 Ollama',
    provider: 'Ollama',
    model: 'qwen3:14b',
    latency: '本地',
  ),
  DemoConnection(
    name: 'Gemini 快速',
    provider: 'Gemini',
    model: '3.5 Flash',
    latency: '410 ms',
  ),
];

class DemoModel {
  const DemoModel({
    required this.name,
    required this.context,
    required this.price,
    this.recommended = false,
  });

  final String name;
  final String context;
  final String price;
  final bool recommended;
}

const demoModels = <DemoModel>[
  DemoModel(
    name: 'Claude Sonnet 4.5',
    context: '200k',
    price: r'$3 / $15',
    recommended: true,
  ),
  DemoModel(name: 'Claude Haiku 4.5', context: '200k', price: r'$1 / $5'),
  DemoModel(name: 'GPT-5.6', context: '128k', price: r'$2.5 / $10'),
  DemoModel(name: 'Gemini 3.5 Flash', context: '1M', price: r'$0.3 / $1.2'),
  DemoModel(name: 'DeepSeek V4', context: '128k', price: '¥1 / ¥2'),
];

class DemoVoice {
  const DemoVoice({
    required this.character,
    required this.provider,
    required this.voice,
    this.enabled = true,
  });

  final String character;
  final String provider;
  final String voice;
  final bool enabled;
}

const demoVoices = <DemoVoice>[
  DemoVoice(
    character: 'Seraphina',
    provider: 'ElevenLabs',
    voice: 'Aurora · 温柔',
  ),
  DemoVoice(character: '沈砚', provider: 'Azure', voice: '云希 · 低沉'),
  DemoVoice(character: 'Vesper', provider: 'OpenAI', voice: 'Nova'),
  DemoVoice(
    character: '旁白',
    provider: 'System',
    voice: '系统默认',
    enabled: false,
  ),
];

class DemoGalleryItem {
  const DemoGalleryItem({
    required this.prompt,
    required this.colors,
    required this.size,
  });

  final String prompt;
  final List<Color> colors;
  final String size;
}

const demoGallery = <DemoGalleryItem>[
  DemoGalleryItem(
    prompt: '王都的雨夜，塔顶的星图',
    colors: [Color(0xFF8C4A3F), Color(0xFFD98E5F), Color(0xFF3B1E2A)],
    size: '1024×1536',
  ),
  DemoGalleryItem(
    prompt: '旧书店，凌晨两点的灯',
    colors: [Color(0xFF2F4A46), Color(0xFF7FA893), Color(0xFF1A2624)],
    size: '1024×1536',
  ),
  DemoGalleryItem(
    prompt: '夜航船跃迁前的星云',
    colors: [Color(0xFF2A2E5C), Color(0xFF6F6BB0), Color(0xFF14152B)],
    size: '1536×1024',
  ),
  DemoGalleryItem(
    prompt: '山腰木屋，桂花与酒',
    colors: [Color(0xFF3E5A3A), Color(0xFFB7C48A), Color(0xFF1C2A1B)],
    size: '1024×1536',
  ),
];

// ---------------------------------------------------------------------------
// Stats
// ---------------------------------------------------------------------------

class DemoStat {
  const DemoStat({
    required this.name,
    required this.messages,
    required this.words,
    required this.ratio,
    required this.colors,
  });

  final String name;
  final int messages;
  final String words;
  final double ratio;
  final List<Color> colors;
}

const demoStats = <DemoStat>[
  DemoStat(
    name: 'Seraphina',
    messages: 486,
    words: '128k',
    ratio: .92,
    colors: [Color(0xFF8C4A3F), Color(0xFFD98E5F)],
  ),
  DemoStat(
    name: '阿箬',
    messages: 312,
    words: '84k',
    ratio: .66,
    colors: [Color(0xFF3E5A3A), Color(0xFFB7C48A)],
  ),
  DemoStat(
    name: 'Vesper',
    messages: 208,
    words: '61k',
    ratio: .48,
    colors: [Color(0xFF2A2E5C), Color(0xFF6F6BB0)],
  ),
  DemoStat(
    name: '白塔',
    messages: 96,
    words: '22k',
    ratio: .22,
    colors: [Color(0xFF4A4658), Color(0xFFA9A3BF)],
  ),
];

List<String> _stringList(dynamic value) {
  if (value is! List) return <String>[];
  return [
    for (final item in value)
      if (item != null) item.toString(),
  ];
}
