import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/llm.dart';
import '../core/models.dart';
import '../core/prompt.dart';
import '../core/statusbar.dart';
import '../core/store.dart';
import '../data/demo.dart';

export '../core/models.dart' show ChatMessage;

/// Real chat state machine backed by the local store and a direct model API.
class ChatController extends ChangeNotifier {
  ChatController({required this.character, ChatSession? session}) {
    _session = session ?? AppStore.instance.sessionFor(character);
    _initStatusBar();
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

  /// 角色卡自带 regex_scripts 的状态识别模式（适配任意卡的关键）。
  late final List<RegExp> _cardPatterns = StatusBar.cardPatterns(character.rawJson);

  List<ChatMessage> get messages => _session.messages;
  ChatSession get session => _session;

  bool isGenerating = false;
  ChatMessage? streamingMessage;

  StreamSubscription<String>? _sub;
  bool _disposed = false;
  bool _regenerating = false;
  bool _continuing = false;
  bool _summarizing = false;
  DateTime? _generationStartedAt;
  int _promptTokens = 0;
  late AppSettings _activeSettings;

  String _time() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  /// 若角色世界书带 [InitVar] 初始值条目、且会话还没有变量树，则解析为状态栏初值。
  void _initStatusBar() {
    if (_session.statData.isNotEmpty) return;
    final init = StatusBar.findInitContent(character);
    if (init != null && init.trim().isNotEmpty) {
      final parsed = StatusBar.parseInit(init);
      if (parsed.isNotEmpty) {
        _session.statData = parsed;
        _save();
        return;
      }
    }
    // 整段输出型卡片（无 InitVar）：从最近一条含状态块的消息回填初始状态。
    for (var i = _session.messages.length - 1; i >= 0; i--) {
      final m = _session.messages[i];
      if (m.isUser) continue;
      final full = StatusBar.extractStatus(m.text, cardPatterns: _cardPatterns);
      if (full != null && full.isNotEmpty) {
        _session.statData = full;
        _save();
        return;
      }
    }
  }

  /// 应用回复里的状态更新：MVU 差分累积到变量树；整段状态输出则直接替换。
  void _applyStatusUpdate(String text) {
    if (StatusBar.hasUpdate(text)) {
      final ops = StatusBar.extractOps(text);
      if (ops.isNotEmpty) {
        _session.statData = StatusBar.applyOps(_session.statData, ops);
      }
      return;
    }
    final full = StatusBar.extractStatus(text, cardPatterns: _cardPatterns);
    if (full != null && full.isNotEmpty) {
      _session.statData = full;
    }
  }

  void send(String text, {List<ChatAttachment> attachments = const []}) {
    final value = text.trim();
    if ((value.isEmpty && attachments.isEmpty) || isGenerating) return;
    messages.add(
      ChatMessage(
        id: 'm${DateTime.now().microsecondsSinceEpoch}',
        text: value,
        isUser: true,
        time: _time(),
        attachments: attachments,
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
    _generationStartedAt = DateTime.now();
    final baseSettings = AppStore.instance.settings;
    final preset = AppStore.instance.presetForCharacter(character);
    _activeSettings = preset == null
        ? baseSettings
        : baseSettings.copyWith(
            api: baseSettings.api.copyWith(
              temperature: preset.temperature,
              // 预设 maxTokens<=0 表示「跟随全局生成参数」，避免默认预设
              // 悄悄把回复长度压回 512 导致长回复（含结尾心理描写）被截断。
              maxTokens: preset.maxTokens > 0
                  ? preset.maxTokens
                  : baseSettings.api.maxTokens,
            ),
          );

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
        settings: _activeSettings,
      );
      _promptTokens = prompt.approxTokens;
      final client = LLMClient();
      final stream = client.stream(
        settings: _activeSettings,
        messages: prompt.messages,
      );
      _sub = stream.timeout(const Duration(seconds: 180), onTimeout: (sink) {
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
      message.model = _activeSettings.api.model;
      message.apiProvider = _activeSettings.api.provider;
      message.promptTokens = _promptTokens;
      message.completionTokens = estimateTokens(message.text);
      message.durationMs = _generationStartedAt == null
          ? null
          : DateTime.now()
              .difference(_generationStartedAt!)
              .inMilliseconds;
    }
    _finishStream();
  }

  void _finishStream() {
    final message = streamingMessage;
    if (message != null) {
      final text = message.text.trim();
      // Store the raw model output. Display-only regex is applied when the
      // message is rendered, never written back into chat history.
      message.text = text.isEmpty ? '……' : text;
      // 状态栏变量更新只在收到回复时应用一次；正文里的状态块在显示/发送时剥离。
      _applyStatusUpdate(message.text);
      message.time = _time();
      message.model = _activeSettings.api.model;
      message.apiProvider = _activeSettings.api.provider;
      message.promptTokens = _promptTokens;
      message.completionTokens = estimateTokens(message.text);
      message.durationMs = _generationStartedAt == null
          ? null
          : DateTime.now()
              .difference(_generationStartedAt!)
              .inMilliseconds;
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
    final receivedMessage = message != null &&
        message.text.trim().isNotEmpty &&
        !message.text.trim().startsWith('⚠️');
    if (_disposed) return;
    if (receivedMessage) {
      SystemSound.play(SystemSoundType.alert).ignore();
    }
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

  void deleteAfter(ChatMessage message) {
    final index = messages.indexOf(message);
    if (index < 0 || index == messages.length - 1) return;
    messages.removeRange(index + 1, messages.length);
    _session.updatedAt = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    _save();
  }

  void regenerateFrom(ChatMessage message) {
    final index = messages.indexOf(message);
    if (index < 0 || isGenerating) return;
    if (index < messages.length - 1) {
      messages.removeRange(index + 1, messages.length);
    }
    if (message.isUser) {
      _startGeneration();
    } else {
      message.text = '';
      streamingMessage = message;
      _startGeneration(regenerate: true);
    }
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
      final unsummarized = _session.messages
          .skip(_session.summaryUpTo)
          .where((m) => !m.hidden && !m.isSystem && m.text.trim().isNotEmpty)
          .toList();
      if (unsummarized.isEmpty) return;
      final batch = unsummarized;
      final transcript = batch
          .map((m) => '${m.isUser ? settings.userName : character.name}: ${m.text}')
          .join('\n\n');
      final previous = _session.summary.trim();
      if (transcript.trim().isEmpty) return;
      final buffer = StringBuffer();
      final stream = LLMClient().stream(
        settings: settings,
        messages: [
          {
            'role': 'system',
            'content': settings.summaryPrompt +
                (previous.isEmpty
                    ? ''
                    : '\n\n已有摘要（可合并更新）：\n$previous'),
          },
          {'role': 'user', 'content': transcript},
        ],
      );
      await for (final chunk in stream) {
        buffer.write(chunk);
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
    _sub = null;
    // Keep the partial reply when the user leaves mid-generation.
    final message = streamingMessage;
    if (message != null) {
      final text = message.text.trim();
      if (text.isEmpty) {
        if (_regenerating && message.swipes.isNotEmpty) {
          message.text = message.currentSwipe;
        } else if (!_regenerating && !_continuing) {
          messages.remove(message);
        }
      } else {
        message.text = text;
        message.time = _time();
        if (_regenerating) {
          if (!message.swipes.contains(text)) message.swipes.insert(0, text);
          message.swipeIndex = message.swipes.indexOf(text);
        } else if (_continuing) {
          if (message.swipes.isEmpty) {
            message.swipes = [text];
          } else {
            final index = message.swipeIndex.clamp(0, message.swipes.length - 1);
            message.swipes[index] = text;
          }
        } else if (message.swipes.isEmpty ||
            message.swipes.every((s) => s.isEmpty)) {
          message.swipes = [text];
          message.swipeIndex = 0;
        }
        _session.updatedAt = DateTime.now().millisecondsSinceEpoch;
        AppStore.instance.saveSessions();
      }
    }
    streamingMessage = null;
    super.dispose();
  }
}
