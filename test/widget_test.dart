import 'package:flutter_test/flutter_test.dart';
import 'package:open_tavern/core/ai/provider_client.dart';

void main() {
  group('AiProviderConfig', () {
    test('四项齐全才算配置完成', () {
      const AiProviderConfig empty = AiProviderConfig(
        kind: 'deepseek',
        baseUrl: '',
        apiKey: '',
        model: '',
      );
      expect(empty.isComplete, isFalse);

      const AiProviderConfig filled = AiProviderConfig(
        kind: 'deepseek',
        baseUrl: 'https://api.deepseek.com/v1',
        apiKey: 'sk-test',
        model: 'deepseek-chat',
      );
      expect(filled.isComplete, isTrue);
    });

    test('Base URL 去掉尾部斜杠', () {
      const AiProviderConfig config = AiProviderConfig(
        kind: 'custom',
        baseUrl: 'https://example.com/v1///',
        apiKey: 'k',
        model: 'm',
      );
      expect(config.normalizedBaseUrl, 'https://example.com/v1');
    });

    test('内置供应商有默认地址', () {
      expect(
        ProviderClient.defaultBaseUrls['deepseek'],
        'https://api.deepseek.com/v1',
      );
      expect(
        ProviderClient.defaultBaseUrls['openrouter'],
        'https://openrouter.ai/api/v1',
      );
    });
  });
}
