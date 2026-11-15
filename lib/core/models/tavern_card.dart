/// 角色卡与世界书的数据模型（与旧版酒馆插件的 data.json 字段一致）。
library;

class TavernWorldEntry {
  TavernWorldEntry({
    required this.id,
    this.comment = '',
    this.keys = const <String>[],
    this.content = '',
    this.order = 100,
    this.position = 0,
    this.depth = 4,
    this.role = 0,
    this.enabled = true,
    this.constant = false,
    this.selective = true,
  });

  final String id;
  final String comment;
  final List<String> keys;
  final String content;
  final int order;

  /// 0=角色前 1=角色后 2=作者注上 3=作者注下 4=@D 深度
  final int position;
  final int depth;
  final int role;
  final bool enabled;
  final bool constant;
  final bool selective;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'comment': comment,
        'keys': keys,
        'content': content,
        'order': order,
        'position': position,
        'depth': depth,
        'role': role,
        'enabled': enabled,
        'constant': constant,
        'selective': selective,
      };

  static TavernWorldEntry fromJson(Map<String, dynamic> json, {String fallbackId = ''}) {
    return TavernWorldEntry(
      id: '${json['id'] ?? fallbackId}',
      comment: '${json['comment'] ?? ''}',
      keys: _strings(json['keys']),
      content: '${json['content'] ?? ''}',
      order: _int(json['order'], 100),
      position: _int(json['position'], 0),
      depth: _int(json['depth'], 4),
      role: _int(json['role'], 0),
      enabled: json['enabled'] != false,
      constant: json['constant'] == true,
      selective: json['selective'] != false,
    );
  }
}

class TavernWorld {
  TavernWorld({
    required this.id,
    required this.name,
    this.entries = const <TavernWorldEntry>[],
    this.ownerCharacterId = '',
  });

  final String id;
  final String name;
  final List<TavernWorldEntry> entries;
  final String ownerCharacterId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'entries': entries.map((TavernWorldEntry e) => e.toJson()).toList(),
        'ownerCharacterId': ownerCharacterId,
      };

  static TavernWorld fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawEntries = json['entries'] is List ? json['entries'] as List<dynamic> : <dynamic>[];
    return TavernWorld(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      ownerCharacterId: '${json['ownerCharacterId'] ?? ''}',
      entries: <TavernWorldEntry>[
        for (int i = 0; i < rawEntries.length; i++)
          if (rawEntries[i] is Map)
            TavernWorldEntry.fromJson(
              Map<String, dynamic>.from(rawEntries[i] as Map),
              fallbackId: 'e${i + 1}',
            ),
      ],
    );
  }
}

class TavernCard {
  TavernCard({
    required this.name,
    this.description = '',
    this.personality = '',
    this.scenario = '',
    this.firstMes = '',
    this.example = '',
    this.creatorNotes = '',
    this.systemPrompt = '',
    this.postHistory = '',
    this.alternateGreetings = const <String>[],
    this.tags = const <String>[],
    this.creator = '',
    this.characterVersion = '',
    this.extensions = const <String, dynamic>{},
    this.voice = '',
    this.spec = '',
    this.specVersion = '',
    this.book,
  });

  final String name;
  final String description;
  final String personality;
  final String scenario;
  final String firstMes;
  final String example;
  final String creatorNotes;
  final String systemPrompt;
  final String postHistory;
  final List<String> alternateGreetings;
  final List<String> tags;
  final String creator;
  final String characterVersion;
  final Map<String, dynamic> extensions;
  final String voice;
  final String spec;
  final String specVersion;

  /// 卡里内嵌的世界书（导入时会被拆成独立的 TavernWorld）。
  final TavernWorld? book;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'description': description,
        'personality': personality,
        'scenario': scenario,
        'firstMes': firstMes,
        'example': example,
        'creatorNotes': creatorNotes,
        'systemPrompt': systemPrompt,
        'postHistory': postHistory,
        'alternateGreetings': alternateGreetings,
        'tags': tags,
        'creator': creator,
        'characterVersion': characterVersion,
        'extensions': extensions,
        'voice': voice,
        'spec': spec,
        'specVersion': specVersion,
      };
}

/// 导出成 SillyTavern V2 结构（PNG 里存的就是这份）。
Map<String, dynamic> cardToV2Json(TavernCard card) {
  return <String, dynamic>{
    'spec': 'chara_card_v2',
    'spec_version': '2.0',
    'data': <String, dynamic>{
      'name': card.name,
      'description': card.description,
      'personality': card.personality,
      'scenario': card.scenario,
      'first_mes': card.firstMes,
      'mes_example': card.example,
      'creator_notes': card.creatorNotes,
      'system_prompt': card.systemPrompt,
      'post_history_instructions': card.postHistory,
      'alternate_greetings': card.alternateGreetings,
      'tags': card.tags,
      'creator': card.creator,
      'character_version': card.characterVersion,
      'extensions': <String, dynamic>{
        ...card.extensions,
        if (card.voice.isNotEmpty) 'hdsh_voice': card.voice,
      },
      if (card.book != null) 'character_book': _bookToStJson(card.book!),
    },
  };
}

Map<String, dynamic> _bookToStJson(TavernWorld world) {
  return <String, dynamic>{
    'name': world.name,
    'entries': <Map<String, dynamic>>[
      for (final TavernWorldEntry entry in world.entries)
        <String, dynamic>{
          'keys': entry.keys,
          'content': entry.content,
          'comment': entry.comment,
          'order': entry.order,
          'position': entry.position,
          'depth': entry.depth,
          'role': entry.role,
          'enabled': entry.enabled,
          'constant': entry.constant,
          'selective': entry.selective,
        },
    ],
  };
}

int _int(Object? value, int fallback) {
  if (value is num) return value.toInt();
  final int? parsed = int.tryParse('$value');
  return parsed ?? fallback;
}

List<String> _strings(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return <String>[
    for (final Object? item in value)
      if ('$item'.trim().isNotEmpty) '$item'.trim(),
  ];
}
