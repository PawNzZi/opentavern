/// 提示词组装：把角色卡、世界书、记忆、历史拼成 system + user。
library;

import '../models/tavern_card.dart';
import '../settings/app_settings.dart';
import 'variables.dart';
import 'worldbook.dart';

class BuiltPrompt {
  BuiltPrompt({
    required this.system,
    required this.user,
    required this.activated,
    required this.totalTokens,
    required this.historyCount,
  });

  final String system;
  final String user;
  final List<ActivatedEntry> activated;
  final int totalTokens;
  final int historyCount;

  List<Map<String, dynamic>> get messages => <Map<String, dynamic>>[
        <String, dynamic>{
          'role': 'system',
          'content': <Map<String, String>>[<String, String>{'type': 'text', 'text': system}],
        },
        <String, dynamic>{
          'role': 'user',
          'content': <Map<String, String>>[<String, String>{'type': 'text', 'text': user}],
        },
      ];
}

/// 组装一轮提示词。
BuiltPrompt buildPrompt({
  required Map<String, dynamic> character,
  required List<TavernWorld> worlds,
  required Map<String, dynamic> chat,
  required String userText,
  required AppSettings settings,
}) {
  final String charName = '${character['name'] ?? '角色'}';
  final String userName = settings.userName;
  final List<dynamic> rawMessages = chat['messages'] is List ? chat['messages'] as List : <dynamic>[];
  final List<String> recent = <String>[
    for (final Object? item in rawMessages)
      if (item is Map) '${item['text'] ?? ''}',
  ];

  final List<TavernWorldEntry> entries = <TavernWorldEntry>[
    for (final TavernWorld world in worlds) ...world.entries,
  ];
  final List<ActivatedEntry> activated = activateEntries(
    entries,
    recentTexts: <String>[...recent, userText],
    scanDepth: settings.scanDepth,
    maxTokens: settings.worldMaxTokens,
    recursionDepth: settings.recursionDepth,
  );

  final String worldBefore = _block(activated, <int>[0]);
  final String worldAfter = _block(activated, <int>[1]);
  final String authorTop = _block(activated, <int>[2]);
  final String authorBottom = _block(activated, <int>[3]);
  final String depthBlock = _block(activated, <int>[4]);

  final Map<String, dynamic> variables = chat['variables'] is Map
      ? Map<String, dynamic>.from(chat['variables'] as Map)
      : <String, dynamic>{};

  String text(Object? value) => '${value ?? ''}'.trim();

  final String description = text(character['description']);
  final String personality = text(character['personality']);
  final String scenario = text(character['scenario']);
  final String example = text(character['example']);
  final String systemPrompt = text(character['systemPrompt']);
  final String postHistory = text(character['postHistory']);
  final String persona = settings.persona.trim();

  final String memorySummary = _memorySummary(chat);

  final Map<String, String> sections = <String, String>{
    'main': _mainSection(settings, charName, userName),
    'worldBefore': worldBefore,
    'personaDescription': persona.isEmpty ? '' : '【用户设定】\n$persona',
    'characterDescription': description.isEmpty ? '' : '【角色描述】\n$description',
    'characterPersonality': personality.isEmpty ? '' : '【性格】\n$personality',
    'scenario': scenario.isEmpty ? '' : '【场景】\n$scenario',
    'systemPrompt': systemPrompt.isEmpty ? '' : '【角色专属提示词】\n$systemPrompt',
    'worldAfter': worldAfter,
    'examplesBefore': '',
    'examples': example.isEmpty ? '' : '【示例对话】\n$example',
    'examplesAfter': '',
    'authorTop': authorTop,
    'authorBottom': authorBottom,
    'memory': memorySummary.isEmpty ? '' : '【剧情记忆】\n$memorySummary',
    'postHistory': postHistory,
  };

  final List<String> ordered = <String>[];
  for (final String id in settings.promptOrder) {
    final String value = sections[id] ?? '';
    if (value.isNotEmpty) ordered.add(value);
  }
  if (depthBlock.isNotEmpty) ordered.add(depthBlock);

  String system = ordered.join('\n\n');
  system = substituteMacros(system, charName: charName, userName: userName, variables: variables);

  // 历史：最近 N 条拍平成文本，名字前缀便于模型分辨说话人
  final int limit = settings.historyLimit;
  final List<dynamic> history = rawMessages.length <= limit
      ? rawMessages
      : rawMessages.sublist(rawMessages.length - limit);
  final List<String> lines = <String>[];
  for (final Object? item in history) {
    if (item is! Map) continue;
    final String body = '${item['text'] ?? ''}'.trim();
    if (body.isEmpty) continue;
    final bool isUser = '${item['role']}' == 'user';
    final String speaker = isUser
        ? userName
        : (settings.includeNames ? charName : '');
    lines.add(speaker.isEmpty ? body : '$speaker：$body');
  }
  lines.add('$userName：$userText');
  final String user = substituteMacros(
    lines.join('\n'),
    charName: charName,
    userName: userName,
    variables: variables,
  );

  return BuiltPrompt(
    system: system,
    user: user,
    activated: activated,
    totalTokens: estimateTokens(system) + estimateTokens(user),
    historyCount: history.length,
  );
}

String _mainSection(AppSettings settings, String charName, String userName) {
  final String custom = settings.mainPrompt.trim();
  final String template = custom.isEmpty ? AppSettings.defaultMainPrompt : custom;
  return template
      .replaceAll('{{char}}', charName)
      .replaceAll('{{user}}', userName);
}

String _memorySummary(Map<String, dynamic> chat) {
  final Object? memory = chat['memory'];
  if (memory is! Map) return '';
  return '${memory['summary'] ?? ''}'.trim();
}

String _block(List<ActivatedEntry> activated, List<int> positions) {
  final List<String> items = <String>[];
  for (final ActivatedEntry item in activated) {
    if (!positions.contains(item.entry.position)) continue;
    items.add(item.entry.content.trim());
  }
  return items.join('\n\n');
}
