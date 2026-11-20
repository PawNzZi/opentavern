import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/core/prompt.dart';
import 'package:tavern_app/data/demo.dart';

void main() {
  test('prompt section order is configurable', () {
    const character = DemoCharacter(
      name: '顺序',
      initial: '顺',
      title: '',
      tagline: '',
      creator: '',
      version: '1',
      description: '角色描述',
      greeting: '',
      tags: [],
      lorebook: '',
      preset: '',
      chats: 0,
      tokens: '0',
      colors: [],
    );
    final session = ChatSession(id: 's', characterName: '顺序', title: 't');
    final normal = PromptBuilder.build(
      character: character,
      session: session,
      settings: const AppSettings(authorNote: '笔记'),
    );
    final normalSystem = normal.messages.first['content'] as String;
    expect(normalSystem.indexOf('角色'), lessThan(normalSystem.indexOf('作者')));
    final reversed = PromptBuilder.build(
      character: character,
      session: session,
      settings: const AppSettings(
        authorNote: '笔记',
        promptOrder: [
          'authorNote',
          'character',
          'main',
        ],
      ),
    );
    final reversedSystem = reversed.messages.first['content'] as String;
    expect(reversedSystem.indexOf('作者'), lessThan(reversedSystem.indexOf('角色')));
  });
}
