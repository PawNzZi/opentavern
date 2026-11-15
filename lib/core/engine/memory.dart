/// 剧情记忆（上下文压缩）：把逐字窗口之外的旧历史折叠成摘要。
library;

import '../settings/app_settings.dart';
import 'reply.dart' show StatusLine;

class MemoryPlan {
  MemoryPlan({
    required this.start,
    required this.end,
    required this.foldable,
    required this.tail,
  });

  final int start;
  final int end;
  final int foldable;
  final int tail;
}

int _tokens(String text) => (text.length / 2).ceil();

/// 计算这次能折叠哪一段：`[start, end)`，尾部保留 [historyLimit] 条。
MemoryPlan planCompaction({
  required List<dynamic> messages,
  required int historyLimit,
  Map<String, dynamic>? memory,
}) {
  final String throughId = memory == null ? '' : '${memory['throughMessageId'] ?? ''}';
  int start = 0;
  if (throughId.isNotEmpty) {
    final int index = messages.indexWhere(
      (Object? item) => item is Map && '${item['id']}' == throughId,
    );
    if (index >= 0) start = index + 1;
  }
  final int tail = historyLimit.clamp(2, 100);
  final int end = (messages.length - tail).clamp(start, messages.length);
  return MemoryPlan(start: start, end: end, foldable: end - start, tail: tail);
}

String transcriptOf(
  List<dynamic> messages,
  int start,
  int end, {
  required String userName,
  required String characterName,
}) {
  final List<String> lines = <String>[];
  for (int i = start; i < end && i < messages.length; i++) {
    final Object? item = messages[i];
    if (item is! Map) continue;
    final String text = '${item['text'] ?? ''}'.trim();
    if (text.isEmpty) continue;
    final bool isUser = '${item['role']}' == 'user';
    lines.add('${isUser ? userName : characterName}：$text');
  }
  return lines.join('\n');
}

List<List<int>> planChunks(
  List<dynamic> messages,
  int start,
  int end, {
  int maxMessages = 24,
  int maxChars = 12000,
}) {
  final List<List<int>> chunks = <List<int>>[];
  int cursor = start;
  while (cursor < end) {
    int next = cursor;
    int chars = 0;
    while (next < end && next - cursor < maxMessages) {
      final int length = '${(messages[next] is Map) ? (messages[next] as Map)['text'] ?? '' : ''}'.length;
      if (next > cursor && chars + length > maxChars) break;
      chars += length;
      next += 1;
    }
    if (next == cursor) next = cursor + 1;
    chunks.add(<int>[cursor, next]);
    cursor = next;
  }
  return chunks;
}

String memorySystemPrompt() {
  return <String>[
    '你是角色扮演对话的「剧情记忆」整理器：把给定对话提炼成一段可长期复用的中文剧情摘要。',
    '',
    '提炼原则：',
    '- 只保留核心要素：时间、地点、人物（一律写角色名，不用「用户」「AI」「模型」）、事件、具体的言语行为与动作、关键决定，',
    '  以及这些要素造成的剧情推进。',
    '- 过滤无关内容：环境与外貌铺陈、心理描写、寒暄客套、重复表达、与主线无关的闲聊，都不要写进摘要。',
    '- 保持因果链：写清「谁因为什么做了什么 → 导致了什么 → 现在处于什么局面」。',
    '- 结尾必须写清「当前进展」：此刻的时间地点、在场人物、双方处境与未完成的事，让下一轮对话可以直接接上。',
    '',
    '写作要求：',
    '- 用第三人称、连贯的叙事散文来写，禁止分点、编号、Markdown、表格。',
    '- 不设字数指标：信息多就写长，信息少就写短；但每一句都要有信息量，能用一句说清的不写两句。',
    '- 只有当某句台词本身就构成关键事件或重要承诺时，才引用原话（最多一句，用「」括起），其余一律转述。',
    '',
    '合并规则：',
    '- 输入会给出【已有摘要】和【新增对话】：请把两者融合成一份新的完整摘要，不是在旧摘要后面追加。',
    '- 旧摘要中仍然影响剧情的事实必须保留；已经过时的细节可以合并、压缩或删除。',
    '- 新旧冲突时以新对话为准，并在文中自然交代变化。',
    '- 不要出现「摘要」「上文」「本次」这类元叙述，直接写剧情本身。',
    '',
    '只输出摘要正文，不要标题、不要解释。',
  ].join('\n');
}

String memoryUserPrompt({required String summary, required String transcript}) {
  final String previous = summary.trim();
  return <String>[
    '【已有摘要】',
    previous.isEmpty ? '（无，这是第一次压缩）' : previous,
    '',
    '【新增对话】',
    transcript.trim(),
    '',
    '请输出融合后的完整摘要：',
    '- 接着旧摘要的时间线往下写，已经交代过的事不要重复描述；',
    '- 只写核心要素与剧情发展（时间、地点、人物、事件、行为、决定），没有信息量的修饰与闲谈略去；',
    '- 收尾落在「当前进展」，写清此刻的时间地点、在场人物与双方处境，让后续对话能自然接上；',
    '- 不设字数限制：只保留有信息量的句子，不要为了凑长度而堆砌细节。',
  ].join('\n');
}

class CompactResult {
  CompactResult({
    required this.ok,
    this.reason = '',
    this.summary = '',
    this.foldedMessages = 0,
    this.throughMessageId = '',
    this.beforeTokens = 0,
    this.afterTokens = 0,
    this.error = '',
  });

  final bool ok;
  final String reason;
  final String summary;
  final int foldedMessages;
  final String throughMessageId;
  final int beforeTokens;
  final int afterTokens;
  final String error;
}

/// 执行一次压缩。[summarize] 负责真正调用模型。
Future<CompactResult> compactChat({
  required Map<String, dynamic> chat,
  required AppSettings settings,
  required Future<String> Function(String system, String user, int maxTokens) summarize,
}) async {
  final List<dynamic> messages = chat['messages'] is List ? chat['messages'] as List : <dynamic>[];
  final Map<String, dynamic>? memory =
      chat['memory'] is Map ? Map<String, dynamic>.from(chat['memory'] as Map) : null;
  final MemoryPlan plan = planCompaction(
    messages: messages,
    historyLimit: settings.historyLimit,
    memory: memory,
  );
  if (plan.foldable <= 0) {
    return CompactResult(ok: false, reason: 'nothing-to-fold');
  }
  final List<List<int>> chunks = planChunks(
    messages,
    plan.start,
    plan.end,
    maxMessages: settings.memoryChunkMessages,
    maxChars: settings.memoryChunkChars,
  );
  final int beforeTokens = (memory?['tokens'] is num ? (memory!['tokens'] as num).toInt() : 0) +
      _tokens(transcriptOf(messages, plan.start, plan.end,
          userName: settings.userName, characterName: '${chat['characterName'] ?? '角色'}'));

  String summary = '${memory?['summary'] ?? ''}';
  int used = 0;
  try {
    for (final List<int> chunk in chunks) {
      final String transcript = transcriptOf(
        messages,
        chunk[0],
        chunk[1],
        userName: settings.userName,
        characterName: '角色',
      );
      if (transcript.trim().isEmpty) continue;
      final String next = await summarize(
        memorySystemPrompt(),
        memoryUserPrompt(summary: summary, transcript: transcript),
        settings.memorySummaryMaxTokens,
      );
      if (next.trim().isEmpty) {
        return CompactResult(ok: false, reason: 'failed', error: '摘要模型返回为空');
      }
      summary = next.trim();
      used += 1;
    }
  } catch (error) {
    return CompactResult(ok: false, reason: 'failed', error: '$error');
  }
  if (used == 0) {
    return CompactResult(ok: false, reason: 'empty-transcript');
  }
  final Map? lastFolded = plan.end - 1 < messages.length ? messages[plan.end - 1] as Map? : null;
  final String throughId = '${lastFolded?['id'] ?? memory?['throughMessageId'] ?? ''}';
  final int sourceMessages =
      (memory?['sourceMessages'] is num ? (memory!['sourceMessages'] as num).toInt() : 0) + plan.foldable;

  final int now = DateTime.now().millisecondsSinceEpoch;
  chat['memory'] = <String, dynamic>{
    'summary': summary,
    'throughMessageId': throughId,
    'sourceMessages': sourceMessages,
    'tokens': _tokens(summary),
    'updatedAt': now,
  };
  return CompactResult(
    ok: true,
    summary: summary,
    foldedMessages: plan.foldable,
    throughMessageId: throughId,
    beforeTokens: beforeTokens,
    afterTokens: _tokens(summary),
  );
}

/// 把消息列表转成备份/导出用的文本。
String exportChatAsText(
  Map<String, dynamic> chat, {
  required String characterName,
  required String userName,
}) {
  final StringBuffer buffer = StringBuffer();
  final List<dynamic> memory = <dynamic>[];
  final Object? mem = chat['memory'];
  if (mem is Map && '${mem['summary'] ?? ''}'.trim().isNotEmpty) {
    buffer.writeln('【剧情记忆】');
    buffer.writeln('${mem['summary']}');
    buffer.writeln();
  }
  memory.clear();
  final List<dynamic> messages = chat['messages'] is List ? chat['messages'] as List : <dynamic>[];
  for (final Object? item in messages) {
    if (item is! Map) continue;
    final String text = '${item['text'] ?? ''}'.trim();
    if (text.isEmpty) continue;
    final bool isUser = '${item['role']}' == 'user';
    buffer.writeln('${isUser ? userName : characterName}：$text');
  }
  return buffer.toString().trim();
}

/// 状态行转 JSON（供消息持久化）。
List<Map<String, dynamic>> statusToJson(List<StatusLine> lines) =>
    lines.map((StatusLine line) => line.toJson()).toList(growable: false);
