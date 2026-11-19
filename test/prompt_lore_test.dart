import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/core/prompt.dart';
import 'package:tavern_app/core/store.dart';
import 'package:tavern_app/data/demo.dart';

void main() {
  test('linked lorebook entries enter the prompt on keyword match', () {
    final character = DemoCharacter(
      name: '测试角色',
      initial: '测',
      title: '',
      tagline: '',
      creator: '',
      version: '',
      description: '',
      greeting: '',
      tags: const [],
      lorebook: '测试世界书',
      preset: '',
      chats: 0,
      tokens: '',
      colors: const [],
    );
    final book = Lorebook(
      id: 'test-book',
      name: '测试世界书',
      linked: character.name,
      entries: [
        LoreEntry(
          id: 'e1',
          keys: const ['王都'],
          content: '王都的雨意味着预言即将发生。',
        ),
      ],
    );
    AppStore.instance.lorebooks
      ..clear()
      ..add(book);
    final session = ChatSession(
      id: 's1',
      characterName: character.name,
      title: 'test',
      messages: [
        ChatMessage(id: 'm1', text: '王都下雨了', isUser: true),
      ],
    );
    final built = PromptBuilder.build(
      character: character,
      session: session,
      settings: const AppSettings(),
    );
    expect(built.messages.first['content'], contains('王都的雨意味着预言即将发生。'));
  });
}
