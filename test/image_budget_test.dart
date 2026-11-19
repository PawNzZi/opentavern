import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/core/prompt.dart';
import 'package:tavern_app/data/demo.dart';

void main() {
  test('prompt keeps image-only messages and caps images', () {
    final character = DemoCharacter(
      name: '图片角色',
      initial: '图',
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
    ChatAttachment image(String id) => ChatAttachment(
          id: id,
          name: 'x.png',
          mime: 'image/png',
          base64: 'QUJD',
        );
    final session = ChatSession(
      id: 's',
      characterName: character.name,
      title: 't',
      messages: [
        ChatMessage(id: 'u1', text: '', isUser: true, attachments: [image('1')]),
        ChatMessage(id: 'u2', text: '第二张', isUser: true, attachments: [image('2')]),
        ChatMessage(id: 'u3', text: '第三张', isUser: true, attachments: [image('3')]),
      ],
    );
    final built = PromptBuilder.build(
      character: character,
      session: session,
      settings: const AppSettings(),
    );
    final imageParts = built.messages
        .where((m) => m['role'] == 'user')
        .expand((m) => m['content'] is List ? m['content'] as List : const [])
        .whereType<Map>()
        .where((p) => p['type'] == 'image')
        .length;
    expect(imageParts, 2);
    expect(built.messages.any((m) => m['role'] == 'user'), isTrue);
  });
}
