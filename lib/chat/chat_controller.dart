import 'dart:async';

import 'package:flutter/foundation.dart';

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.text,
    this.isUser = false,
    this.time,
    this.reasoning,
    List<String>? swipes,
    this.swipeIndex = 0,
    this.hidden = false,
    this.bookmarked = false,
  }) : swipes = swipes ?? [text];

  final String id;
  String text;
  final bool isUser;
  String? time;
  String? reasoning;
  List<String> swipes;
  int swipeIndex;
  bool hidden;
  bool bookmarked;

  bool get hasSwipes => swipes.length > 1;
}

/// Demo chat state machine. It simulates a streaming backend so the prototype
/// can be felt end-to-end: send, stream, stop, regenerate, continue, swipe.
class ChatController extends ChangeNotifier {
  ChatController() {
    _seed();
  }

  final List<ChatMessage> messages = [];
  bool isGenerating = false;
  ChatMessage? streamingMessage;

  Timer? _timer;
  bool _disposed = false;
  String _target = '';
  int _cursor = 0;
  int _variant = 0;

  static const _replyVariants = <String>[
    '她没有立刻回答。窗外的雨敲在玻璃上，像有人在极远的地方敲门。\n\n“坏消息也分种类。”她终于说，“有些是冲你来的，有些是冲我来的。”',
    '“你带了伞吗？”\n\n她问得很轻，像是已经知道答案。\n\n“没有也没关系。塔顶的雨，通常只下给留下来的人看。”',
    '她笑了一下，那笑意没有到眼睛里。\n\n“今晚的客人不只你一个。楼下的门，已经响了三次。”',
    '她把星图转了个方向，指尖停在一颗很暗的星上。\n\n“你看，它一直在那里。只是今晚，它第一次被看见。”',
  ];

  static const _continuations = <String>[
    '\n\n她把茶杯往你面前推了推，示意你坐下。',
    '\n\n窗外的雨声忽然停了一瞬。',
    '\n\n“别急着回答。”她说，“先听听雨。”',
  ];

  String _time() => '21:41';

  void _seed() {
    messages.addAll([
      ChatMessage(
        id: 'm1',
        text: '外面的雨好像更大了。',
        isUser: true,
        time: '21:38',
      ),
      ChatMessage(
        id: 'm2',
        text:
            '她把最后一枚星图钉按进软木墙，转身时耳坠轻轻一晃。\n\n是啊。王都的雨，总在预言之后来。\n\n你来得正好——我刚算到，今晚会有一位客人，带着坏消息。',
        time: '21:39',
        reasoning: '先建立场景与神秘感；用动作替代直接陈述；在结尾抛出一个钩子。',
        swipes: [
          '她把最后一枚星图钉按进软木墙，转身时耳坠轻轻一晃。\n\n是啊。王都的雨，总在预言之后来。\n\n你来得正好——我刚算到，今晚会有一位客人，带着坏消息。',
          '她没回头，只是把窗推开了一条缝。\n\n“雨是预言的余音。”她说，“你听，它今晚的节奏不太对。”',
          '“你迟到了。”\n\n她把一杯冷掉的茶推到你面前，像是早就准备好这句开场。',
          '塔顶的风把星图吹得作响。\n\n她按住最上面那张纸，抬眼看你：“我等你很久了。”',
        ],
        swipeIndex: 0,
      ),
      ChatMessage(
        id: 'm3',
        text: '那你还让我进来？',
        isUser: true,
        time: '21:39',
      ),
      ChatMessage(
        id: 'm4',
        text:
            '“因为坏消息也分种类。”\n\n她推来一杯还冒着热气的红茶，杯沿有一道细细的金边。\n\n“有些坏消息，只配在雨天说。”',
        time: '21:40',
        swipes: [
          '“因为坏消息也分种类。”\n\n她推来一杯还冒着热气的红茶，杯沿有一道细细的金边。\n\n“有些坏消息，只配在雨天说。”',
          '“因为我想看看，你会先问哪一件事。”\n\n她靠在窗边，雨光落在她的侧脸上。',
        ],
      ),
    ]);
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
    notifyListeners();
    Future<void>.delayed(const Duration(milliseconds: 420), () {
      if (_disposed) return;
      if (messages.isNotEmpty && messages.last.isUser) {
        _startReply();
      }
    });
  }

  void _startReply() {
    final message = ChatMessage(
      id: 'm${DateTime.now().microsecondsSinceEpoch}',
      text: '',
      time: _time(),
    );
    messages.add(message);
    streamingMessage = message;
    isGenerating = true;
    _target = _replyVariants[_variant++ % _replyVariants.length];
    _cursor = 0;
    notifyListeners();
    _runStream();
  }

  void _runStream() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 28), (timer) {
      final message = streamingMessage;
      if (message == null) {
        timer.cancel();
        return;
      }
      if (_cursor >= _target.length) {
        timer.cancel();
        _finish();
        return;
      }
      final step = 1 + (_cursor % 3);
      final next = (_cursor + step).clamp(0, _target.length);
      message.text = _target.substring(0, next);
      _cursor = next;
      notifyListeners();
    });
  }

  void _finish() {
    final message = streamingMessage;
    if (message != null) {
      message.text = message.text.trim().isEmpty ? '……' : message.text;
      if (!message.swipes.contains(message.text)) {
        message.swipes = [message.text, ...message.swipes];
        message.swipeIndex = 0;
      }
      message.time = _time();
    }
    streamingMessage = null;
    isGenerating = false;
    notifyListeners();
  }

  void stop() {
    _timer?.cancel();
    _finish();
  }

  void regenerate() {
    if (isGenerating) return;
    final last = _lastAssistant();
    if (last == null) return;
    last.text = '';
    streamingMessage = last;
    isGenerating = true;
    _target = _replyVariants[_variant++ % _replyVariants.length];
    _cursor = 0;
    notifyListeners();
    _runStream();
  }

  void continueLast() {
    if (isGenerating) return;
    final last = _lastAssistant();
    if (last == null) return;
    final base = last.text;
    streamingMessage = last;
    isGenerating = true;
    _target = '$base${_continuations[_variant++ % _continuations.length]}';
    _cursor = base.length;
    notifyListeners();
    _runStream();
  }

  void impersonate() {
    if (isGenerating) return;
    messages.add(
      ChatMessage(
        id: 'm${DateTime.now().microsecondsSinceEpoch}',
        text: '我先把伞收起来。你继续说。',
        isUser: true,
        time: _time(),
      ),
    );
    notifyListeners();
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
  }

  void edit(ChatMessage message, String text) {
    message.text = text.trim();
    if (message.swipes.isEmpty) {
      message.swipes = [message.text];
    } else {
      message.swipes[message.swipeIndex] = message.text;
    }
    notifyListeners();
  }

  void delete(ChatMessage message) {
    messages.remove(message);
    notifyListeners();
  }

  void toggleHidden(ChatMessage message) {
    message.hidden = !message.hidden;
    notifyListeners();
  }

  void toggleBookmark(ChatMessage message) {
    message.bookmarked = !message.bookmarked;
    notifyListeners();
  }

  ChatMessage? _lastAssistant() {
    for (var i = messages.length - 1; i >= 0; i--) {
      if (!messages[i].isUser) return messages[i];
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
