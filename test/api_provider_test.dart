import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/models.dart';

void main() {
  test('ProviderProfile round-trips and reports emptiness', () {
    const empty = ProviderProfile();
    expect(empty.isEmpty, true);
    const p = ProviderProfile(
      baseUrl: 'https://api.deepseek.com/v1',
      apiKey: 'sk-deepseek',
      model: 'deepseek-chat',
    );
    expect(p.isEmpty, false);
    final back = ProviderProfile.fromJson(p.toJson());
    expect(back.baseUrl, p.baseUrl);
    expect(back.apiKey, p.apiKey);
    expect(back.model, p.model);
    expect(p.copyWith(apiKey: 'sk-other').apiKey, 'sk-other');
    expect(p.copyWith(apiKey: 'sk-other').baseUrl, p.baseUrl);
  });

  test('APISettings keeps an independent profile per provider', () {
    const api = APISettings(
      provider: 'deepseek',
      baseUrl: 'https://api.deepseek.com/v1',
      apiKey: 'sk-deepseek',
      model: 'deepseek-chat',
      profiles: {
        'deepseek': ProviderProfile(
          baseUrl: 'https://api.deepseek.com/v1',
          apiKey: 'sk-deepseek',
          model: 'deepseek-chat',
        ),
        'openai': ProviderProfile(
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'sk-openai',
          model: 'gpt-4o-mini',
        ),
      },
    );
    final back = APISettings.fromJson(api.toJson());
    expect(back.profiles['deepseek']!.apiKey, 'sk-deepseek');
    expect(back.profiles['openai']!.apiKey, 'sk-openai');
    // 切换服务商时各自取各自的密钥，互不串用。
    expect(back.profiles['openai']!.apiKey, isNot(back.profiles['deepseek']!.apiKey));
  });

  test('legacy single-key settings migrate into the active provider profile', () {
    final api = APISettings.fromJson({
      'provider': 'deepseek',
      'baseUrl': 'https://api.deepseek.com/v1',
      'apiKey': 'sk-legacy',
      'model': 'deepseek-chat',
    });
    expect(api.profiles.containsKey('deepseek'), true);
    expect(api.profiles['deepseek']!.apiKey, 'sk-legacy');
    expect(api.profiles['deepseek']!.baseUrl, 'https://api.deepseek.com/v1');
  });

  test('existing profiles are not overwritten by migration', () {
    final api = APISettings.fromJson({
      'provider': 'openai',
      'baseUrl': 'https://api.openai.com/v1',
      'apiKey': 'sk-active',
      'model': 'gpt-4o-mini',
      'profiles': {
        'openai': {'baseUrl': 'https://api.openai.com/v1', 'apiKey': 'sk-saved', 'model': 'gpt-4o-mini'},
      },
    });
    expect(api.profiles['openai']!.apiKey, 'sk-saved');
  });

  test('configured requires a key except for custom', () {
    const base = APISettings(baseUrl: 'https://x/v1', model: 'm');
    expect(base.copyWith(provider: 'openai', apiKey: '').configured, false);
    expect(base.copyWith(provider: 'openai', apiKey: 'sk').configured, true);
    expect(base.copyWith(provider: 'openrouter', apiKey: '').configured, false);
    expect(base.copyWith(provider: 'suixiang', apiKey: 'sk').configured, true);
    expect(base.copyWith(provider: 'custom', apiKey: '').configured, true);
  });
}
