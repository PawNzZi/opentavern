import 'dart:convert';

class ChatAttachment {
  ChatAttachment({
    required this.id,
    required this.name,
    required this.mime,
    this.base64 = '',
    this.text = '',
  });

  final String id;
  final String name;
  final String mime;
  final String base64;
  final String text;

  bool get isImage => mime.startsWith('image/');

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mime': mime,
        'base64': base64,
        'text': text,
      };

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      id: (json['id'] ?? 'a${DateTime.now().microsecondsSinceEpoch}').toString(),
      name: (json['name'] ?? 'image').toString(),
      mime: (json['mime'] ?? 'image/png').toString(),
      base64: (json['base64'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
    );
  }
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.text,
    this.isUser = false,
    this.isSystem = false,
    this.time,
    this.reasoning,
    List<String>? swipes,
    this.swipeIndex = 0,
    this.hidden = false,
    this.bookmarked = false,
    int? createdAt,
    List<ChatAttachment>? attachments,
  })  : swipes = swipes ?? [text],
        attachments = attachments ?? [],
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  final String id;
  String text;
  final bool isUser;
  bool isSystem;
  String? time;
  String? reasoning;
  List<String> swipes;
  int swipeIndex;
  bool hidden;
  bool bookmarked;
  final int createdAt;
  final List<ChatAttachment> attachments;

  bool get hasSwipes => swipes.length > 1;

  String get currentSwipe =>
      swipes.isEmpty ? text : swipes[swipeIndex.clamp(0, swipes.length - 1)];

  ChatMessage copyWith({
    String? text,
    String? time,
    String? reasoning,
    List<String>? swipes,
    int? swipeIndex,
    bool? hidden,
    bool? bookmarked,
    List<ChatAttachment>? attachments,
  }) {
    return ChatMessage(
      id: id,
      text: text ?? this.text,
      isUser: isUser,
      isSystem: isSystem,
      time: time ?? this.time,
      reasoning: reasoning ?? this.reasoning,
      swipes: swipes ?? List.of(this.swipes),
      swipeIndex: swipeIndex ?? this.swipeIndex,
      hidden: hidden ?? this.hidden,
      bookmarked: bookmarked ?? this.bookmarked,
      attachments: attachments ?? List.of(this.attachments),
      createdAt: this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isUser': isUser,
        'isSystem': isSystem,
        'time': time,
        'reasoning': reasoning,
        'swipes': swipes,
        'swipeIndex': swipeIndex,
        'hidden': hidden,
        'bookmarked': bookmarked,
        'createdAt': createdAt,
        'attachments': attachments.map((a) => a.toJson()).toList(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] ?? 'm${DateTime.now().microsecondsSinceEpoch}').toString(),
      text: (json['text'] ?? json['mes'] ?? '').toString(),
      isUser: json['isUser'] == true || json['is_user'] == true,
      isSystem: json['isSystem'] == true || json['is_system'] == true,
      time: json['time']?.toString() ?? json['send_date']?.toString(),
      reasoning: json['reasoning']?.toString(),
      swipes: (json['swipes'] as List?)?.map((e) => e.toString()).toList(),
      swipeIndex: (json['swipeIndex'] as num?)?.toInt() ??
          (json['swipe_id'] as num?)?.toInt() ??
          0,
      hidden: json['hidden'] == true,
      bookmarked: json['bookmarked'] == true,
      createdAt: (json['createdAt'] as num?)?.toInt(),
      attachments: (json['attachments'] as List?)
              ?.whereType<Map>()
              .map((e) => ChatAttachment.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
    );
  }
}

class ChatSession {
  ChatSession({
    required this.id,
    required this.characterName,
    required this.title,
    List<ChatMessage>? messages,
    this.pinned = false,
    int? updatedAt,
    Map<String, String>? variables,
    this.summary = '',
    this.summaryUpTo = 0,
  })  : messages = messages ?? [],
        variables = variables ?? {},
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  final String id;
  String characterName;
  String title;
  final List<ChatMessage> messages;
  bool pinned;
  int updatedAt;
  final Map<String, String> variables;
  String summary;
  int summaryUpTo;

  ChatMessage? get lastMessage {
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].text.trim().isNotEmpty) return messages[i];
    }
    return null;
  }

  String get snippet {
    final m = lastMessage;
    if (m == null) return '还没有消息';
    final text = m.text.replaceAll('\n', ' ').trim();
    return text.length > 42 ? '${text.substring(0, 42)}…' : text;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'characterName': characterName,
        'title': title,
        'pinned': pinned,
        'updatedAt': updatedAt,
        'variables': variables,
        'summary': summary,
        'summaryUpTo': summaryUpTo,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: (json['id'] ?? 'c${DateTime.now().microsecondsSinceEpoch}').toString(),
      characterName: (json['characterName'] ?? '').toString(),
      title: (json['title'] ?? '新对话').toString(),
      pinned: json['pinned'] == true,
      updatedAt: (json['updatedAt'] as num?)?.toInt(),
      variables: (json['variables'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
          {},
      summary: (json['summary'] ?? '').toString(),
      summaryUpTo: (json['summaryUpTo'] as num?)?.toInt() ?? 0,
      messages: (json['messages'] as List?)
              ?.whereType<Map>()
              .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
    );
  }
}

class APISettings {
  const APISettings({
    this.provider = 'openai',
    this.baseUrl = 'https://api.openai.com/v1',
    this.apiKey = '',
    this.model = 'gpt-4o-mini',
    this.temperature = .85,
    this.maxTokens = 512,
    this.streaming = true,
  });

  final String provider;
  final String baseUrl;
  final String apiKey;
  final String model;
  final double temperature;
  final int maxTokens;
  final bool streaming;

  bool get configured => baseUrl.trim().isNotEmpty && model.trim().isNotEmpty;

  APISettings copyWith({
    String? provider,
    String? baseUrl,
    String? apiKey,
    String? model,
    double? temperature,
    int? maxTokens,
    bool? streaming,
  }) {
    return APISettings(
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      streaming: streaming ?? this.streaming,
    );
  }

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'temperature': temperature,
        'maxTokens': maxTokens,
        'streaming': streaming,
      };

  factory APISettings.fromJson(Map<String, dynamic> json) {
    return APISettings(
      provider: (json['provider'] ?? 'openai').toString(),
      baseUrl: (json['baseUrl'] ?? 'https://api.openai.com/v1').toString(),
      apiKey: (json['apiKey'] ?? '').toString(),
      model: (json['model'] ?? 'gpt-4o-mini').toString(),
      temperature: (json['temperature'] as num?)?.toDouble() ?? .85,
      maxTokens: (json['maxTokens'] as num?)?.toInt() ?? 512,
      streaming: json['streaming'] != false,
    );
  }
}

/// 默认的系统段落顺序，贴近 SillyTavern 的 prompt 顺序。
///
/// [PromptBuilder] 按这个顺序把非空段落拼进第一条 system 消息；其中
/// `jailbreak`（角色卡 post_history_instructions / PHI）保留在顺序表里，
/// 但发送时固定放在历史消息之后，见 `lib/core/prompt.dart`。
const List<String> kDefaultPromptOrder = [
  'main',
  'worldInfoBefore',
  'personaDescription',
  'charDescription',
  'charPersonality',
  'scenario',
  'charSystemPrompt',
  'worldInfoAfter',
  'dialogueExamples',
  'summary',
  'authorsNote',
  'jailbreak',
];

class AppSettings {
  const AppSettings({
    this.api = const APISettings(),
    this.userName = '',
    this.personaName = '',
    this.personaDescription = '',
    this.mainPrompt =
        '你正在扮演 {{char}}。请始终以 {{char}} 的身份、语气和视角回复，'
        '不要替 {{user}} 说话，不要跳出角色。用自然、具体、有画面感的叙述推进场景。',
    this.authorNote = '',
    this.maxContext = 8192,
    this.tokenPadding = 64,
    this.memoryEnabled = true,
    this.summaryInterval = 20,
    this.summaryPrompt =
        '请用简洁的中文总结以下角色对话的剧情、人物关系、当前场景与未解决的线索。只输出摘要，不要续写对话。',
    this.promptOrder = kDefaultPromptOrder,
  });

  final APISettings api;
  final String userName;
  final String personaName;
  final String personaDescription;
  final String mainPrompt;
  final String authorNote;
  final int maxContext;
  final int tokenPadding;
  final bool memoryEnabled;
  final int summaryInterval;
  final String summaryPrompt;
  final List<String> promptOrder;

  AppSettings copyWith({
    APISettings? api,
    String? userName,
    String? personaName,
    String? personaDescription,
    String? mainPrompt,
    String? authorNote,
    int? maxContext,
    int? tokenPadding,
    bool? memoryEnabled,
    int? summaryInterval,
    String? summaryPrompt,
    List<String>? promptOrder,
  }) {
    return AppSettings(
      api: api ?? this.api,
      userName: userName ?? this.userName,
      personaName: personaName ?? this.personaName,
      personaDescription: personaDescription ?? this.personaDescription,
      mainPrompt: mainPrompt ?? this.mainPrompt,
      authorNote: authorNote ?? this.authorNote,
      maxContext: maxContext ?? this.maxContext,
      tokenPadding: tokenPadding ?? this.tokenPadding,
      memoryEnabled: memoryEnabled ?? this.memoryEnabled,
      summaryInterval: summaryInterval ?? this.summaryInterval,
      summaryPrompt: summaryPrompt ?? this.summaryPrompt,
      promptOrder: promptOrder ?? List.of(this.promptOrder),
    );
  }

  Map<String, dynamic> toJson() => {
        'api': api.toJson(),
        'userName': userName,
        'personaName': personaName,
        'personaDescription': personaDescription,
        'mainPrompt': mainPrompt,
        'authorNote': authorNote,
        'maxContext': maxContext,
        'tokenPadding': tokenPadding,
        'memoryEnabled': memoryEnabled,
        'summaryInterval': summaryInterval,
        'summaryPrompt': summaryPrompt,
        'promptOrder': promptOrder,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final storedOrder = (json['promptOrder'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    return AppSettings(
      api: APISettings.fromJson(
        json['api'] is Map
            ? Map<String, dynamic>.from(json['api'] as Map)
            : const {},
      ),
      userName: (json['userName'] ?? '').toString(),
      personaName: (json['personaName'] ?? '').toString(),
      personaDescription: (json['personaDescription'] ?? '').toString(),
      mainPrompt: (json['mainPrompt'] ??
              '你正在扮演 {{char}}。请始终以 {{char}} 的身份、语气和视角回复。')
          .toString(),
      authorNote: (json['authorNote'] ?? '').toString(),
      maxContext: (json['maxContext'] as num?)?.toInt() ?? 8192,
      tokenPadding: (json['tokenPadding'] as num?)?.toInt() ?? 64,
      memoryEnabled: json['memoryEnabled'] != false,
      summaryInterval: (json['summaryInterval'] as num?)?.toInt() ?? 20,
      summaryPrompt: (json['summaryPrompt'] ??
              '请用简洁的中文总结以下角色对话的剧情、人物关系、当前场景与未解决的线索。只输出摘要，不要续写对话。')
          .toString(),
      promptOrder: storedOrder.contains('charDescription')
          ? storedOrder
          : kDefaultPromptOrder,
    );
  }

  String toJsonString() => jsonEncode(toJson());
}

class LoreEntry {
  LoreEntry({
    required this.id,
    this.name = '',
    this.keys = const [],
    this.secondaryKeys = const [],
    this.content = '',
    this.enabled = true,
    this.constant = false,
    this.selective = false,
    this.order = 100,
    this.position = 'before',
    this.depth = 4,
    this.role = 'system',
    this.comment = '',
  });

  final String id;
  String name;
  List<String> keys;
  List<String> secondaryKeys;
  String content;
  bool enabled;
  bool constant;
  bool selective;
  int order;
  String position;
  int depth;
  String role;
  String comment;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'keys': keys,
        'secondaryKeys': secondaryKeys,
        'content': content,
        'enabled': enabled,
        'constant': constant,
        'selective': selective,
        'order': order,
        'position': position,
        'depth': depth,
        'role': role,
        'comment': comment,
      };

  factory LoreEntry.fromJson(Map<String, dynamic> json) {
    return LoreEntry(
      id: (json['id'] ?? 'l${DateTime.now().microsecondsSinceEpoch}').toString(),
      name: (json['name'] ?? '').toString(),
      keys: (json['keys'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      secondaryKeys: (json['secondaryKeys'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      content: (json['content'] ?? '').toString(),
      enabled: json['enabled'] != false,
      constant: json['constant'] == true,
      selective: json['selective'] == true,
      order: (json['order'] as num?)?.toInt() ?? 100,
      position: (json['position'] ?? 'before').toString(),
      depth: (json['depth'] as num?)?.toInt() ?? 4,
      role: (json['role'] ?? 'system').toString(),
      comment: (json['comment'] ?? '').toString(),
    );
  }
}

class Lorebook {
  Lorebook({
    required this.id,
    required this.name,
    List<LoreEntry>? entries,
    this.enabled = true,
    this.isGlobal = false,
    this.linked,
    int? updatedAt,
  })  : entries = entries ?? [],
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  final String id;
  String name;
  final List<LoreEntry> entries;
  bool enabled;
  bool isGlobal;
  String? linked;
  int updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'isGlobal': isGlobal,
        'linked': linked,
        'updatedAt': updatedAt,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  factory Lorebook.fromJson(Map<String, dynamic> json) {
    return Lorebook(
      id: (json['id'] ?? 'b${DateTime.now().microsecondsSinceEpoch}').toString(),
      name: (json['name'] ?? '未命名世界书').toString(),
      enabled: json['enabled'] != false,
      isGlobal: json['isGlobal'] == true,
      linked: json['linked']?.toString(),
      updatedAt: (json['updatedAt'] as num?)?.toInt(),
      entries: (json['entries'] as List?)
              ?.whereType<Map>()
              .map((e) => LoreEntry.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
    );
  }
}

class QuickReply {
  QuickReply({
    required this.id,
    required this.label,
    this.message = '',
    this.enabled = true,
  });

  final String id;
  String label;
  String message;
  bool enabled;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'message': message,
        'enabled': enabled,
      };

  factory QuickReply.fromJson(Map<String, dynamic> json) {
    return QuickReply(
      id: (json['id'] ?? 'q${DateTime.now().microsecondsSinceEpoch}').toString(),
      label: (json['label'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      enabled: json['enabled'] != false,
    );
  }
}

class QuickReplySet {
  QuickReplySet({
    required this.id,
    required this.name,
    List<QuickReply>? replies,
    this.enabled = true,
  }) : replies = replies ?? [];

  final String id;
  String name;
  final List<QuickReply> replies;
  bool enabled;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'replies': replies.map((e) => e.toJson()).toList(),
      };

  factory QuickReplySet.fromJson(Map<String, dynamic> json) {
    return QuickReplySet(
      id: (json['id'] ?? 'qs${DateTime.now().microsecondsSinceEpoch}').toString(),
      name: (json['name'] ?? '快捷回复').toString(),
      enabled: json['enabled'] != false,
      replies: (json['replies'] as List?)
              ?.whereType<Map>()
              .map((e) => QuickReply.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
    );
  }
}

class PromptEntry {
  PromptEntry({
    required this.id,
    required this.name,
    this.content = '',
    this.role = 'system',
    this.enabled = true,
    this.order = 100,
  });

  final String id;
  String name;
  String content;
  String role;
  bool enabled;
  int order;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'content': content,
        'role': role,
        'enabled': enabled,
        'order': order,
      };

  factory PromptEntry.fromJson(Map<String, dynamic> json) {
    return PromptEntry(
      id: (json['id'] ?? 'p${DateTime.now().microsecondsSinceEpoch}').toString(),
      name: (json['name'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      role: (json['role'] ?? 'system').toString(),
      enabled: json['enabled'] != false,
      order: (json['order'] as num?)?.toInt() ?? 100,
    );
  }
}

class PromptPreset {
  PromptPreset({
    required this.id,
    required this.name,
    this.mainPrompt = '',
    List<PromptEntry>? entries,
    this.temperature = .85,
    this.maxTokens = 512,
  }) : entries = entries ?? [];

  final String id;
  String name;
  String mainPrompt;
  final List<PromptEntry> entries;
  double temperature;
  int maxTokens;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mainPrompt': mainPrompt,
        'temperature': temperature,
        'maxTokens': maxTokens,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  factory PromptPreset.fromJson(Map<String, dynamic> json) {
    return PromptPreset(
      id: (json['id'] ?? 'pp${DateTime.now().microsecondsSinceEpoch}').toString(),
      name: (json['name'] ?? '默认预设').toString(),
      mainPrompt: (json['mainPrompt'] ?? '').toString(),
      temperature: (json['temperature'] as num?)?.toDouble() ?? .85,
      maxTokens: (json['maxTokens'] as num?)?.toInt() ?? 512,
      entries: (json['entries'] as List?)
              ?.whereType<Map>()
              .map((e) => PromptEntry.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
    );
  }
}

class RegexScript {
  RegexScript({
    required this.id,
    required this.name,
    required this.find,
    required this.replace,
    this.enabled = true,
    this.placement = 'display',
    this.scope = '全局',
    this.caseSensitive = false,
  });

  final String id;
  String name;
  String find;
  String replace;
  bool enabled;
  String placement;
  String scope;
  bool caseSensitive;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'find': find,
        'replace': replace,
        'enabled': enabled,
        'placement': placement,
        'scope': scope,
        'caseSensitive': caseSensitive,
      };

  factory RegexScript.fromJson(Map<String, dynamic> json) {
    return RegexScript(
      id: (json['id'] ?? 'r${DateTime.now().microsecondsSinceEpoch}').toString(),
      name: (json['name'] ?? '').toString(),
      find: (json['find'] ?? '').toString(),
      replace: (json['replace'] ?? '').toString(),
      enabled: json['enabled'] != false,
      placement: (json['placement'] ?? 'display').toString(),
      scope: (json['scope'] ?? '全局').toString(),
      caseSensitive: json['caseSensitive'] == true,
    );
  }
}
