import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../data/demo.dart';
import 'card_import.dart';
import 'models.dart';

/// Small local-first persistence layer. Everything lives in one folder under
/// the app documents directory; no server is involved.
class AppStore extends ChangeNotifier {
  AppStore._();

  static final AppStore instance = AppStore._();

  final List<DemoCharacter> characters = [];
  final List<ChatSession> sessions = [];
  final List<Lorebook> lorebooks = [];
  final List<QuickReplySet> quickReplySets = [];
  String activeQuickSetId = '';
  AppSettings settings = const AppSettings();

  Directory? _dir;
  bool _ready = false;

  bool get isReady => _ready;

  Future<void> init() async {
    if (_ready) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      _dir = Directory('${docs.path}/tavern');
      if (!await _dir!.exists()) await _dir!.create(recursive: true);
    } catch (e) {
      debugPrint('Local storage unavailable, using memory: $e');
      _dir = null;
    }

    await _load();
    if (characters.isEmpty) {
      characters.addAll(demoCharacters);
      await _seedSessions();
      _seedLorebooks();
      _seedQuickReplies();
      await saveCharacters();
      await saveSessions();
      await saveLorebooks();
    } else if (lorebooks.isEmpty) {
      _seedLorebooks();
      await saveLorebooks();
    }
    if (quickReplySets.isEmpty) {
      _seedQuickReplies();
      await saveQuickReplies();
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> _load() async {
    final chars = await _readJson('characters.json');
    if (chars is List) {
      for (final item in chars.whereType<Map>()) {
        characters.add(
          DemoCharacter.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }
    final chats = await _readJson('chats.json');
    if (chats is List) {
      for (final item in chats.whereType<Map>()) {
        sessions.add(ChatSession.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    final lore = await _readJson('lorebooks.json');
    if (lore is List) {
      for (final item in lore.whereType<Map>()) {
        lorebooks.add(Lorebook.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    final qr = await _readJson('quickreplies.json');
    if (qr is Map) {
      activeQuickSetId = (qr['active'] ?? '').toString();
      for (final item in (qr['sets'] as List? ?? []).whereType<Map>()) {
        quickReplySets.add(
          QuickReplySet.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }
    final cfg = await _readJson('settings.json');
    if (cfg is Map) {
      settings = AppSettings.fromJson(Map<String, dynamic>.from(cfg));
    }
  }

  Future<void> _seedSessions() async {
    for (final chat in demoChats) {
      final character = characters.firstWhere(
        (c) => c.name == chat.character.name,
        orElse: () => chat.character,
      );
      final messages = <ChatMessage>[];
      if (character.greeting.trim().isNotEmpty) {
        messages.add(
          ChatMessage(
            id: 'greet-${character.name}',
            text: character.greeting,
            time: chat.time,
          ),
        );
      }
      sessions.add(
        ChatSession(
          id: 'seed-${character.name}',
          characterName: character.name,
          title: '${character.name} · ${chat.time}',
          messages: messages,
          pinned: chat.pinned,
        ),
      );
    }
  }

  void _seedLorebooks() {
    for (final book in demoLorebooks) {
      lorebooks.add(
        Lorebook(
          id: 'seed-lore-${book.name}',
          name: book.name,
          isGlobal: book.isGlobal,
          linked: book.linked,
          entries: [
            LoreEntry(
              id: 'seed-entry-${book.name}',
              name: book.name,
              keys: [book.name.split(' ').first],
              content: '${book.name} 的设定条目。命中关键词时会注入当前对话。',
            ),
          ],
        ),
      );
    }
  }

  void _seedQuickReplies() {
    for (final set in demoQuickSets) {
      quickReplySets.add(
        QuickReplySet(
          id: 'seed-qr-${set.name}',
          name: set.name,
          replies: [
            for (final label in set.buttons)
              QuickReply(
                id: 'seed-qr-${set.name}-$label',
                label: label,
                message: label,
              ),
          ],
        ),
      );
    }
    if (quickReplySets.isNotEmpty) {
      activeQuickSetId = quickReplySets.first.id;
    }
  }

  QuickReplySet? get activeQuickSet {
    for (final set in quickReplySets) {
      if (set.id == activeQuickSetId) return set;
    }
    return quickReplySets.isEmpty ? null : quickReplySets.first;
  }

  Future<void> saveQuickReplies() async {
    await _writeJson('quickreplies.json', {
      'active': activeQuickSetId,
      'sets': quickReplySets.map((s) => s.toJson()).toList(),
    });
    notifyListeners();
  }

  Future<void> addLorebook(Lorebook book) async {
    final index = lorebooks.indexWhere((b) => b.id == book.id);
    if (index >= 0) {
      lorebooks[index] = book;
    } else {
      lorebooks.add(book);
    }
    await saveLorebooks();
    notifyListeners();
  }

  Future<void> saveLorebooks() async {
    await _writeJson(
      'lorebooks.json',
      lorebooks.map((b) => b.toJson()).toList(),
    );
    notifyListeners();
  }

  ChatSession? sessionById(String? id) {
    if (id == null) return null;
    for (final session in sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  ChatSession sessionFor(DemoCharacter character) {
    ChatSession? latest;
    for (final session in sessions) {
      if (session.characterName != character.name) continue;
      if (latest == null || session.updatedAt > latest.updatedAt) {
        latest = session;
      }
    }
    if (latest != null) return latest;
    final session = ChatSession(
      id: 'chat-${DateTime.now().microsecondsSinceEpoch}',
      characterName: character.name,
      title: '${character.name} · 新对话',
      messages: [
        if (character.greeting.trim().isNotEmpty)
          ChatMessage(
            id: 'greet-${DateTime.now().microsecondsSinceEpoch}',
            text: character.greeting,
            time: _timeLabel(),
          ),
      ],
    );
    sessions.add(session);
    saveSessions();
    return session;
  }

  ChatSession createSession(
    DemoCharacter character, {
    String? title,
    List<ChatMessage>? messages,
  }) {
    final session = ChatSession(
      id: 'chat-${DateTime.now().microsecondsSinceEpoch}',
      characterName: character.name,
      title: title ?? '${character.name} · 新对话',
      messages: messages ??
          [
            if (character.greeting.trim().isNotEmpty)
              ChatMessage(
                id: 'greet-${DateTime.now().microsecondsSinceEpoch}',
                text: character.greeting,
                time: _timeLabel(),
              ),
          ],
    );
    sessions.add(session);
    saveSessions();
    return session;
  }

  ChatSession branchSession(
    ChatSession source, {
    required int throughIndex,
    String? title,
  }) {
    final cut = source.messages.isEmpty
        ? -1
        : throughIndex.clamp(0, source.messages.length - 1);
    final copied = cut < 0
        ? <ChatMessage>[]
        : source.messages
            .take(cut + 1)
            .map((m) => m.copyWith())
            .toList();
    final session = ChatSession(
      id: 'branch-${DateTime.now().microsecondsSinceEpoch}',
      characterName: source.characterName,
      title: title ?? '${source.title} · 分支',
      messages: copied,
    );
    sessions.add(session);
    saveSessions();
    return session;
  }

  Future<void> deleteSession(String id) async {
    sessions.removeWhere((s) => s.id == id);
    await saveSessions();
  }

  Future<void> addCharacter(DemoCharacter character) async {
    final index = characters.indexWhere((c) => c.name == character.name);
    if (index >= 0) {
      characters[index] = character;
    } else {
      characters.add(character);
    }
    await saveCharacters();
    notifyListeners();
  }

  Future<DemoCharacter?> importCard(Uint8List bytes, String fileName) async {
    var card = parseCharacterCard(bytes, fileName);
    if (card == null) return null;
    final embedded = parseCharacterBook(card.rawJson, linked: card.name);
    if (embedded != null) {
      await addLorebook(embedded);
      card = card.copyWith(lorebook: embedded.name);
    }
    await addCharacter(card);
    return card;
  }

  Future<void> saveCharacters() async {
    await _writeJson(
      'characters.json',
      characters.map((c) => c.toJson()).toList(),
    );
  }

  Future<void> saveSessions() async {
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _writeJson('chats.json', sessions.map((s) => s.toJson()).toList());
    notifyListeners();
  }

  Future<void> saveSettings() async {
    await _writeJson('settings.json', settings.toJson());
    notifyListeners();
  }

  Future<Object?> _readJson(String name) async {
    if (_dir == null) return null;
    final file = File('${_dir!.path}/$name');
    if (!await file.exists()) return null;
    try {
      return jsonDecode(await file.readAsString());
    } catch (e) {
      debugPrint('read $name failed: $e');
      return null;
    }
  }

  Future<void> _writeJson(String name, Object value) async {
    if (_dir == null) return;
    final file = File('${_dir!.path}/$name');
    final temp = File('${file.path}.tmp');
    try {
      await temp.writeAsString(jsonEncode(value), flush: true);
      if (await file.exists()) await file.delete();
      await temp.rename(file.path);
    } catch (e) {
      debugPrint('write $name failed: $e');
    }
  }

  String _timeLabel() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}
