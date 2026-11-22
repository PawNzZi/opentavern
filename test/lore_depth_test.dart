import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/core/prompt.dart';
import 'package:tavern_app/core/store.dart';
import 'package:tavern_app/data/demo.dart';

void main() {
  test('at_depth lore is injected into history', () {
    final character = DemoCharacter(
      name: '深度角色',
      initial: '深',
      title: '',
      tagline: '',
      creator: '',
      version: '',
      description: '',
      greeting: '',
      tags: const [],
      lorebook: '',
      preset: '',
      chats: 0,
      tokens: '',
      colors: const [],
    );
    AppStore.instance.lorebooks
      ..clear()
      ..add(Lorebook(
        id: 'depth-book',
        name: '深度书',
        linked: character.name,
        entries: [
          LoreEntry(
            id: 'de1',
            keys: const ['王都'],
            content: '深度注入内容',
            position: 'at_depth',
            depth: 1,
            role: 'assistant',
          ),
        ],
      ));
    final session = ChatSession(
      id: 'depth-flow',
      characterName: character.name,
      title: 't',
      messages: [
        ChatMessage(id: 'u1', text: '王都', isUser: true),
        ChatMessage(id: 'a1', text: '嗯', isUser: false),
      ],
    );
    final built = PromptBuilder.build(
      character: character,
      session: session,
      settings: const AppSettings(),
    );
    final found = built.messages.any(
      (m) =>
          m['role'] == 'assistant' &&
          m['content'].toString().contains('深度注入内容'),
    );
    expect(found, isTrue);
    AppStore.instance.lorebooks.clear();
  });
}
