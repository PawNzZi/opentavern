import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/llm.dart';
import 'package:tavern_app/core/models.dart';

void main() {
  test('OpenAI-compatible model list is fetched and parsed', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <String>[];
    server.listen((request) async {
      requests.add(request.uri.path);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'object': 'list',
        'data': [
          {'id': 'gpt-a'},
          {'id': 'gpt-b'},
        ],
      }));
      await request.response.close();
    });
    final models = await LLMClient().fetchModels(
      APISettings(
        provider: 'openai',
        baseUrl: 'http://127.0.0.1:${server.port}/v1',
        apiKey: 'sk-test',
      ),
    );
    expect(models, containsAll(<String>['gpt-a', 'gpt-b']));
    expect(requests.single, '/v1/models');
    await server.close(force: true);
  });
}
