/// 世界书激活：关键词匹配、递归、预算控制。
library;

import '../models/tavern_card.dart';

class ActivatedEntry {
  ActivatedEntry({
    required this.entry,
    required this.reason,
    required this.tokens,
  });

  final TavernWorldEntry entry;
  final String reason;
  final int tokens;
}

int estimateTokens(String text) => (text.length / 2).ceil();

/// 在最近 [scanDepth] 条消息里找关键词。
///
/// - `constant` 条目无条件激活
/// - 关键词大小写不敏感、子串匹配
/// - 递归：被激活条目的正文再参与匹配（最多 [recursionDepth] 层）
List<ActivatedEntry> activateEntries(
  List<TavernWorldEntry> entries, {
  required List<String> recentTexts,
  int scanDepth = 12,
  int maxTokens = 6000,
  int recursionDepth = 2,
  int Function(String text)? countTokens,
}) {
  final int Function(String) counter = countTokens ?? estimateTokens;
  final List<String> haystack = recentTexts.length <= scanDepth
      ? recentTexts
      : recentTexts.sublist(recentTexts.length - scanDepth);
  final String scanText = haystack.join('\n').toLowerCase();

  final List<ActivatedEntry> activated = <ActivatedEntry>[];
  final Set<String> activatedIds = <String>{};
  int used = 0;

  bool add(TavernWorldEntry entry, String reason) {
    if (activatedIds.contains(entry.id)) return false;
    final int tokens = counter(entry.content);
    if (used + tokens > maxTokens) return false;
    activatedIds.add(entry.id);
    used += tokens;
    activated.add(ActivatedEntry(entry: entry, reason: reason, tokens: tokens));
    return true;
  }

  // 1) 常驻条目
  for (final TavernWorldEntry entry in entries) {
    if (!entry.enabled || entry.content.trim().isEmpty) continue;
    if (entry.constant) {
      add(entry, '常驻');
    }
  }

  // 2) 关键词命中
  final List<TavernWorldEntry> pending = <TavernWorldEntry>[];
  for (final TavernWorldEntry entry in entries) {
    if (!entry.enabled || entry.constant || entry.content.trim().isEmpty) continue;
    if (activatedIds.contains(entry.id)) continue;
    for (final String key in entry.keys) {
      final String needle = key.trim().toLowerCase();
      if (needle.isEmpty) continue;
      if (scanText.contains(needle)) {
        if (add(entry, '命中：$key')) {
          pending.add(entry);
        }
        break;
      }
    }
  }

  // 3) 递归
  int depth = 1;
  while (depth < recursionDepth && pending.isNotEmpty) {
    final String recursiveText = pending
        .map((TavernWorldEntry entry) => entry.content)
        .join('\n')
        .toLowerCase();
    pending.clear();
    for (final TavernWorldEntry entry in entries) {
      if (!entry.enabled || entry.constant || entry.content.trim().isEmpty) continue;
      if (activatedIds.contains(entry.id)) continue;
      for (final String key in entry.keys) {
        final String needle = key.trim().toLowerCase();
        if (needle.isEmpty) continue;
        if (recursiveText.contains(needle)) {
          if (add(entry, '递归：$key')) pending.add(entry);
          break;
        }
      }
    }
    depth += 1;
  }

  return activated;
}
