import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class LLMException implements Exception {
  LLMException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Direct client-side model access. The app is single-user and local-only, so
/// the API key never leaves the device except in the request to the provider.
class LLMClient {
  Stream<String> stream({
    required AppSettings settings,
    required List<Map<String, String>> messages,
  }) async* {
    final api = settings.api;
    if (api.baseUrl.trim().isEmpty || api.model.trim().isEmpty) {
      throw LLMException('请先在设置中填写 API 地址与模型');
    }
    switch (api.provider) {
      case 'anthropic':
        yield* _anthropic(api, messages);
      case 'gemini':
        yield* _gemini(api, messages);
      case 'ollama':
        yield* _ollama(api, messages);
      default:
        yield* _openAI(api, messages);
    }
  }

  Stream<String> _openAI(
    APISettings api,
    List<Map<String, String>> messages,
  ) async* {
    final client = http.Client();
    try {
      final base = _trim(api.baseUrl);
      final uri = Uri.parse(
        base.endsWith('/chat/completions') ? base : '$base/chat/completions',
      );
      final request = http.Request('POST', uri)
        ..headers.addAll({
          'Content-Type': 'application/json',
          if (api.apiKey.trim().isNotEmpty)
            'Authorization': 'Bearer ${api.apiKey.trim()}',
        })
        ..body = jsonEncode({
          'model': api.model,
          'messages': messages,
          'temperature': api.temperature,
          'max_tokens': api.maxTokens,
          'stream': true,
        });
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        throw LLMException(
          _errorText(body, response.statusCode),
          statusCode: response.statusCode,
        );
      }
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data:')) continue;
        final data = trimmed.substring(5).trim();
        if (data == '[DONE]') break;
        final decoded = _tryJson(data);
        final choices = decoded?['choices'];
        if (choices is! List || choices.isEmpty) continue;
        final delta = choices.first['delta'];
        final content = delta is Map ? delta['content'] : null;
        if (content is String && content.isNotEmpty) yield content;
      }
    } finally {
      client.close();
    }
  }

  Stream<String> _anthropic(
    APISettings api,
    List<Map<String, String>> messages,
  ) async* {
    if (api.apiKey.trim().isEmpty) {
      throw LLMException('Claude 需要在设置中填写 API Key');
    }
    final client = http.Client();
    try {
      final base = _trim(api.baseUrl);
      final uri = Uri.parse(
        base.endsWith('/v1/messages') ? base : '$base/v1/messages',
      );
      String? system;
      final bodyMessages = <Map<String, String>>[];
      for (final message in messages) {
        if (message['role'] == 'system') {
          system = '${system ?? ''}\n${message['content']}'.trim();
        } else {
          bodyMessages.add(message);
        }
      }
      final request = http.Request('POST', uri)
        ..headers.addAll({
          'Content-Type': 'application/json',
          'x-api-key': api.apiKey.trim(),
          'anthropic-version': '2023-06-01',
        })
        ..body = jsonEncode({
          'model': api.model,
          'max_tokens': api.maxTokens,
          'temperature': api.temperature,
          if (system != null && system.isNotEmpty) 'system': system,
          'messages': bodyMessages,
          'stream': true,
        });
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        throw LLMException(
          _errorText(body, response.statusCode),
          statusCode: response.statusCode,
        );
      }
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data:')) continue;
        final decoded = _tryJson(trimmed.substring(5).trim());
        if (decoded == null) continue;
        if (decoded['type'] == 'content_block_delta') {
          final delta = decoded['delta'];
          final text = delta is Map ? delta['text'] : null;
          if (text is String && text.isNotEmpty) yield text;
        }
      }
    } finally {
      client.close();
    }
  }

  Stream<String> _gemini(
    APISettings api,
    List<Map<String, String>> messages,
  ) async* {
    if (api.apiKey.trim().isEmpty) {
      throw LLMException('Gemini 需要在设置中填写 API Key');
    }
    final client = http.Client();
    try {
      final base = _trim(api.baseUrl);
      String? system;
      final contents = <Map<String, dynamic>>[];
      for (final message in messages) {
        if (message['role'] == 'system') {
          system = '${system ?? ''}\n${message['content']}'.trim();
          continue;
        }
        contents.add({
          'role': message['role'] == 'assistant' ? 'model' : 'user',
          'parts': [
            {'text': message['content']},
          ],
        });
      }
      final uri = Uri.parse(
        '$base/models/${Uri.encodeComponent(api.model)}:streamGenerateContent'
        '?alt=sse&key=${Uri.encodeQueryComponent(api.apiKey.trim())}',
      );
      final request = http.Request('POST', uri)
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode({
          'contents': contents,
          if (system != null && system.isNotEmpty)
            'systemInstruction': {
              'parts': [
                {'text': system},
              ],
            },
          'generationConfig': {
            'temperature': api.temperature,
            'maxOutputTokens': api.maxTokens,
          },
        });
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        throw LLMException(
          _errorText(body, response.statusCode),
          statusCode: response.statusCode,
        );
      }
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data:')) continue;
        final decoded = _tryJson(trimmed.substring(5).trim());
        if (decoded == null) continue;
        final candidates = decoded['candidates'];
        if (candidates is! List || candidates.isEmpty) continue;
        final content = candidates.first['content'];
        final parts = content is Map ? content['parts'] : null;
        if (parts is List) {
          for (final part in parts.whereType<Map>()) {
            final text = part['text'];
            if (text is String && text.isNotEmpty) yield text;
          }
        }
      }
    } finally {
      client.close();
    }
  }

  Stream<String> _ollama(
    APISettings api,
    List<Map<String, String>> messages,
  ) async* {
    final client = http.Client();
    try {
      final base = _trim(api.baseUrl);
      final uri = Uri.parse(
        base.endsWith('/api/chat') ? base : '$base/api/chat',
      );
      final request = http.Request('POST', uri)
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode({
          'model': api.model,
          'messages': messages,
          'stream': true,
          'options': {
            'temperature': api.temperature,
            'num_predict': api.maxTokens,
          },
        });
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        throw LLMException(
          _errorText(body, response.statusCode),
          statusCode: response.statusCode,
        );
      }
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.trim().isEmpty) continue;
        final decoded = _tryJson(line.trim());
        if (decoded == null) continue;
        final message = decoded['message'];
        final content = message is Map ? message['content'] : null;
        if (content is String && content.isNotEmpty) yield content;
      }
    } finally {
      client.close();
    }
  }

  String _trim(String value) {
    var base = value.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base;
  }

  Map<String, dynamic>? _tryJson(String text) {
    try {
      final decoded = jsonDecode(text);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  String _errorText(String body, int status) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] != null) {
          return '${error['message']} (HTTP $status)';
        }
        if (decoded['message'] != null) {
          return '${decoded['message']} (HTTP $status)';
        }
      }
    } catch (_) {}
    final trimmed = body.trim();
    if (trimmed.isEmpty) return '请求失败 (HTTP $status)';
    return trimmed.length > 240
        ? '${trimmed.substring(0, 240)}… (HTTP $status)'
        : '$trimmed (HTTP $status)';
  }
}
