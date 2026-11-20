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
    final promptBudget = settings.maxContext -
        settings.api.maxTokens -
        settings.tokenPadding;
    final loreBudget = (promptBudget * .35).round().clamp(256, 8000).toInt();
    final loreEntries = _activatedLore(
      character,
      recentText,
      maxTokens: loreBudget,
    );
    final loreBefore = loreEntries
        .where((e) => e.position != 'after')
        .map((e) => e.content.trim())
        .where((e) => e.isNotEmpty)
        .join('\n\n');
    final loreAfter = loreEntries
        .where((e) => e.position == 'after')
        .map((e) => e.content.trim())
        .where((e) => e.isNotEmpty)
        .join('\n\n');

    final sections = <String, String>{};
    final preset = AppStore.instance.activePreset;
    final main = preset?.mainPrompt.trim().isNotEmpty == true
        ? preset!.mainPrompt
        : settings.mainPrompt;
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
    if (session.summary.trim().isNotEmpty) {
      sections['summary'] = '\n[前情提要]\n${session.summary.trim()}';
    }
    if (settings.authorNote.trim().isNotEmpty) {
      sections['authorsNote'] =
          '\n[作者笔记]\n${macro(settings.authorNote).trim()}';
    }
    // PHI（角色的 post_history_instructions）不参与 system 段落排序：
    // 它固定作为历史消息之后的最后一条 system 消息发送，贴近 SillyTavern。
    final postHistory = character.postHistoryInstructions.trim().isEmpty
        ? ''
        : '\n[越狱 / PHI]\n${macro(character.postHistoryInstructions).trim()}';
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

    final maxPrompt =
        settings.maxContext - settings.api.maxTokens - settings.tokenPadding;
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
      var content = applyRegexScripts(
        m.text,
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

    return BuiltPrompt(
      messages: [
        {'role': 'system', 'content': system.toString().trim()},
        ...extra,
        ...history,
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

  static List<LoreEntry> _activatedLore(
    DemoCharacter character,
    String text, {
    int maxTokens = 2400,
  }) {
    final lower = text.toLowerCase();
    final selected = <LoreEntry>[];

    void scanEntries(List<LoreEntry> entries) {
      for (final entry in entries) {
        if (!entry.enabled || entry.content.trim().isEmpty) continue;
        final primary = entry.constant ||
            entry.keys.any(
              (k) => k.trim().isNotEmpty && lower.contains(k.toLowerCase()),
            );
        if (!primary) continue;
        if (entry.selective && entry.secondaryKeys.isNotEmpty) {
          final secondary = entry.secondaryKeys.any(
            (k) => k.trim().isNotEmpty && lower.contains(k.toLowerCase()),
          );
          if (!secondary) continue;
        }
        selected.add(entry);
      }
    }

    for (final book in AppStore.instance.lorebooks) {
      if (!book.enabled) continue;
      if (!book.isGlobal && book.linked != character.name) continue;
      scanEntries(book.entries);
    }

    // Fallback for cards that have not been imported into the lorebook store.
    final raw = character.rawJson;
    if (selected.isEmpty && raw != null) {
      final data = raw['data'] is Map ? raw['data'] as Map : raw;
      final book = data['character_book'];
      if (book is Map) {
        final entries = book['entries'];
        if (entries is List) {
          for (final entry in entries.whereType<Map>()) {
            if (entry['enabled'] == false) continue;
            final keys = entry['keys'] is List
                ? (entry['keys'] as List).map((e) => e.toString()).toList()
                : <String>[];
            if (keys.isEmpty) continue;
            final matched = keys.any(
              (k) => k.trim().isNotEmpty && lower.contains(k.toLowerCase()),
            );
            if (!matched) continue;
            final content = (entry['content'] ?? '').toString().trim();
            if (content.isNotEmpty) {
              selected.add(
                LoreEntry(
                  id: 'embedded-${selected.length}',
                  name: entry['comment']?.toString() ?? '',
                  keys: keys,
                  content: content,
                  constant: entry['constant'] == true,
                  position: entry['position'] == 'after_char' ? 'after' : 'before',
                ),
              );
            }
          }
        }
      }
    }

    selected.sort((a, b) => b.order.compareTo(a.order));
    final result = <LoreEntry>[];
    var used = 0;
    for (final entry in selected) {
      final cost = estimateTokens(entry.content) + 2;
      if (result.isNotEmpty && used + cost > maxTokens) break;
      result.add(entry);
      used += cost;
      if (result.length >= 20) break;
    }
    return result;
  }
}

