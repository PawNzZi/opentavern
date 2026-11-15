/// OpenAI 兼容供应商客户端（Dart 版，取代旧插件里的 provider.js）。
///
/// 只做单机 App 需要的两件事：列模型、流式对话。
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class AiProviderConfig {
  const AiProviderConfig({
    required this.kind,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  /// `deepseek` / `openrouter` / `custom`
  final String kind;
  final String baseUrl;
  final String apiKey;
  final String model;

  /// 四项齐全才算配置完成。
  bool get isComplete =>
      baseUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty && model.trim().isNotEmpty;

  String get normalizedBaseUrl =>
      baseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  AiProviderConfig copyWith({String? model}) {
    return AiProviderConfig(
      kind: kind,
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model ?? this.model,
    );
  }
}

class ProviderModel {
  const ProviderModel(this.id, this.name);

  final String id;
  final String name;
}

class ProviderException implements Exception {
  ProviderException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProviderClient {
  ProviderClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const Map<String, String> defaultBaseUrls = <String, String>{
    'deepseek': 'https://api.deepseek.com/v1',
    'openrouter': 'https://openrouter.ai/api/v1',
  };

  Map<String, String> _headers(AiProviderConfig config) {
    final Map<String, String> headers = <String, String>{
      'authorization': 'Bearer ${config.apiKey.trim()}',
      'content-type': 'application/json',
    };
    if (config.kind == 'openrouter') {
      headers['HTTP-Referer'] = 'https://github.com/PawNzZi/open-tavern';
      headers['X-Title'] = 'OpenTavern';
    }
    return headers;
  }

  /// 拉取模型列表。
  Future<List<ProviderModel>> listModels(AiProviderConfig config) async {
    final Uri uri = Uri.parse('${config.normalizedBaseUrl}/models');
    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: _headers(config))
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw ProviderException('拉取模型超时，请检查网络或 Base URL');
    }
    if (response.statusCode != 200) {
      String detail = response.body;
      try {
        final Object? json = jsonDecode(response.body);
        if (json is Map && json['error'] is Map) {
          detail = '${(json['error'] as Map)['message'] ?? detail}';
        }
      } catch (_) {
        // 保持原始文本
      }
      throw ProviderException('拉取模型失败（HTTP ${response.statusCode}）：$detail');
    }
    final Object? parsed = jsonDecode(response.body);
    final List<dynamic> rows = parsed is Map && parsed['data'] is List
        ? parsed['data'] as List<dynamic>
        : (parsed is List ? parsed : <dynamic>[]);
    final List<ProviderModel> models = <ProviderModel>[];
    final Set<String> seen = <String>{};
    for (final Object? row in rows) {
      if (row is! Map) continue;
      final String id = '${row['id'] ?? row['name'] ?? ''}'.trim();
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      final String name = '${row['name'] ?? ''}'.trim();
      models.add(ProviderModel(id, name.isEmpty ? id : name));
    }
    models.sort((ProviderModel a, ProviderModel b) => a.id.compareTo(b.id));
    return models;
  }

  /// 流式对话：逐段产出增量文本。
  Stream<String> streamChat({
    required AiProviderConfig config,
    required List<Map<String, String>> messages,
    int? maxTokens,
    double? temperature,
    List<String>? stop,
    Future<void>? abortTrigger,
  }) async* {
    final Uri uri = Uri.parse('${config.normalizedBaseUrl}/chat/completions');
    final Map<String, dynamic> body = <String, dynamic>{
      'model': config.model.trim(),
      'messages': messages,
      'stream': true,
    };
    if (maxTokens != null && maxTokens > 0) {
      body['max_tokens'] = maxTokens.clamp(1, 32768);
    }
    if (temperature != null && temperature >= 0) {
      body['temperature'] = temperature.clamp(0, 2);
    }
    if (stop != null && stop.isNotEmpty) {
      body['stop'] = stop.take(8).toList(growable: false);
    }

    final http.Request request = http.Request('POST', uri)
      ..headers.addAll(_headers(config))
      ..body = jsonEncode(body);

    final http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw ProviderException('供应商连接超时');
    }
    if (response.statusCode != 200) {
      final String text = await response.stream.bytesToString();
      String detail = text;
      try {
        final Object? json = jsonDecode(text);
        if (json is Map && json['error'] is Map) {
          detail = '${(json['error'] as Map)['message'] ?? text}';
        }
      } catch (_) {
        // 保持原文
      }
      throw ProviderException('供应商返回 HTTP ${response.statusCode}：$detail');
    }

    final Stream<String> lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final String rawLine in lines) {
      final String line = rawLine.trim();
      if (line.isEmpty || line.startsWith(':')) continue;
      if (!line.startsWith('data:')) continue;
      final String data = line.substring(5).trim();
      if (data == '[DONE]') return;
      Object? json;
      try {
        json = jsonDecode(data);
      } catch (_) {
        continue;
      }
      if (json is! Map) continue;
      final Object? choices = json['choices'];
      if (choices is! List || choices.isEmpty) continue;
      final Object? choice = choices.first;
      if (choice is! Map) continue;
      final Object? delta = choice['delta'];
      if (delta is Map) {
        final Object? content = delta['content'];
        if (content is String && content.isNotEmpty) {
          yield content;
        }
      }
    }
  }

  void close() => _client.close();
}
