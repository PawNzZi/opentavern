import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/core/prompt.dart';
import 'package:tavern_app/core/store.dart';
import 'package:tavern_app/data/demo.dart';

DemoCharacter _character({String lorebook = ''}) => DemoCharacter(
      name: '联动角色',
      initial: '联',
      title: '',
      tagline: '',
      creator: '',
      version: '',
      description: '',
      greeting: '',
      tags: const [],
      lorebook: lorebook,
      preset: '',
      chats: 0,
      tokens: '',
      colors: const [],
    );

void main() {
  test('card-bound worldbook enters the prompt', () {
    final character = _character(lorebook: '角色绑定书');
    final book = Lorebook(
      id: 'bound-book',
      name: '角色绑定书',
      entries: [
        LoreEntry(
          id: 'bound-e1',
          keys: const ['王都'],
          content: '王都下着雨。',
        ),
      ],
    );
    final store = AppStore.instance;
    store.lorebooks
      ..clear()
      ..add(book);
    final session = ChatSession(
      id: 'flow-session',
      characterName: character.name,
      title: 't',
      messages: [ChatMessage(id: 'm1', text: '王都下雨了', isUser: true)],
    );
    final built = PromptBuilder.build(
      character: character,
      session: session,
      settings: const AppSettings(),
    );
    expect(built.messages.first['content'], contains('王都下着雨'));
    store.lorebooks.clear();
  });

  test('extreme context settings do not crash prompt build', () {
    final character = _character();
    final session = ChatSession(
      id: 'tiny-session',
      characterName: character.name,
      title: 't',
      messages: [ChatMessage(id: 'm1', text: '你好', isUser: true)],
    );
    const settings = AppSettings(
      maxContext: 2048,
      tokenPadding: 2048,
      api: APISettings(maxTokens: 4096),
    );
    expect(
      () => PromptBuilder.build(
        character: character,
        session: session,
        settings: settings,
      ),
      returnsNormally,
    );
  });

  test('backup keeps regex scripts', () {
    final store = AppStore.instance;
    store.regexScripts.add(
      RegexScript(
        id: 'backup-regex',
        name: '测试正则',
        find: 'foo',
        replace: 'bar',
      ),
    );
    final decoded = jsonDecode(store.exportBackup()) as Map;
    final regexes = decoded['regexes'] as List;
    expect(regexes.any((e) => e['name'] == '测试正则'), isTrue);
    store.regexScripts.clear();
  });
}
