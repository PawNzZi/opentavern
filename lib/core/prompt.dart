import 'dart:math';

import '../data/demo.dart';
import 'regex.dart';
import 'store.dart';
import 'macros.dart';
import 'models.dart';

class BuiltPrompt {
  BuiltPrompt({
    required this.messages,
    required this.approxTokens,
    required this.droppedMessages,
    this.sections = const {},
  });

  final List<Map<String, dynamic>> messages;
  final int approxTokens;
  final int droppedMessages;

  /// 实际拼接进 prompt 的系统段落，按发送顺序排列。
  ///
  /// `jailbreak`（角色卡的 post_history_instructions / PHI）固定排在最后：
  /// 它作为历史消息之后的最后一条 system 消息发送。
  final Map<String, String> sections;
}

int estimateTokens(String text) {
  var cjk = 0;
  var other = 0;
  for (final rune in text.runes) {
    if ((rune >= 0x2E80 && rune <= 0x9FFF) ||
        (rune >= 0xF900 && rune <= 0xFAFF) ||
        (rune >= 0x3040 && rune <= 0x30FF)) {
      cjk++;
    } else {
      other++;
    }
  }
  return cjk + (other / 4).ceil();
}

class PromptBuilder {
  static BuiltPrompt build({
    required DemoCharacter character,
    required ChatSession session,
    required AppSettings settings,
  }) {
    String lastUser = '';
    String lastAny = '';
    for (final m in session.messages.reversed) {
      if (lastAny.isEmpty && m.text.trim().isNotEmpty) lastAny = m.text;
      if (lastUser.isEmpty && m.isUser && m.text.trim().isNotEmpty) {
        lastUser = m.text;
      }
      if (lastAny.isNotEmpty && lastUser.isNotEmpty) break;
    }
    String macro(String input) => MacroEngine.expand(
          input,
          character: character,
          settings: settings,
          variables: session.variables,
          userInput: lastUser,
          lastMessage: lastAny,
        );

    final recentText = session.messages
        .where((m) => !m.hidden && m.text.trim().isNotEmpty)
        .toList()
        .reversed
        .take(8)
        .map((m) => m.text)
        .join('\n');
    final activatedLore = _activatedLore(character, recentText);
    final preset = AppStore.instance.presetForCharacter(character);
    final main = preset?.mainPrompt.trim().isNotEmpty == true
        ? preset!.mainPrompt
        : settings.mainPrompt;
    final postHistory = character.postHistoryInstructions.trim().isEmpty
        ? ''
        : '\n[越狱 / PHI]\n${macro(character.postHistoryInstructions).trim()}';
    final rawMaxPrompt =
        settings.maxContext - settings.api.maxTokens - settings.tokenPadding;
    final maxPrompt = rawMaxPrompt < 256 ? 256 : rawMaxPrompt;
    final fixedParts = <String>[
      main,
      character.systemPrompt,
      character.description,
      character.personality,
      character.scenario,
      character.exampleDialogue,
      settings.personaDescription,
      settings.summaryPosition == 'in_prompt' ? session.summary : '',
      session.authorNoteOverride ? session.authorNote : settings.authorNote,
      postHistory,
    ];
    if (preset != null) {
      for (final entry in preset.entries.where((e) => e.enabled)) {
        fixedParts.add(macro(entry.content));
      }
    }
    final fixedTokens =
        estimateTokens(fixedParts.join('\n')) + fixedParts.length * 8;
    final historyReserve =
        (maxPrompt * .25).round().clamp(512, 4096).toInt();
    final availableForLore =
        (maxPrompt - fixedTokens - historyReserve).clamp(0, maxPrompt).toInt();
    final loreBudget = settings.loreMaxTokens > 0
        ? settings.loreMaxTokens.clamp(0, availableForLore).toInt()
        : availableForLore;
    final loreEntries = _applyLoreBudget(activatedLore, loreBudget);
    final loreAtDepth =
        loreEntries.where((e) => e.position == 'at_depth').toList();
    final loreBefore = loreEntries
        .where((e) => e.position != 'after' && e.position != 'at_depth')
        .map((e) => e.content.trim())
        .where((e) => e.isNotEmpty)
        .join('\n\n');
    final loreAfter = loreEntries
        .where((e) => e.position == 'after')
        .map((e) => e.content.trim())
        .where((e) => e.isNotEmpty)
        .join('\n\n');

    final sections = <String, String>{};
    if (main.trim().isNotEmpty) {
      sections['main'] = macro(main).trim();
    }
    if (character.systemPrompt.trim().isNotEmpty) {
      sections['charSystemPrompt'] =
          '\n[角色专属提示词]\n${macro(character.systemPrompt).trim()}';
    }
    if (loreBefore.isNotEmpty) {
      sections['worldInfoBefore'] = '\n[世界设定 · 角色前]\n$loreBefore';
    }
    if (character.description.trim().isNotEmpty) {
      sections['charDescription'] =
          '\n[角色描述]\n${macro(character.description).trim()}';
    }
    if (character.personality.trim().isNotEmpty) {
      sections['charPersonality'] =
          '\n[性格]\n${macro(character.personality).trim()}';
    }
    if (character.scenario.trim().isNotEmpty) {
      sections['scenario'] = '\n[场景]\n${macro(character.scenario).trim()}';
    }
    if (loreAfter.isNotEmpty) {
      sections['worldInfoAfter'] = '\n[世界设定 · 角色后]\n$loreAfter';
    }
    if (settings.personaDescription.trim().isNotEmpty) {
      sections['personaDescription'] =
          '\n[用户设定]\n名字：${settings.userName}\n'
          '${macro(settings.personaDescription).trim()}';
    }
    if (character.exampleDialogue.trim().isNotEmpty) {
      sections['dialogueExamples'] =
          '\n[对话示例]\n${macro(character.exampleDialogue).trim()}';
    }
    final summaryText = session.summary.trim();
    if (summaryText.isNotEmpty && settings.summaryPosition == 'in_prompt') {
      sections['summary'] = '\n[前情提要]\n$summaryText';
    }
    final effectiveAuthorNote = session.authorNoteOverride
        ? session.authorNote
        : settings.authorNote;
    if (effectiveAuthorNote.trim().isNotEmpty) {
      sections['authorsNote'] =
          '\n[作者笔记]\n${macro(effectiveAuthorNote).trim()}';
    }
    final system = StringBuffer();
    final usedSections = <String, String>{};
    for (final key in settings.promptOrder) {
      final section = sections.remove(key);
      if (section != null && section.trim().isNotEmpty) {
        system.writeln(section);
        usedSections[key] = section.trim();
      }
    }
    for (final entry in sections.entries) {
      if (entry.value.trim().isNotEmpty) {
        system.writeln(entry.value);
        usedSections[entry.key] = entry.value.trim();
      }
    }

    final extra = <Map<String, String>>[];
    if (preset != null) {
      final enabled = preset.entries.where((e) => e.enabled).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      for (final entry in enabled) {
        final content = macro(entry.content).trim();
        if (content.isEmpty) continue;
        if (entry.role == 'system') {
          system.writeln('\n[${entry.name}]\n$content');
        } else {
          extra.add({
            'role': entry.role == 'assistant' ? 'assistant' : 'user',
            'content': content,
          });
        }
      }
    }

    var used = estimateTokens(system.toString());
    // PHI 在历史之后发送，但同样占用上下文预算。
    if (postHistory.trim().isNotEmpty) used += estimateTokens(postHistory);
    // 预设里的 user/assistant 条目插在历史之前，也要计入。
    for (final entry in extra) {
      used += estimateTokens(entry['content'] ?? '') + 4;
    }
    var history = <Map<String, dynamic>>[];
    var dropped = 0;
    var imageCount = 0;

    for (var i = session.messages.length - 1; i >= 0; i--) {
      final m = session.messages[i];
      if (m.hidden || m.isSystem) continue;
      if (m.text.trim().isEmpty && m.attachments.isEmpty) continue;
      var content = m.isUser
          ? _formatUserRoleplay(m.text)
          : m.text;
      content = applyRegexScripts(
        content,
        AppStore.instance.regexScripts,
        stage: 'prompt',
        characterName: character.name,
      );
      for (final att in m.attachments.where((a) => !a.isImage)) {
        if (att.text.trim().isEmpty) continue;
        content += '\n\n[附件 ${att.name}]\n${att.text.trim()}';
      }
      final includedImages = <ChatAttachment>[];
      for (final att in m.attachments.where((a) => a.isImage)) {
        if (imageCount >= 2) break;
        includedImages.add(att);
        imageCount++;
      }
      final tokens =
          estimateTokens(content) + 4 + includedImages.length * 850;
      if (used + tokens > maxPrompt) {
        dropped = i + 1;
        break;
      }
      history.add({
        'role': m.isUser ? 'user' : 'assistant',
        'content': includedImages.isEmpty
            ? content
            : <Map<String, dynamic>>[
                {'type': 'text', 'text': content},
                for (final att in includedImages)
                  {
                    'type': 'image',
                    'mime': att.mime,
                    'base64': att.base64,
                  },
              ],
      });
      used += tokens;
    }
    history = history.reversed.toList();
    for (final entry in loreAtDepth) {
      final role = entry.role == 'user'
          ? 'user'
          : entry.role == 'assistant'
              ? 'assistant'
              : 'system';
      final index =
          (history.length - entry.depth).clamp(0, history.length);
      history.insert(index, {
        'role': role,
        'content': entry.content.trim(),
      });
      used += estimateTokens(entry.content) + 4;
    }
    final summaryMessages = <Map<String, dynamic>>[];
    if (summaryText.isNotEmpty && settings.summaryPosition != 'in_prompt') {
      final role = settings.summaryRole == 'user'
          ? 'user'
          : settings.summaryRole == 'assistant'
              ? 'assistant'
              : 'system';
      final summaryMessage = {
        'role': role,
        'content': '[前情提要]\n$summaryText',
      };
      if (settings.summaryPosition == 'at_depth') {
        final depth = settings.summaryDepth.clamp(0, history.length);
        final index = (history.length - depth).clamp(0, history.length);
        history.insert(index, summaryMessage);
      } else {
        summaryMessages.add(summaryMessage);
      }
      used += estimateTokens(summaryText) + 4;
    }

    return BuiltPrompt(
      messages: [
        {'role': 'system', 'content': system.toString().trim()},
        ...extra,
        ...history,
        ...summaryMessages,
        // 与 SillyTavern 的 post-history instructions 一致：PHI 是历史之后
        // 的最后一条 system 消息，而不是混在开头那条 system 里。
        if (postHistory.trim().isNotEmpty)
          {'role': 'system', 'content': postHistory.trim()},
      ],
      approxTokens: used,
      droppedMessages: dropped,
      sections: {
        ...usedSections,
        if (postHistory.trim().isNotEmpty) 'jailbreak': postHistory.trim(),
      },
    );
  }

  /// Converts roleplay shorthand in user messages:
  /// “...” becomes explicit user speech and （...） an environment/action note.
  static String _formatUserRoleplay(String text) {
    var result = text;
    result = result.replaceAllMapped(
      RegExp(r'“([^”]*)”'),
      (match) => '[用户发言] ${match.group(1)!.trim()}',
    );
    result = result.replaceAllMapped(
      RegExp(r'（([^）]*)）'),
      (match) => '[用户环境/动作] ${match.group(1)!.trim()}',
    );
    return result;
  }

  static List<LoreEntry> _activatedLore(
    DemoCharacter character,
    String text,
  ) {
    final selected = <LoreEntry>[];
    final selectedIds = <String>{};

    bool containsKey(String haystack, LoreEntry entry, String key) {
      final raw = key.trim();
      if (raw.isEmpty) return false;
      final ignoreCase = !entry.caseSensitive;
      final source = ignoreCase ? haystack.toLowerCase() : haystack;
      if (raw.length >= 2 && raw.startsWith('/') && raw.endsWith('/')) {
        try {
          final pattern = RegExp(
            raw.substring(1, raw.length - 1),
            caseSensitive: !ignoreCase,
          );
          return pattern.hasMatch(source);
        } catch (_) {
          return false;
        }
      }
      final needle = ignoreCase ? raw.toLowerCase() : raw;
      if (!entry.matchWholeWords) return source.contains(needle);
      final escaped = RegExp.escape(needle);
      final pattern = RegExp(
        '(?<![A-Za-z0-9_])$escaped(?![A-Za-z0-9_])',
        caseSensitive: !ignoreCase,
      );
      return pattern.hasMatch(source);
    }

    bool primaryMatch(LoreEntry entry, String haystack) {
      if (entry.constant) return true;
      return entry.keys.any((key) => containsKey(haystack, entry, key));
    }

    bool secondaryMatch(LoreEntry entry, String haystack) {
      if (!entry.selective || entry.secondaryKeys.isEmpty) return true;
      final hits = entry.secondaryKeys
          .where((key) => containsKey(haystack, entry, key))
          .length;
      switch (entry.selectiveLogic) {
        case 'AND_ALL':
          return hits == entry.secondaryKeys.length;
        case 'NOT_ANY':
          return hits == 0;
        case 'NOT_ALL':
          return hits != entry.secondaryKeys.length;
        case 'AND_ANY':
        default:
          return hits > 0;
      }
    }

    bool probabilityPass(LoreEntry entry) {
      if (entry.probability >= 100) return true;
      if (entry.probability <= 0) return false;
      final seed = entry.id.hashCode ^ text.hashCode;
      return Random(seed).nextInt(100) < entry.probability;
    }

    void scanBooks(String haystack, {required bool recursionPass}) {
      for (final book in AppStore.instance.lorebooks) {
        if (!book.enabled) continue;
        final boundByCard = character.lorebook.isNotEmpty &&
            (character.lorebook == book.name || character.lorebook == book.id);
        if (!book.isGlobal && book.linked != character.name && !boundByCard) {
          continue;
        }
        for (final entry in book.entries) {
          if (!entry.enabled || entry.content.trim().isEmpty) continue;
          if (selectedIds.contains(entry.id)) continue;
          if (recursionPass && entry.preventRecursion) continue;
          if (!primaryMatch(entry, haystack)) continue;
          if (!secondaryMatch(entry, haystack)) continue;
          if (!probabilityPass(entry)) continue;
          selected.add(entry);
          selectedIds.add(entry.id);
        }
      }
    }

    scanBooks(text, recursionPass: false);

    // Card fallback when the embedded book was never materialised.
    final raw = character.rawJson;
    if (selected.isEmpty && raw != null) {
      final data = raw['data'] is Map ? raw['data'] as Map : raw;
      final book = data['character_book'];
      if (book is Map) {
        final entries = book['entries'];
        if (entries is List) {
          for (final item in entries.whereType<Map>()) {
            if (item['enabled'] == false) continue;
            final keys = item['keys'] is List
                ? (item['keys'] as List).map((e) => e.toString()).toList()
                : <String>[];
            if (keys.isEmpty) continue;
            final matched = keys.any(
              (k) => k.trim().isNotEmpty && text.toLowerCase().contains(k.toLowerCase()),
            );
            if (!matched) continue;
            final content = (item['content'] ?? '').toString().trim();
            if (content.isEmpty) continue;
            final entry = LoreEntry(
              id: 'embedded-${selected.length}',
              name: item['comment']?.toString() ?? '',
              keys: keys,
              content: content,
              constant: item['constant'] == true,
              position: item['position'] == 'after_char' ? 'after' : 'before',
            );
            selected.add(entry);
            selectedIds.add(entry.id);
          }
        }
      }
    }

    // Recursive scan: activated content can trigger further entries.
    for (var pass = 0; pass < 5; pass++) {
      final recursionText = selected
          .where((e) => !e.excludeRecursion)
          .map((e) => e.content)
          .join('\n');
      if (recursionText.trim().isEmpty) break;
      final before = selected.length;
      scanBooks(recursionText, recursionPass: true);
      if (selected.length == before) break;
    }

    // Grouped entries: keep the highest-weight entry from each group.
    final grouped = <String, LoreEntry>{};
    final result = <LoreEntry>[];
    for (final entry in selected) {
      if (entry.group.trim().isEmpty) {
        result.add(entry);
      } else {
        final current = grouped[entry.group];
        if (current == null || entry.groupWeight > current.groupWeight) {
          grouped[entry.group] = entry;
        }
      }
    }
    result.addAll(grouped.values);
    result.sort((a, b) => b.order.compareTo(a.order));
    return result;
  }

  static List<LoreEntry> _applyLoreBudget(
    List<LoreEntry> entries,
    int maxTokens,
  ) {
    if (maxTokens <= 0) return const <LoreEntry>[];
    final sorted = [...entries]..sort((a, b) => b.order.compareTo(a.order));
    final result = <LoreEntry>[];
    var used = 0;
    for (final entry in sorted) {
      final cost = estimateTokens(entry.content) + 2;
      if (used + cost > maxTokens) continue;
      result.add(entry);
      used += cost;
    }
    return result;
  }
}

