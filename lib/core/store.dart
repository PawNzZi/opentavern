import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../data/demo.dart';
import 'card_import.dart';
import 'lore_io.dart';
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
  final List<PromptPreset> presets = [];
  final List<RegexScript> regexScripts = [];
  String activePresetId = '';
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
    await _purgeDemoDataOnce();
    await _seedMissingQuickReplies();
    _ready = true;
    notifyListeners();
  }

  Future<void> _purgeDemoDataOnce() async {
    if (_dir == null) return;
    final marker = File('${_dir!.path}/.demo_purged');
    if (await marker.exists()) return;
    final demoNames = demoCharacters.map((c) => c.name).toSet();
    characters.removeWhere(
      (c) => c.rawJson == null && demoNames.contains(c.name),
    );
    sessions.removeWhere((s) => s.id.startsWith('seed-'));
    lorebooks.removeWhere((b) => b.id.startsWith('seed-'));
    quickReplySets.removeWhere((q) => q.id.startsWith('seed-'));
    presets.removeWhere(
      (p) => p.id == 'preset-default' || p.id.startsWith('seed-'),
    );
    regexScripts.removeWhere((r) => r.id.startsWith('seed-'));
    if (settings.personaName == '旅人' &&
        settings.personaDescription == '一个在各地旅行的记录者，习惯先观察再开口。') {
      settings = settings.copyWith(
        userName: '',
        personaName: '',
        personaDescription: '',
      );
      await saveSettings();
    }
    if (!presets.any((p) => p.id == activePresetId)) activePresetId = '';
    if (!quickReplySets.any((q) => q.id == activeQuickSetId)) {
      activeQuickSetId = '';
    }
    await saveCharacters();
    await saveSessions();
    await saveLorebooks();
    await saveQuickReplies();
    await savePresets();
    await saveRegexes();
    await marker.writeAsString(DateTime.now().toIso8601String());
  }

  /// Removes all user content while keeping API and UI preferences.
  Future<void> clearAllContent() async {
    characters.clear();
    sessions.clear();
    lorebooks.clear();
    quickReplySets.clear();
    presets.clear();
    regexScripts.clear();
    activePresetId = '';
    activeQuickSetId = '';
    await saveCharacters();
    await saveSessions();
    await saveLorebooks();
    await saveQuickReplies();
    await savePresets();
    await saveRegexes();
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
    final rx = await _readJson('regex.json');
    if (rx is List) {
      for (final item in rx.whereType<Map>()) {
        regexScripts.add(
          RegexScript.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }
    final pp = await _readJson('presets.json');
    if (pp is Map) {
      activePresetId = (pp['active'] ?? '').toString();
      for (final item in (pp['presets'] as List? ?? []).whereType<Map>()) {
        presets.add(
          PromptPreset.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }
    final cfg = await _readJson('settings.json');
    if (cfg is Map) {
      settings = AppSettings.fromJson(Map<String, dynamic>.from(cfg));
    }
  }

  Future<void> _seedMissingQuickReplies() async {
    var added = false;
    for (final set in demoQuickSets) {
      if (quickReplySets.any((q) => q.name == set.name)) continue;
      added = true;
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
    if (quickReplySets.isNotEmpty && activeQuickSetId.isEmpty) {
      activeQuickSetId = quickReplySets.first.id;
    }
    if (added) await saveQuickReplies();
  }

  Future<void> addPreset(PromptPreset preset) async {
    presets.add(preset);
    activePresetId = preset.id;
    await savePresets();
    notifyListeners();
  }

  Future<void> setActivePreset(String id) async {
    activePresetId = id;
    await savePresets();
    notifyListeners();
  }

  Future<void> saveRegexes() async {
    await _writeJson(
      'regex.json',
      regexScripts.map((r) => r.toJson()).toList(),
    );
    notifyListeners();
  }

  PromptPreset? presetForCharacter(DemoCharacter character) {
    if (character.preset.trim().isNotEmpty) {
      for (final preset in presets) {
        if (preset.name == character.preset || preset.id == character.preset) {
          return preset;
        }
      }
    }
    return activePreset;
  }

  PromptPreset? get activePreset {
    for (final preset in presets) {
      if (preset.id == activePresetId) return preset;
    }
    return presets.isEmpty ? null : presets.first;
  }


  Future<void> savePresets() async {
    await _writeJson('presets.json', {
      'active': activePresetId,
      'presets': presets.map((p) => p.toJson()).toList(),
      'regexes': regexScripts.map((r) => r.toJson()).toList(),
    });
    notifyListeners();
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

  Future<void> deleteLorebook(String id) async {
    lorebooks.removeWhere((b) => b.id == id);
    await saveLorebooks();
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
    String? greeting,
    List<ChatMessage>? messages,
  }) {
    final session = ChatSession(
      id: 'chat-${DateTime.now().microsecondsSinceEpoch}',
      characterName: character.name,
      title: title ?? '${character.name} · 新对话',
      messages: messages ??
          [
            if ((greeting ?? character.greeting).trim().isNotEmpty)
              ChatMessage(
                id: 'greet-${DateTime.now().microsecondsSinceEpoch}',
                text: greeting ?? character.greeting,
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
      parentId: source.id,
      mainChatId: source.mainChatId ?? source.id,
      summary: source.summary,
      summaryUpTo: source.summaryUpTo,
      authorNote: source.authorNote,
      authorNoteOverride: source.authorNoteOverride,
    );
    sessions.add(session);
    saveSessions();
    return session;
  }

  Future<void> deleteSession(String id) async {
    sessions.removeWhere((s) => s.id == id);
    await saveSessions();
  }

  String exportChatJsonl(ChatSession session) {
    final header = jsonEncode({
      'user_name': settings.userName,
      'character_name': session.characterName,
      'create_date': DateTime.fromMillisecondsSinceEpoch(
        session.updatedAt,
      ).toIso8601String(),
      'chat_metadata': {
        'integrity': session.id,
        'variables': session.variables,
        'summary': session.summary,
      },
    });
    final lines = <String>[header];
    for (final m in session.messages) {
      lines.add(jsonEncode({
        'name': m.isUser ? settings.userName : session.characterName,
        'is_user': m.isUser,
        'is_system': m.isSystem,
        'send_date': DateTime.fromMillisecondsSinceEpoch(m.createdAt).toIso8601String(),
        'mes': m.text,
        'extra': {'bookmarked': m.bookmarked, 'hidden': m.hidden},
        'swipes': m.swipes,
        'swipe_id': m.swipeIndex,
      }));
    }
    return lines.join('\n');
  }

  Future<ChatSession?> importChatText(
    String characterName,
    String raw, {
    bool jsonl = true,
  }) async {
    final messages = <ChatMessage>[];
    if (jsonl) {
      for (final line in raw.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is! Map) continue;
          final map = Map<String, dynamic>.from(decoded);
          if (map.containsKey('mes')) {
            messages.add(ChatMessage(
              id: 'import-${messages.length}-${DateTime.now().microsecondsSinceEpoch}',
              text: (map['mes'] ?? '').toString(),
              isUser: map['is_user'] == true,
              isSystem: map['is_system'] == true,
              swipes: (map['swipes'] as List?)?.map((e) => e.toString()).toList(),
              swipeIndex: (map['swipe_id'] as num?)?.toInt() ?? 0,
              bookmarked: (map['extra'] is Map && map['extra']['bookmarked'] == true),
              hidden: (map['extra'] is Map && map['extra']['hidden'] == true),
            ));
          }
        } catch (_) {}
      }
    } else {
      for (final line in raw.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final split = trimmed.indexOf(': ');
        if (split <= 0) {
          messages.add(ChatMessage(
            id: 'import-txt-${messages.length}',
            text: trimmed,
          ));
          continue;
        }
        final speaker = trimmed.substring(0, split).trim();
        final text = trimmed.substring(split + 2).trim();
        if (text.isEmpty) continue;
        messages.add(ChatMessage(
          id: 'import-txt-${messages.length}',
          text: text,
          isUser: speaker ==
              (settings.userName.trim().isEmpty
                  ? 'User'
                  : settings.userName),
        ));
      }
    }
    if (messages.isEmpty) return null;
    final session = ChatSession(
      id: 'import-${DateTime.now().microsecondsSinceEpoch}',
      characterName: characterName,
      title: '$characterName · 导入',
      messages: messages,
    );
    sessions.add(session);
    await saveSessions();
    notifyListeners();
    return session;
  }

  Future<void> deletePreset(String id) async {
    presets.removeWhere((p) => p.id == id);
    if (activePresetId == id) {
      activePresetId = presets.isEmpty ? '' : presets.first.id;
    }
    await savePresets();
    notifyListeners();
  }

  Future<void> recordSearch(String query) async {
    final value = query.trim();
    if (value.isEmpty) return;
    final next = [value, ...settings.recentSearches.where((e) => e != value)]
        .take(8)
        .toList();
    settings = settings.copyWith(recentSearches: next);
    await saveSettings();
  }

  Future<void> clearSearches() async {
    settings = settings.copyWith(recentSearches: const []);
    await saveSettings();
  }

  String exportChatTxt(ChatSession session) {
    final buffer = StringBuffer();
    for (final m in session.messages) {
      if (m.isSystem || m.hidden) continue;
      final userName = settings.userName.trim().isEmpty
          ? 'User'
          : settings.userName;
      buffer.writeln('${m.isUser ? userName : session.characterName}: ${m.text}');
      buffer.writeln();
    }
    return buffer.toString();
  }

  String exportBackup() {
    return jsonEncode({
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'characters': characters.map((c) => c.toJson()).toList(),
      'sessions': sessions.map((s) => s.toJson()).toList(),
      'settings': settings.toJson(),
      'lorebooks': lorebooks.map((b) => b.toJson()).toList(),
      'quickReplySets': quickReplySets.map((q) => q.toJson()).toList(),
      'activeQuickSetId': activeQuickSetId,
      'presets': presets.map((p) => p.toJson()).toList(),
      'activePresetId': activePresetId,
      'regexes': regexScripts.map((r) => r.toJson()).toList(),
    });
  }

  Future<bool> importBackup(String raw) async {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      final data = Map<String, dynamic>.from(decoded);
      if (data['characters'] is List) {
        characters
          ..clear()
          ..addAll(
            (data['characters'] as List)
                .whereType<Map>()
                .map((e) => DemoCharacter.fromJson(Map<String, dynamic>.from(e))),
          );
      }
      if (data['sessions'] is List) {
        sessions
          ..clear()
          ..addAll(
            (data['sessions'] as List)
                .whereType<Map>()
                .map((e) => ChatSession.fromJson(Map<String, dynamic>.from(e))),
          );
      }
      if (data['settings'] is Map) {
        settings = AppSettings.fromJson(Map<String, dynamic>.from(data['settings'] as Map));
      }
      if (data['lorebooks'] is List) {
        lorebooks
          ..clear()
          ..addAll(
            (data['lorebooks'] as List)
                .whereType<Map>()
                .map((e) => Lorebook.fromJson(Map<String, dynamic>.from(e))),
          );
      }
      if (data['quickReplySets'] is List) {
        quickReplySets
          ..clear()
          ..addAll(
            (data['quickReplySets'] as List)
                .whereType<Map>()
                .map((e) => QuickReplySet.fromJson(Map<String, dynamic>.from(e))),
          );
        activeQuickSetId = (data['activeQuickSetId'] ?? '').toString();
      }
      if (data['regexes'] is List) {
        regexScripts
          ..clear()
          ..addAll(
            (data['regexes'] as List)
                .whereType<Map>()
                .map((e) => RegexScript.fromJson(Map<String, dynamic>.from(e))),
          );
      }
      if (data['presets'] is List) {
        presets
          ..clear()
          ..addAll(
            (data['presets'] as List)
                .whereType<Map>()
                .map((e) => PromptPreset.fromJson(Map<String, dynamic>.from(e))),
          );
        activePresetId = (data['activePresetId'] ?? '').toString();
      }
      await saveCharacters();
      await saveSessions();
      await saveSettings();
      await saveLorebooks();
      await saveQuickReplies();
      await savePresets();
      await saveRegexes();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> deleteCharacter(
    DemoCharacter character, {
    bool deleteChats = false,
  }) async {
    characters.removeWhere((c) => c.name == character.name);
    if (deleteChats) {
      sessions.removeWhere((s) => s.characterName == character.name);
      await saveSessions();
    }
    await saveCharacters();
    notifyListeners();
  }

  Future<void> replaceCharacter(
    DemoCharacter character, {
    required String previousName,
  }) async {
    final index = characters.indexWhere((c) => c.name == previousName);
    if (index >= 0) {
      characters[index] = character;
    } else {
      final fallback = characters.indexWhere((c) => c.name == character.name);
      if (fallback >= 0) {
        characters[fallback] = character;
      } else {
        characters.add(character);
      }
    }
    if (previousName != character.name) {
      for (final session in sessions) {
        if (session.characterName == previousName) {
          session.characterName = character.name;
        }
      }
      for (final book in lorebooks) {
        if (book.linked == previousName) {
          book.linked = character.name;
        }
      }
      await saveSessions();
      await saveLorebooks();
    }
    await saveCharacters();
    notifyListeners();
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

  Future<Lorebook?> importLorebook(
    Uint8List bytes,
    String fileName,
  ) async {
    final book = parseWorldInfo(bytes, fileName);
    if (book == null) return null;
    await addLorebook(book);
    return book;
  }

  String exportLorebookJson(Lorebook book) =>
      const JsonEncoder.withIndent('  ').convert(lorebookToWorldJson(book));

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

  Future<void> logImportFailures(
    List<String> failures, {
    String source = 'import',
  }) async {
    if (_dir == null || failures.isEmpty) return;
    final file = File('${_dir!.path}/import_failures.log');
    final stamp = DateTime.now().toIso8601String();
    await file.writeAsString(
      '$stamp [$source]\n${failures.join('\n')}\n\n',
      mode: FileMode.append,
    );
  }

  Future<String> readImportFailures() async {
    if (_dir == null) return '';
    final file = File('${_dir!.path}/import_failures.log');
    if (!await file.exists()) return '';
    return file.readAsString();
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
