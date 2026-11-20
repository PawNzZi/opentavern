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
  });

  final List<Map<String, dynamic>> messages;
  final int approxTokens;
  final int droppedMessages;
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
    final loreEntries = _activatedLore(character, recentText);
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
    if (character.postHistoryInstructions.trim().isNotEmpty) {
      sections['jailbreak'] =
          '\n[越狱 / PHI]\n${macro(character.postHistoryInstructions).trim()}';
    }
    final system = StringBuffer();
    for (final key in settings.promptOrder) {
      final section = sections.remove(key);
      if (section != null && section.trim().isNotEmpty) {
        system.writeln(section);
      }
    }
    for (final section in sections.values) {
      if (section.trim().isNotEmpty) system.writeln(section);
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
    final systemTokens = estimateTokens(system.toString());
    var history = <Map<String, dynamic>>[];
    var used = systemTokens;
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
      ],
      approxTokens: used,
      droppedMessages: dropped,
    );
  }

  static List<LoreEntry> _activatedLore(DemoCharacter character, String text) {
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
    return selected.take(6).toList();
  }
}

