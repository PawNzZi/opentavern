import '../data/demo.dart';
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
    String macro(String input) {
      return input
          .replaceAll('{{char}}', character.name)
          .replaceAll('{{user}}', settings.userName)
          .replaceAll('{{persona}}', settings.personaName)
          .replaceAll('{{description}}', character.description)
          .replaceAll('{{personality}}', character.personality)
          .replaceAll('{{scenario}}', character.scenario)
          .replaceAll('{{mes_example}}', character.exampleDialogue);
    }

    final recentText = session.messages
        .where((m) => !m.hidden && m.text.trim().isNotEmpty)
        .toList()
        .reversed
        .take(8)
        .map((m) => m.text)
        .join('\n');
    final lore = _activateLore(character, recentText);

    final system = StringBuffer();
    final main = character.systemPrompt.trim().isNotEmpty
        ? character.systemPrompt
        : settings.mainPrompt;
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
      final tokens = estimateTokens(m.text) + 4;
      if (used + tokens > maxPrompt) {
        dropped = i + 1;
        break;
      }
      history.add({
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.text,
      });
      used += tokens;
    }
    history = history.reversed.toList();

    return BuiltPrompt(
      messages: [
        {'role': 'system', 'content': system.toString().trim()},
        ...history,
      ],
      approxTokens: used,
      droppedMessages: dropped,
    );
  }

  static String _activateLore(DemoCharacter character, String text) {
    final raw = character.rawJson;
    if (raw == null) return '';
    final data = raw['data'] is Map ? raw['data'] as Map : raw;
    final book = data['character_book'];
    if (book is! Map) return '';
    final entries = book['entries'];
    if (entries is! List) return '';
    final lower = text.toLowerCase();
    final selected = <String>[];
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
      if (content.isNotEmpty) selected.add(content);
    }
    return selected.take(4).join('\n\n');
  }
}
