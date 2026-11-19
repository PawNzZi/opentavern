import 'dart:convert';

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
  })  : swipes = swipes ?? [text],
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
  })  : messages = messages ?? [],
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  final String id;
  final String characterName;
  String title;
  final List<ChatMessage> messages;
  bool pinned;
  int updatedAt;

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
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: (json['id'] ?? 'c${DateTime.now().microsecondsSinceEpoch}').toString(),
      characterName: (json['characterName'] ?? '').toString(),
      title: (json['title'] ?? '新对话').toString(),
      pinned: json['pinned'] == true,
      updatedAt: (json['updatedAt'] as num?)?.toInt(),
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

class AppSettings {
  const AppSettings({
    this.api = const APISettings(),
    this.userName = '旅人',
    this.personaName = '旅人',
    this.personaDescription = '一个在各地旅行的记录者，习惯先观察再开口。',
    this.mainPrompt =
        '你正在扮演 {{char}}。请始终以 {{char}} 的身份、语气和视角回复，'
        '不要替 {{user}} 说话，不要跳出角色。用自然、具体、有画面感的叙述推进场景。',
    this.authorNote = '',
    this.maxContext = 8192,
    this.tokenPadding = 64,
  });

  final APISettings api;
  final String userName;
  final String personaName;
  final String personaDescription;
  final String mainPrompt;
  final String authorNote;
  final int maxContext;
  final int tokenPadding;

  AppSettings copyWith({
    APISettings? api,
    String? userName,
    String? personaName,
    String? personaDescription,
    String? mainPrompt,
    String? authorNote,
    int? maxContext,
    int? tokenPadding,
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
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      api: APISettings.fromJson(
        json['api'] is Map
            ? Map<String, dynamic>.from(json['api'] as Map)
            : const {},
      ),
      userName: (json['userName'] ?? '旅人').toString(),
      personaName: (json['personaName'] ?? '旅人').toString(),
      personaDescription:
          (json['personaDescription'] ?? '一个在各地旅行的记录者，习惯先观察再开口。').toString(),
      mainPrompt: (json['mainPrompt'] ??
              '你正在扮演 {{char}}。请始终以 {{char}} 的身份、语气和视角回复。')
          .toString(),
      authorNote: (json['authorNote'] ?? '').toString(),
      maxContext: (json['maxContext'] as num?)?.toInt() ?? 8192,
      tokenPadding: (json['tokenPadding'] as num?)?.toInt() ?? 64,
    );
  }

  String toJsonString() => jsonEncode(toJson());
}
