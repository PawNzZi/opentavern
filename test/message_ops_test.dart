import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/chat/chat_controller.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/core/store.dart';
import 'package:tavern_app/data/demo.dart';

void main() {
  test('deleteAfter truncates only later messages', () {
    final character = DemoCharacter(
      name: '消息操作',
      initial: '消',
      title: '',
      tagline: '',
      creator: '',
      version: '',
      description: '',
      greeting: '你好',
      tags: const [],
      lorebook: '',
      preset: '',
      chats: 0,
      tokens: '',
      colors: const [],
    );
    final session = ChatSession(
      id: 'ops',
      characterName: character.name,
      title: 't',
      messages: [
        ChatMessage(id: '1', text: 'one'),
        ChatMessage(id: '2', text: 'two'),
        ChatMessage(id: '3', text: 'three'),
      ],
    );
    final controller = ChatController(character: character, session: session);
    controller.deleteAfter(session.messages.first);
    expect(controller.messages.length, 1);
    expect(controller.messages.first.text, 'one');
    controller.dispose();
  });
}
