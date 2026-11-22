import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/core/prompt.dart';
import 'package:tavern_app/data/demo.dart';

void main() {
  test('user quote and parentheses become typed prompt segments', () {
    final character = DemoCharacter(
      name: '占位角色',
      initial: '占',
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
    final session = ChatSession(
      id: 'roleplay-session',
      characterName: character.name,
      title: 't',
      messages: [
        ChatMessage(
          id: 'm1',
          text: '“你好”（站在门口）',
          isUser: true,
        ),
      ],
    );
    final built = PromptBuilder.build(
      character: character,
      session: session,
      settings: const AppSettings(),
    );
    final text = built.messages.map((m) => '${m['content']}').join('\n');
    expect(text, contains('[用户发言] 你好'));
    expect(text, contains('[用户环境/动作] 站在门口'));
  });
}
