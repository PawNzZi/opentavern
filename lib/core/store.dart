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
      await saveCharacters();
      await saveSessions();
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

  ChatSession sessionFor(DemoCharacter character) {
    for (final session in sessions) {
      if (session.characterName == character.name) return session;
    }
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
    final card = parseCharacterCard(bytes, fileName);
    if (card == null) return null;
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
