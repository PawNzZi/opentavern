import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/core/store.dart';

void main() {
  test('JSONL round-trip keeps summary, variables and message metadata', () async {
    final store = AppStore.instance;
    store.sessions.clear();
    final session = ChatSession(
      id: 'export-session',
      characterName: '流程角色',
      title: '导出',
      summary: '已有摘要',
      summaryUpTo: 1,
      variables: const {'hp': '10'},
      messages: [
        ChatMessage(
          id: 'u1',
          text: '你好',
          isUser: true,
          createdAt: 1700000000000,
        ),
        ChatMessage(
          id: 'a1',
          text: '你好呀',
          model: 'gpt-test',
          apiProvider: 'openai',
          promptTokens: 12,
          completionTokens: 3,
          durationMs: 900,
          createdAt: 1700000001000,
        ),
      ],
    );
    final raw = store.exportChatJsonl(session);
    final imported = await store.importChatText('流程角色', raw);
    expect(imported, isNotNull);
    expect(imported!.summary, '已有摘要');
    expect(imported.variables['hp'], '10');
    expect(imported.messages.length, 2);
    final assistant = imported.messages.last;
    expect(assistant.model, 'gpt-test');
    expect(assistant.apiProvider, 'openai');
    expect(assistant.promptTokens, 12);
    expect(assistant.completionTokens, 3);
    expect(assistant.durationMs, 900);
    expect(assistant.createdAt, 1700000001000);
    store.sessions.clear();
  });
}
