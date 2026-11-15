/// 对话与消息的读写操作（含分支、swipe、删除后记忆失效处理）。
library;

import 'package:uuid/uuid.dart';

import '../store/tavern_store.dart';

class ChatOps {
  ChatOps._();

  static const Uuid _uuid = Uuid();

  static List<Map<String, dynamic>> messages(Map<String, dynamic> chat) {
    final Object? raw = chat['messages'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return <Map<String, dynamic>>[
      for (final Object? item in raw)
        if (item is Map) item.map((Object? k, Object? v) => MapEntry<String, dynamic>('$k', v)),
    ];
  }

  static Future<Map<String, dynamic>> append(
    String chatId,
    String role,
    String text, {
    List<Map<String, dynamic>> statusLines = const <Map<String, dynamic>>[],
    List<String> quickOptions = const <String>[],
    List<Map<String, dynamic>> swipes = const <Map<String, dynamic>>[],
  }) async {
    final Map? chat = TavernStore.instance.mutable('chats', chatId);
    if (chat == null) return <String, dynamic>{};
    final Map<String, dynamic> message = <String, dynamic>{
      'id': 'm_${_uuid.v4()}',
      'role': role,
      'text': text,
      'at': DateTime.now().millisecondsSinceEpoch,
      if (statusLines.isNotEmpty) 'statusLines': statusLines,
      if (quickOptions.isNotEmpty) 'quickOptions': quickOptions,
      if (swipes.isNotEmpty) 'swipes': swipes,
      if (swipes.isNotEmpty) 'swipeIndex': 0,
    };
    (chat['messages'] as List).add(message);
    chat['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    await TavernStore.instance.save();
    return message;
  }

  static Future<void> updateText(String chatId, String messageId, String text) async {
    final Map? chat = TavernStore.instance.mutable('chats', chatId);
    if (chat == null) return;
    for (final Object? item in chat['messages'] as List) {
      if (item is Map && '${item['id']}' == messageId) {
        item['text'] = text;
        item['editedAt'] = DateTime.now().millisecondsSinceEpoch;
      }
    }
    await _invalidateMemoryIfAffected(chat, messageId);
    await TavernStore.instance.save();
  }

  /// 删除一条消息；如果它落在记忆覆盖范围内，记忆作废（下次重新压缩）。
  static Future<void> deleteMessage(String chatId, String messageId) async {
    final Map? chat = TavernStore.instance.mutable('chats', chatId);
    if (chat == null) return;
    final List messages = chat['messages'] as List;
    final int index = messages.indexWhere((Object? item) => item is Map && '${item['id']}' == messageId);
    if (index < 0) return;
    messages.removeAt(index);
    await _invalidateMemoryIfAffected(chat, messageId);
    await TavernStore.instance.save();
  }

  static Future<void> _invalidateMemoryIfAffected(Map chat, String messageId) async {
    final Object? memory = chat['memory'];
    if (memory is! Map) return;
    final String throughId = '${memory['throughMessageId'] ?? ''}';
    if (throughId.isEmpty) return;
    final List list = chat['messages'] as List;
    final int through = list.indexWhere((Object? item) => item is Map && '${item['id']}' == throughId);
    final int target = list.indexWhere((Object? item) => item is Map && '${item['id']}' == messageId);
    // 目标在覆盖范围内（找不到 through 也算）→ 记忆失效
    if (through < 0 || (target >= 0 && target <= through) || target < 0) {
      chat['memory'] = null;
    }
  }

  /// 从某条消息处开分支：新对话只保留到这条为止。
  static Future<Map<String, dynamic>?> branch(String chatId, String messageId) async {
    final Map<String, dynamic>? source = TavernStore.instance.chat(chatId);
    if (source == null) return null;
    final List<Map<String, dynamic>> sourceMessages = ChatOps.messages(source);
    final int index = sourceMessages.indexWhere((Map<String, dynamic> item) => '${item['id']}' == messageId);
    if (index < 0) return null;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final String id = 't_${_uuid.v4()}';
    final Map<String, dynamic> branchChat = <String, dynamic>{
      'id': id,
      'characterId': source['characterId'],
      'title': '${source['title'] ?? ''} · 分支',
      'messages': <Map<String, dynamic>>[
        for (int i = 0; i <= index; i++)
          <String, dynamic>{
            ...sourceMessages[i],
            'id': 'm_${_uuid.v4()}',
          },
      ],
      'variables': source['variables'] is Map
          ? Map<String, dynamic>.from(source['variables'] as Map)
          : <String, dynamic>{},
      'memory': null,
      'createdAt': now,
      'updatedAt': now,
    };
    (TavernStore.instance.rawData['chats'] as List).add(branchChat);
    await TavernStore.instance.save();
    return branchChat;
  }

  /// 设置某条消息选中的候选。
  static Future<void> selectSwipe(String chatId, String messageId, int index) async {
    final Map? chat = TavernStore.instance.mutable('chats', chatId);
    if (chat == null) return;
    for (final Object? item in chat['messages'] as List) {
      if (item is! Map || '${item['id']}' != messageId) continue;
      final Object? swipes = item['swipes'];
      if (swipes is! List || index < 0 || index >= swipes.length) return;
      final Map selected = swipes[index] as Map;
      item['swipeIndex'] = index;
      item['text'] = '${selected['text'] ?? ''}';
      if (selected['statusLines'] is List) item['statusLines'] = selected['statusLines'];
      if (selected['quickOptions'] is List) item['quickOptions'] = selected['quickOptions'];
    }
    await TavernStore.instance.save();
  }

  /// 给某条助手消息追加一个候选。
  static Future<void> addSwipe(
    String chatId,
    String messageId, {
    required String text,
    List<Map<String, dynamic>> statusLines = const <Map<String, dynamic>>[],
    List<String> quickOptions = const <String>[],
  }) async {
    final Map? chat = TavernStore.instance.mutable('chats', chatId);
    if (chat == null) return;
    for (final Object? item in chat['messages'] as List) {
      if (item is! Map || '${item['id']}' != messageId) continue;
      final List swipes = item['swipes'] is List ? item['swipes'] as List : <dynamic>[];
      swipes.add(<String, dynamic>{
        'text': text,
        if (statusLines.isNotEmpty) 'statusLines': statusLines,
        if (quickOptions.isNotEmpty) 'quickOptions': quickOptions,
      });
      item['swipes'] = swipes;
      item['swipeIndex'] = swipes.length - 1;
      item['text'] = text;
      if (statusLines.isNotEmpty) item['statusLines'] = statusLines;
      if (quickOptions.isNotEmpty) item['quickOptions'] = quickOptions;
    }
    await TavernStore.instance.save();
  }

  /// 最后一条助手消息（重新生成/续写用）。
  static Map<String, dynamic>? lastAssistant(Map<String, dynamic> chat) {
    final List<Map<String, dynamic>> messages = ChatOps.messages(chat);
    for (int i = messages.length - 1; i >= 0; i--) {
      if ('${messages[i]['role']}' == 'assistant') return messages[i];
    }
    return null;
  }

  /// 去掉最后一条助手消息（重新生成时先移除）。
  static Future<void> removeLastAssistant(String chatId) async {
    final Map? chat = TavernStore.instance.mutable('chats', chatId);
    if (chat == null) return;
    final List messages = chat['messages'] as List;
    for (int i = messages.length - 1; i >= 0; i--) {
      final Object? item = messages[i];
      if (item is Map && '${item['role']}' == 'assistant') {
        messages.removeAt(i);
        break;
      }
    }
    await TavernStore.instance.save();
  }
}
