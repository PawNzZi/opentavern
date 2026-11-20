import 'dart:math';

import '../data/demo.dart';
import 'models.dart';

/// Small, deterministic-by-default macro expander. Supports the most useful
/// SillyTavern macros without pulling in a full STscript engine.
class MacroEngine {
  static String expand(
    String input, {
    required DemoCharacter character,
    required AppSettings settings,
    Map<String, String>? variables,
    String? userInput,
    String? lastMessage,
    Random? random,
  }) {
    final rng = random ?? Random();
    final vars = variables ?? <String, String>{};
    var text = input;

    String pick(String args) {
      final list = args
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (list.isEmpty) return '';
      return list[rng.nextInt(list.length)];
    }

    String roll(String args) {
      final match = RegExp(r'^(\d*)d(\d+)$').firstMatch(args.trim());
      if (match == null) return '0';
      final count = int.tryParse(match.group(1) ?? '') ?? 1;
      final sides = int.tryParse(match.group(2) ?? '') ?? 6;
      var total = 0;
      for (var i = 0; i < count.clamp(1, 100); i++) {
        total += 1 + rng.nextInt(sides.clamp(1, 1000));
      }
      return '$total';
    }

    for (var pass = 0; pass < 12; pass++) {
      final before = text;
      text = text.replaceAllMapped(RegExp(r'\{\{(.*?)\}\}'), (match) {
        final raw = match.group(1)!.trim();
        if (raw.startsWith('//')) return '';
        final parts = raw.split('::');
        final name = parts.first.trim().toLowerCase();
        final args = parts.length > 1 ? parts.sublist(1) : const <String>[];
        switch (name) {
          case 'char':
            return character.name;
          case 'user':
            return settings.userName.trim().isEmpty
                ? 'User'
                : settings.userName;
          case 'persona':
            return settings.personaName.trim().isEmpty
                ? 'User'
                : settings.personaName;
          case 'description':
            return character.description;
          case 'personality':
            return character.personality;
          case 'scenario':
            return character.scenario;
          case 'mes_example':
            return character.exampleDialogue;
          case 'input':
            return userInput ?? '';
          case 'lastmessage':
          case 'last_message':
            return lastMessage ?? '';
          case 'time':
            final now = DateTime.now();
            return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
          case 'date':
            final now = DateTime.now();
            return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          case 'weekday':
            const days = ['鍛ㄤ竴', '鍛ㄤ簩', '鍛ㄤ笁', '鍛ㄥ洓', '鍛ㄤ簲', '鍛ㄥ叚', '鍛ㄦ棩'];
            return days[DateTime.now().weekday - 1];
          case 'newline':
            return '\n';
          case 'trim':
            return '';
          case 'random':
          case 'pick':
            return pick(args.join('::'));
          case 'roll':
            return roll(args.join('::'));
          case 'getvar':
            return vars[args.join('::')] ?? '';
          case 'setvar':
            if (args.length >= 2) {
              vars[args.first] = args.sublist(1).join('::');
            }
            return '';
          case 'addvar':
            if (args.length >= 2) {
              final key = args.first;
              final current = int.tryParse(vars[key] ?? '') ?? 0;
              final delta = int.tryParse(args.sublist(1).join('::')) ?? 0;
              vars[key] = '${current + delta}';
            }
            return '';
          default:
            return match.group(0)!;
        }
      });
      if (text == before) break;
    }
    return text;
  }
}

