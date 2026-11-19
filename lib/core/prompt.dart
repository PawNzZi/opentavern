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

  final List<Map<String, String>> messages;
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
    String macro(String input) => MacroEngine.expand(
          input,
          character: character,
          settings: settings,
          variables: session.variables,
        );

    final recentText = session.messages
        .where((m) => !m.hidden && m.text.trim().isNotEmpty)
        .toList()
        .reversed
        .take(8)
        .map((m) => m.text)
        .join('\n');
    final lore = _activateLore(character, recentText);

    final system = StringBuffer();
    final preset = AppStore.instance.activePreset;
    final main = character.systemPrompt.trim().isNotEmpty
        ? character.systemPrompt
        : (preset?.mainPrompt.trim().isNotEmpty == true
            ? preset!.mainPrompt
            : settings.mainPrompt);
    if (main.trim().isNotEmpty) {
      system.writeln(macro(main).trim());
    }
    system.writeln('\n[角色]\n名字：${character.name}');
    if (character.description.trim().isNotEmpty) {
      system.writeln('设定：${macro(character.description).trim()}');
    }
    if (character.personality.trim().isNotEmpty) {
      system.writeln('性格：${macro(character.personality).trim()}');
    }
    if (character.scenario.trim().isNotEmpty) {
      system.writeln('场景：${macro(character.scenario).trim()}');
    }
    if (lore.isNotEmpty) system.writeln('\n[世界设定]\n$lore');
    if (settings.personaDescription.trim().isNotEmpty) {
      system.writeln(
        '\n[用户]\n名字：${settings.userName}\n'
        '${macro(settings.personaDescription).trim()}',
      );
    }
    if (character.exampleDialogue.trim().isNotEmpty) {
      system.writeln(
        '\n[对话示例]\n${macro(character.exampleDialogue).trim()}',
      );
    }
    if (settings.authorNote.trim().isNotEmpty) {
      system.writeln('\n[作者笔记]\n${macro(settings.authorNote).trim()}');
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
    var history = <Map<String, String>>[];
    var used = systemTokens;
    var dropped = 0;

    for (var i = session.messages.length - 1; i >= 0; i--) {
      final m = session.messages[i];
      if (m.hidden || m.isSystem) continue;
      if (m.text.trim().isEmpty) continue;
      final content = applyRegexScripts(
        m.text,
        AppStore.instance.regexScripts,
        stage: 'prompt',
      );
      final tokens = estimateTokens(content) + 4;
      if (used + tokens > maxPrompt) {
        dropped = i + 1;
        break;
      }
      history.add({
        'role': m.isUser ? 'user' : 'assistant',
        'content': content,
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

  static String _activateLore(DemoCharacter character, String text) {
    final lower = text.toLowerCase();
    final selected = <(int, String)>[];

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
        selected.add((entry.order, entry.content.trim()));
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
            if (content.isNotEmpty) selected.add((100, content));
          }
        }
      }
    }

    selected.sort((a, b) => b.$1.compareTo(a.$1));
    return selected.map((e) => e.$2).take(6).join('\n\n');
  }
}
