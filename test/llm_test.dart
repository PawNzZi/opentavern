import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/llm.dart';
import 'package:tavern_app/core/models.dart';

void main() {
  test('OpenAI-compatible SSE is assembled', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType('text', 'event-stream');
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      void event(String content) {
        final data = jsonEncode({
          'choices': [
            {
              'delta': {'content': content},
            },
          ],
        });
        request.response.add(utf8.encode('data: $data\n\n'));
      }

      event('你好');
      event('，世界');
      request.response.add(utf8.encode('data: [DONE]\n\n'));
      await request.response.close();
    });
    final settings = AppSettings(
      api: APISettings(
        provider: 'openai',
        baseUrl: 'http://127.0.0.1:${server.port}/v1',
        model: 'test',
      ),
    );
    final chunks = await LLMClient()
        .stream(
          settings: settings,
          messages: [
            {'role': 'user', 'content': 'hi'},
          ],
        )
        .toList();
    expect(chunks.join(), '你好，世界');
    await server.close(force: true);
  });
}
