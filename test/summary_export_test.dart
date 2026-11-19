import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/core/prompt.dart';
import 'package:tavern_app/core/store.dart';
import 'package:tavern_app/data/demo.dart';

void main() {
  test('summary enters prompt and chat export contains messages', () {
    final character = DemoCharacter(
      name: '摘要角色',
      initial: '摘',
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
      id: 'summary-test',
      characterName: character.name,
      title: 'test',
      summary: '他们曾在雨夜相遇。',
      messages: [
        ChatMessage(id: 'm1', text: '你好', isUser: true),
        ChatMessage(id: 'm2', text: '欢迎。'),
      ],
    );
    final built = PromptBuilder.build(
      character: character,
      session: session,
      settings: const AppSettings(),
    );
    expect(built.messages.first['content'], contains('他们曾在雨夜相遇。'));

    final jsonl = AppStore.instance.exportChatJsonl(session);
    expect(jsonl, contains('"mes":"你好"'));
    expect(jsonl, contains('"mes":"欢迎。"'));
  });
}
