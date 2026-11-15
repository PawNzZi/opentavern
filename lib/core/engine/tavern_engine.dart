/// 生成引擎：把提示词交给供应商，流式返回；摘要也走同一条通道。
library;

import '../ai/provider_client.dart';
import '../models/tavern_card.dart';
import '../settings/app_settings.dart';
import 'prompt.dart';

class TavernEngine {
  TavernEngine({required this.settings, ProviderClient? client})
      : client = client ?? ProviderClient();

  final AppSettings settings;
  final ProviderClient client;

  bool get ready => settings.hasProvider;

  String get notReadyMessage => '还没有配置 AI 供应商，去「设置 → AI 供应商」填写后即可对话。';

  /// 拼一轮提示词。
  BuiltPrompt build({
    required Map<String, dynamic> chat,
    required Map<String, dynamic> character,
    required List<TavernWorld> worlds,
    required String userText,
  }) {
    return buildPrompt(
      character: character,
      worlds: worlds,
      chat: chat,
      userText: userText,
      settings: settings,
    );
  }

  /// 流式生成；[onDelta] 逐段回调。
  Stream<String> stream({
    required BuiltPrompt prompt,
    int? maxTokens,
    double? temperature,
    List<String>? stop,
  }) {
    if (!ready) {
      throw ProviderException(notReadyMessage);
    }
    return client.streamChat(
      config: settings.provider,
      messages: prompt.messages,
      maxTokens: maxTokens ?? settings.maxTokens,
      temperature: temperature ?? settings.temperature,
      stop: stop,
    );
  }

  /// 摘要用：一次性收集完整文本。
  Future<String> summarize(String system, String user, int maxTokens) async {
    if (!ready) {
      throw ProviderException(notReadyMessage);
    }
    final StringBuffer buffer = StringBuffer();
    await for (final String delta in client.streamChat(
      config: settings.provider,
      messages: <Map<String, dynamic>>[
        <String, dynamic>{
          'role': 'system',
          'content': <Map<String, String>>[<String, String>{'type': 'text', 'text': system}],
        },
        <String, dynamic>{
          'role': 'user',
          'content': <Map<String, String>>[<String, String>{'type': 'text', 'text': user}],
        },
      ],
      maxTokens: maxTokens,
      temperature: 0.2,
    )) {
      buffer.write(delta);
    }
    return buffer.toString().trim();
  }
}
