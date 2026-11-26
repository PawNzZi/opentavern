import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/core/store.dart';
import 'package:tavern_app/data/demo.dart';

DemoCharacter _charWith({String provider = '', String model = ''}) => DemoCharacter(
      name: '测试角色',
      initial: '测',
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
      colors: const [Color(0xFF6B4E3D)],
      providerOverride: provider,
      modelOverride: model,
    );

void main() {
  test('character provider/model overrides round-trip through JSON', () {
    final c = _charWith(provider: 'deepseek', model: 'deepseek-chat');
    final back = DemoCharacter.fromJson(c.toJson());
    expect(back.providerOverride, 'deepseek');
    expect(back.modelOverride, 'deepseek-chat');
  });

  test('apiForCharacter follows global when no override', () {
    final store = AppStore.instance;
    store.settings = const AppSettings(
      api: APISettings(
        provider: 'openai',
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'sk-openai',
        model: 'gpt-4o-mini',
      ),
    );
    final api = store.apiForCharacter(_charWith());
    expect(api.provider, 'openai');
    expect(api.baseUrl, 'https://api.openai.com/v1');
    expect(api.model, 'gpt-4o-mini');
  });

  test('apiForCharacter uses the character provider profile', () {
    final store = AppStore.instance;
    store.settings = const AppSettings(
      api: APISettings(
        provider: 'openai',
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'sk-openai',
        model: 'gpt-4o-mini',
        profiles: {
          'deepseek': ProviderProfile(
            baseUrl: 'https://api.deepseek.com/v1',
            apiKey: 'sk-ds',
            model: 'deepseek-chat',
          ),
        },
      ),
    );
    final api = store.apiForCharacter(_charWith(provider: 'deepseek'));
    expect(api.provider, 'deepseek');
    expect(api.baseUrl, 'https://api.deepseek.com/v1');
    expect(api.apiKey, 'sk-ds');
    expect(api.model, 'deepseek-chat');
  });

  test('apiForCharacter falls back to provider defaults without profile', () {
    final store = AppStore.instance;
    store.settings = const AppSettings();
    final api = store.apiForCharacter(_charWith(provider: 'openrouter'));
    expect(api.provider, 'openrouter');
    expect(api.baseUrl.contains('openrouter.ai'), true);
    expect(api.model, 'openrouter/auto');
  });

  test('apiForCharacter model override wins', () {
    final store = AppStore.instance;
    store.settings = const AppSettings(
      api: APISettings(
        provider: 'openai',
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'k',
        model: 'gpt-4o-mini',
      ),
    );
    final api = store.apiForCharacter(_charWith(model: 'gpt-4o'));
    expect(api.model, 'gpt-4o');
  });
}
