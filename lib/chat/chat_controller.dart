import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/llm.dart';
import '../core/models.dart';
import '../core/prompt.dart';
import '../core/regex.dart';
import '../core/store.dart';
import '../data/demo.dart';

export '../core/models.dart' show ChatMessage;

/// Real chat state machine backed by the local store and a direct model API.
class ChatController extends ChangeNotifier {
  ChatController({required this.character, ChatSession? session}) {
    _session = session ?? AppStore.instance.sessionFor(character);
    if (_session.messages.isEmpty && character.greeting.trim().isNotEmpty) {
      _session.messages.add(
        ChatMessage(
          id: 'greet-${DateTime.now().microsecondsSinceEpoch}',
          text: character.greeting,
          time: _time(),
        ),
      );
    }
  }

  final DemoCharacter character;
  late final ChatSession _session;

  List<ChatMessage> get messages => _session.messages;
  ChatSession get session => _session;

  bool isGenerating = false;
  ChatMessage? streamingMessage;

  StreamSubscription<String>? _sub;
  bool _disposed = false;
  bool _regenerating = false;
  bool _continuing = false;
  bool _summarizing = false;

  String _time() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void send(String text) {
    final value = text.trim();
    if (value.isEmpty || isGenerating) return;
    messages.add(
      ChatMessage(
        id: 'm${DateTime.now().microsecondsSinceEpoch}',
        text: value,
        isUser: true,
        time: _time(),
      ),
    );
    _session.updatedAt = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    _save();
    _startGeneration();
  }

  Future<void> _startGeneration({
    bool regenerate = false,
    bool continuation = false,
  }) async {
    if (isGenerating) return;
    isGenerating = true;
    _regenerating = regenerate;
    _continuing = continuation;

    if (!regenerate && !continuation) {
      final message = ChatMessage(
        id: 'm${DateTime.now().microsecondsSinceEpoch}',
        text: '',
        time: _time(),
      );
      messages.add(message);
      streamingMessage = message;
    } else {
      final last = _lastAssistant();
      if (last == null) {
        isGenerating = false;
        notifyListeners();
        return;
      }
      if (regenerate) {
        last.text = '';
        last.time = _time();
      }
      streamingMessage = last;
    }
    notifyListeners();

    try {
      final prompt = PromptBuilder.build(
        character: character,
        session: _session,
        settings: AppStore.instance.settings,
      );
      final client = LLMClient();
      final stream = client.stream(
        settings: AppStore.instance.settings,
        messages: prompt.messages,
      );
      _sub = stream.timeout(const Duration(seconds: 60), onTimeout: (sink) {
        sink.addError(TimeoutException('请求超时，请检查网络或 API 地址'));
        sink.close();
      }).listen(
        (chunk) {
          final message = streamingMessage;
          if (message == null || _disposed) return;
          message.text += chunk;
          notifyListeners();
        },
        onError: (Object error) {
          _fail(error);
        },
        onDone: () {
          _finishStream();
        },
        cancelOnError: true,
      );
    } catch (error) {
      _fail(error);
    }
  }

  void _fail(Object error) {
    final message = streamingMessage;
    if (message != null) {
      final readable = error is LLMException ? error.message : error.toString();
      message.text = message.text.trim().isEmpty
          ? '⚠️ $readable'
          : '${message.text}\n\n⚠️ $readable';
      message.time = _time();
    }
    _finishStream();
  }

  void _finishStream() {
    final message = streamingMessage;
    if (message != null) {
      final text = message.text.trim();
      final cleaned = applyRegexScripts(
        text.isEmpty ? '……' : text,
        AppStore.instance.regexScripts,
        stage: 'display',
        characterName: character.name,
      );
      message.text = cleaned;
      message.time = _time();
      if (_regenerating) {
        if (message.swipes.isEmpty ||
            message.swipes.every((s) => s.trim().isEmpty)) {
          message.swipes = [message.text];
        } else if (!message.swipes.contains(message.text)) {
          message.swipes.insert(0, message.text);
        }
        message.swipeIndex = message.swipes.indexOf(message.text);
      } else if (_continuing) {
        if (message.swipes.isEmpty) {
          message.swipes = [message.text];
        } else {
          final index = message.swipeIndex.clamp(0, message.swipes.length - 1);
          message.swipes[index] = message.text;
        }
      } else if (message.swipes.isEmpty ||
          message.swipes.every((s) => s.isEmpty)) {
        message.swipes = [message.text];
        message.swipeIndex = 0;
      }
    }
    streamingMessage = null;
    isGenerating = false;
    _regenerating = false;
    _continuing = false;
    _sub = null;
    if (_disposed) return;
    _session.updatedAt = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    _save();
    _maybeSummarize();
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _finishStream();
  }

  void regenerate() {
    if (isGenerating) return;
    if (_lastAssistant() == null) return;
    _startGeneration(regenerate: true);
  }

  void continueLast() {
    if (isGenerating) return;
    final last = _lastAssistant();
    if (last == null) return;
    _startGeneration(continuation: true);
  }

  void impersonate() {
    if (isGenerating) return;
    messages.add(
      ChatMessage(
        id: 'm${DateTime.now().microsecondsSinceEpoch}',
        text: '（ impersonate 需要模型生成，请直接输入你的回复 ）',
        isUser: true,
        time: _time(),
      ),
    );
    notifyListeners();
    _save();
  }

  void swipe(int delta) {
    if (isGenerating) return;
    final message = _lastAssistant();
    if (message == null || message.swipes.length < 2) return;
    final next =
        (message.swipeIndex + delta + message.swipes.length) %
        message.swipes.length;
    message.swipeIndex = next;
    message.text = message.swipes[next];
    notifyListeners();
    _save();
  }

  void edit(ChatMessage message, String text) {
    message.text = text.trim();
    if (message.swipes.isEmpty) {
      message.swipes = [message.text];
    } else {
      final index = message.swipeIndex.clamp(0, message.swipes.length - 1);
      message.swipes[index] = message.text;
    }
    message.time = _time();
    notifyListeners();
    _save();
  }

  void delete(ChatMessage message) {
    messages.remove(message);
    notifyListeners();
    _save();
  }

  void toggleHidden(ChatMessage message) {
    message.hidden = !message.hidden;
    message.isSystem = message.hidden;
    notifyListeners();
    _save();
  }

  void toggleBookmark(ChatMessage message) {
    message.bookmarked = !message.bookmarked;
    notifyListeners();
    _save();
  }

  ChatSession? branchAt(ChatMessage message) {
    final index = messages.indexOf(message);
    if (index < 0) return null;
    return AppStore.instance.branchSession(_session, throughIndex: index);
  }

  ChatMessage? _lastAssistant() {
    for (var i = messages.length - 1; i >= 0; i--) {
      if (!messages[i].isUser) return messages[i];
    }
    return null;
  }

  Future<void> summarizeNow() async {
    if (_summarizing || isGenerating) return;
    await _summarize();
  }

  Future<void> _maybeSummarize() async {
    final settings = AppStore.instance.settings;
    if (!settings.memoryEnabled || _summarizing) return;
    if (_session.messages.length - _session.summaryUpTo < settings.summaryInterval) {
      return;
    }
    await _summarize();
  }

  Future<void> _summarize() async {
    _summarizing = true;
    try {
      final settings = AppStore.instance.settings;
      final interval = settings.summaryInterval.clamp(4, 100);
      final recent = _session.messages
          .where((m) => !m.hidden && !m.isSystem && m.text.trim().isNotEmpty)
          .toList();
      final start = (recent.length - interval).clamp(0, recent.length);
      final transcript = recent
          .sublist(start)
          .map((m) => '${m.isUser ? settings.userName : character.name}: ${m.text}')
          .join('\n\n');
      if (transcript.trim().isEmpty) return;
      final buffer = StringBuffer();
      final stream = LLMClient().stream(
        settings: settings,
        messages: [
          {'role': 'system', 'content': settings.summaryPrompt},
          {'role': 'user', 'content': transcript},
        ],
      );
      await for (final chunk in stream) {
        buffer.write(chunk);
        if (buffer.length > 8000) break;
      }
      if (_disposed) return;
      final summary = buffer.toString().trim();
      if (summary.isEmpty) return;
      _session.summary = summary;
      _session.summaryUpTo = _session.messages.length;
      _save();
      notifyListeners();
    } catch (_) {
      // Quiet failure: memory must never break the main chat.
    } finally {
      _summarizing = false;
    }
  }

  void _save() {
    AppStore.instance.saveSessions();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}
