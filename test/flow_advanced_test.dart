import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/core/prompt.dart';
import 'package:tavern_app/core/store.dart';
import 'package:tavern_app/data/demo.dart';

DemoCharacter _character({String name = '流程角色', String preset = ''}) =>
    DemoCharacter(
      name: name,
      initial: '流',
      title: '',
      tagline: '',
      creator: '',
      version: '',
      description: '',
      greeting: '',
      tags: const [],
      lorebook: '',
      preset: preset,
      chats: 0,
      tokens: '',
      colors: const [],
    );

ChatSession _session(String id, String characterName) => ChatSession(
      id: id,
      characterName: characterName,
      title: 't',
      messages: [ChatMessage(id: 'm1', text: '你好', isUser: true)],
    );

void main() {
  test('per-chat author note overrides global note', () {
    final character = _character();
    final session = _session('author-session', character.name)
      ..authorNote = '本聊天笔记'
      ..authorNoteOverride = true;
    final built = PromptBuilder.build(
      character: character,
      session: session,
      settings: const AppSettings(authorNote: '全局笔记'),
    );
    final system = built.messages.first['content'] as String;
    expect(system, contains('本聊天笔记'));
    expect(system, isNot(contains('全局笔记')));
  });

  test('summary after_history is sent after chat history', () {
    final character = _character();
    final session = _session('summary-session', character.name)
      ..summary = '前情摘要';
    final built = PromptBuilder.build(
      character: character,
      session: session,
      settings: const AppSettings(summaryPosition: 'after_history'),
    );
    final contents = built.messages.map((m) => '${m['content']}').toList();
    expect(contents.any((c) => c.contains('前情摘要')), isTrue);
    expect(contents.first.contains('前情摘要'), isFalse);
  });

  test('summary at_depth injects into history range', () {
    final character = _character();
    final session = _session('depth-session', character.name)
      ..summary = '深度摘要';
    final built = PromptBuilder.build(
      character: character,
      session: session,
      settings: const AppSettings(
        summaryPosition: 'at_depth',
        summaryDepth: 1,
        summaryRole: 'system',
      ),
    );
    expect(
      built.messages.any((m) => m['content'].toString().contains('深度摘要')),
      isTrue,
    );
  });

  test('character-bound preset main prompt is used', () {
    final character = _character(preset: '专属预设');
    final store = AppStore.instance;
    store.presets
      ..clear()
      ..add(PromptPreset(
        id: 'bound-preset',
        name: '专属预设',
        mainPrompt: 'BOUND_MAIN_PROMPT',
      ));
    final built = PromptBuilder.build(
      character: character,
      session: _session('preset-session', character.name),
      settings: const AppSettings(mainPrompt: 'GLOBAL_MAIN_PROMPT'),
    );
    expect(built.messages.first['content'], contains('BOUND_MAIN_PROMPT'));
    store.presets.clear();
  });

  test('recursive worldbook activation triggers second entry', () {
    final character = _character();
    final store = AppStore.instance;
    store.lorebooks
      ..clear()
      ..add(Lorebook(
        id: 'recursive-book',
        name: '递归书',
        linked: character.name,
        entries: [
          LoreEntry(
            id: 'r1',
            keys: const ['起点'],
            content: '这里提到了终点关键词。',
          ),
          LoreEntry(
            id: 'r2',
            keys: const ['终点'],
            content: '终点条目内容。',
          ),
        ],
      ));
    final session = ChatSession(
      id: 'recursive-session',
      characterName: character.name,
      title: 't',
      messages: [ChatMessage(id: 'm1', text: '起点', isUser: true)],
    );
    final built = PromptBuilder.build(
      character: character,
      session: session,
      settings: const AppSettings(),
    );
    expect(built.messages.first['content'], contains('终点条目内容'));
    store.lorebooks.clear();
  });

  test('branch sessions record parent and main chat', () {
    final store = AppStore.instance;
    final source = ChatSession(
      id: 'main-session',
      characterName: '流程角色',
      title: 'main',
      messages: [ChatMessage(id: 'm1', text: 'hello')],
    );
    store.sessions
      ..clear()
      ..add(source);
    final branch = store.branchSession(source, throughIndex: 0);
    expect(branch.parentId, source.id);
    expect(branch.mainChatId, source.id);
    store.sessions.clear();
  });

  test('chat JSONL import creates a session', () async {
    final store = AppStore.instance;
    store.sessions.clear();
    final raw = [
      jsonEncode({'user_name': 'User', 'character_name': '流程角色'}),
      jsonEncode({'name': 'User', 'is_user': true, 'mes': '你好'}),
      jsonEncode({'name': '流程角色', 'is_user': false, 'mes': '你好呀'}),
    ].join('\n');
    final session = await store.importChatText('流程角色', raw);
    expect(session, isNotNull);
    expect(session!.messages.length, 2);
    store.sessions.clear();
  });

  test('preset defaults to follow-global maxTokens (0)', () {
    final preset = PromptPreset(id: 'p', name: '默认预设');
    expect(preset.maxTokens, 0);
    final parsed = PromptPreset.fromJson({'id': 'p', 'name': 'x'});
    expect(parsed.maxTokens, 0);
    // 0 表示跟随全局；ChatController 只在 >0 时用预设值覆盖全局回复长度。
    const globalMax = 8192;
    final effective = preset.maxTokens > 0 ? preset.maxTokens : globalMax;
    expect(effective, globalMax);
  });

  test('constant worldbook requirement reaches the system prompt', () {
    final character = _character();
    final store = AppStore.instance;
    store.lorebooks
      ..clear()
      ..add(Lorebook(
        id: 'req-book',
        name: '要求书',
        linked: character.name,
        entries: [
          LoreEntry(
            id: 'req',
            constant: true,
            content: '每次回复的最后必须加入角色的心理描写。',
          ),
        ],
      ));
    final built = PromptBuilder.build(
      character: character,
      session: _session('req-session', character.name),
      settings: const AppSettings(),
    );
    expect(
      built.messages.first['content'],
      contains('每次回复的最后必须加入角色的心理描写'),
    );
    store.lorebooks.clear();
  });
}
