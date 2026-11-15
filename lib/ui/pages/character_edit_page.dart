/// 角色编辑：改名字、设定、开场白等字段。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/store/tavern_store.dart';
import '../nav.dart';
import '../theme.dart';
import '../toast.dart';

class CharacterEditPage extends StatefulWidget {
  const CharacterEditPage({super.key, required this.characterId});

  final String characterId;

  @override
  State<CharacterEditPage> createState() => _CharacterEditPageState();
}

class _CharacterEditPageState extends State<CharacterEditPage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _personality = TextEditingController();
  final TextEditingController _scenario = TextEditingController();
  final TextEditingController _firstMes = TextEditingController();
  final TextEditingController _example = TextEditingController();
  final TextEditingController _systemPrompt = TextEditingController();
  final TextEditingController _postHistory = TextEditingController();
  final TextEditingController _tags = TextEditingController();
  final TextEditingController _greetings = TextEditingController();

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic>? character = TavernStore.instance.character(widget.characterId);
    if (character == null) return;
    _name.text = '${character['name'] ?? ''}';
    _description.text = '${character['description'] ?? ''}';
    _personality.text = '${character['personality'] ?? ''}';
    _scenario.text = '${character['scenario'] ?? ''}';
    _firstMes.text = '${character['firstMes'] ?? ''}';
    _example.text = '${character['example'] ?? ''}';
    _systemPrompt.text = '${character['systemPrompt'] ?? ''}';
    _postHistory.text = '${character['postHistory'] ?? ''}';
    _tags.text = (character['tags'] is List ? character['tags'] as List : <dynamic>[]).join('，');
    _greetings.text =
        (character['alternateGreetings'] is List ? character['alternateGreetings'] as List : <dynamic>[])
            .join('\n---\n');
  }

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _name,
      _description,
      _personality,
      _scenario,
      _firstMes,
      _example,
      _systemPrompt,
      _postHistory,
      _tags,
      _greetings,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final Map? character = TavernStore.instance.mutable('characters', widget.characterId);
    if (character == null) return;
    character['name'] = _name.text.trim().isEmpty ? '未命名角色' : _name.text.trim();
    character['description'] = _description.text.trim();
    character['personality'] = _personality.text.trim();
    character['scenario'] = _scenario.text.trim();
    character['firstMes'] = _firstMes.text.trim();
    character['example'] = _example.text.trim();
    character['systemPrompt'] = _systemPrompt.text.trim();
    character['postHistory'] = _postHistory.text.trim();
    character['tags'] = _tags.text
        .split(RegExp(r'[,，\n]'))
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
    character['alternateGreetings'] = _greetings.text
        .split('\n---\n')
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
    character['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    await TavernStore.instance.save();
    if (!mounted) return;
    showToast(context, '已保存');
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TavernColors.bg,
      body: Column(
        children: <Widget>[
          NavBar(
            title: '编辑角色',
            actions: <Widget>[
              TextButton(
                onPressed: () => unawaited(_save()),
                child: const Text('保存', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: <Widget>[
                _field('名字', _name, single: true),
                _field('描述', _description, minLines: 4),
                _field('性格', _personality, minLines: 2),
                _field('场景', _scenario, minLines: 2),
                _field('开场白', _firstMes, minLines: 3),
                _field('备选开场白（用 --- 分隔）', _greetings, minLines: 3),
                _field('示例对话', _example, minLines: 4),
                _field('角色专属提示词', _systemPrompt, minLines: 3),
                _field('历史后指令', _postHistory, minLines: 2),
                _field('标签（逗号分隔）', _tags, single: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, {int minLines = 1, bool single = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: TavernText.caption),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: TavernColors.surface,
              borderRadius: BorderRadius.circular(TavernRadius.field),
            ),
            child: TextField(
              controller: controller,
              minLines: single ? 1 : minLines,
              maxLines: single ? 1 : null,
              style: TavernText.body,
              decoration: const InputDecoration(border: InputBorder.none),
            ),
          ),
        ],
      ),
    );
  }
}
