import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/llm.dart';
import 'package:tavern_app/core/models.dart';

void main() {
  test('OpenAI request carries image content parts', () async {
    String? body;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      body = await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType('text', 'event-stream');
      request.response.add(
        utf8.encode(
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': 'ok'},
              },
            ],
          })}\n\n',
        ),
      );
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
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': '描述这张图'},
                {'type': 'image', 'mime': 'image/png', 'base64': 'QUJD'},
              ],
            },
          ],
        )
        .toList();
    expect(chunks.join(), 'ok');
    expect(body, contains('image_url'));
    expect(body, contains('data:image/png;base64,QUJD'));
    await server.close(force: true);
  });
}
