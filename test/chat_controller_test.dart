import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/chat/chat_controller.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/core/store.dart';
import 'package:tavern_app/data/demo.dart';

void main() {
  test('chat controller streams and persists in memory', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType('text', 'event-stream');
      final data = jsonEncode({
        'choices': [
          {
            'delta': {'content': '星图回答'},
          },
        ],
      });
      request.response.add(utf8.encode('data: $data\n\n'));
      request.response.add(utf8.encode('data: [DONE]\n\n'));
      await request.response.close();
    });

    final character = DemoCharacter(
      name: '测试角色',
      initial: '测',
      title: '测试',
      tagline: '测试',
      creator: 'test',
      version: '1',
      description: '一个测试角色。',
      greeting: '你好。',
      tags: const [],
      lorebook: '',
      preset: '',
      chats: 0,
      tokens: '0',
      colors: const [],
    );
    final store = AppStore.instance;
    store.sessions.clear();
    store.characters
      ..clear()
      ..add(character);
    store.settings = AppSettings(
      api: APISettings(
        provider: 'openai',
        baseUrl: 'http://127.0.0.1:${server.port}/v1',
        model: 'test',
      ),
    );

    final controller = ChatController(character: character);
    controller.send('你好');
    for (var i = 0; i < 100 && controller.isGenerating; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final last = controller.messages.last;
    expect(last.isUser, isFalse);
    expect(last.text, contains('星图回答'));
    controller.dispose();
    await server.close(force: true);
  });
}
