import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/core/prompt.dart';
import 'package:tavern_app/data/demo.dart';

void main() {
  test('text attachments are injected into prompt content', () {
    final character = DemoCharacter(
      name: '文件角色',
      initial: '文',
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
      id: 's',
      characterName: character.name,
      title: 't',
      messages: [
        ChatMessage(
          id: 'm',
          text: '看看这个',
          isUser: true,
          attachments: [
            ChatAttachment(
              id: 'a',
              name: 'notes.txt',
              mime: 'text/plain',
              text: '这是一段附件内容。',
            ),
          ],
        ),
      ],
    );
    final built = PromptBuilder.build(
      character: character,
      session: session,
      settings: const AppSettings(),
    );
    final user = built.messages.firstWhere((m) => m['role'] == 'user');
    expect(user['content'].toString(), contains('notes.txt'));
    expect(user['content'].toString(), contains('这是一段附件内容。'));
  });
}
