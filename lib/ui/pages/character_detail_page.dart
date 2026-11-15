/// 角色详情：查看设定、进入对话、导出角色卡。
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/card/card_io.dart';
import '../../core/models/tavern_card.dart';
import '../../core/store/tavern_store.dart';
import '../nav.dart';
import '../theme.dart';
import '../toast.dart';
import 'character_edit_page.dart';
import 'chat_page.dart';
import 'world_page.dart';

class CharacterDetailPage extends StatefulWidget {
  const CharacterDetailPage({super.key, required this.characterId});

  final String characterId;

  @override
  State<CharacterDetailPage> createState() => _CharacterDetailPageState();
}

class _CharacterDetailPageState extends State<CharacterDetailPage> {
  Map<String, dynamic>? _character;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => _character = TavernStore.instance.character(widget.characterId));
  }

  Future<void> _startChat() async {
    final Map<String, dynamic>? character = _character;
    if (character == null) return;
    final List<dynamic> greetings = character['alternateGreetings'] is List
        ? character['alternateGreetings'] as List
        : <dynamic>[];
    final String first = greetings.isEmpty ? '${character['firstMes'] ?? ''}' : '${greetings.first}';
    final Map<String, dynamic> chat = await TavernStore.instance.addChat(
      widget.characterId,
      firstMes: first,
      title: '${character['name'] ?? ''}',
    );
    if (!mounted) return;
    await pushPage<void>(context, ChatPage(chatId: '${chat['id']}'));
    _load();
  }

  Future<void> _edit() async {
    final Map<String, dynamic>? character = _character;
    if (character == null) return;
    await pushPage<void>(context, CharacterEditPage(characterId: widget.characterId));
    _load();
  }

  TavernCard _toCard(Map<String, dynamic> character) {
    final List<dynamic> worldIds =
        character['worldIds'] is List ? character['worldIds'] as List : <dynamic>[];
    TavernWorld? book;
    if (worldIds.isNotEmpty) {
      book = TavernWorld.fromJson(TavernStore.instance.world('${worldIds.first}') ?? const <String, dynamic>{});
    }
    return TavernCard(
      name: '${character['name'] ?? ''}',
      description: '${character['description'] ?? ''}',
      personality: '${character['personality'] ?? ''}',
      scenario: '${character['scenario'] ?? ''}',
      firstMes: '${character['firstMes'] ?? ''}',
      example: '${character['example'] ?? ''}',
      creatorNotes: '${character['creatorNotes'] ?? ''}',
      systemPrompt: '${character['systemPrompt'] ?? ''}',
      postHistory: '${character['postHistory'] ?? ''}',
      alternateGreetings: <String>[
        for (final Object? item in (character['alternateGreetings'] is List
            ? character['alternateGreetings'] as List
            : <dynamic>[]))
          '$item',
      ],
      tags: <String>[
        for (final Object? item in (character['tags'] is List ? character['tags'] as List : <dynamic>[]))
          '$item',
      ],
      creator: '${character['creator'] ?? ''}',
      characterVersion: '${character['characterVersion'] ?? ''}',
      extensions: character['extensions'] is Map
          ? Map<String, dynamic>.from(character['extensions'] as Map)
          : <String, dynamic>{},
      voice: '${character['voice'] ?? ''}',
      spec: '${character['spec'] ?? ''}',
      specVersion: '${character['specVersion'] ?? ''}',
      book: book,
    );
  }

  Future<void> _exportJson() async {
    final Map<String, dynamic>? character = _character;
    if (character == null) return;
    try {
      final String name = '${character['name'] ?? 'character'}';
      final bool saved = await saveBytes(
        fileName: '$name.json',
        bytes: Uint8List.fromList(CardIo.exportJson(_toCard(character)).codeUnits),
      );
      if (!mounted) return;
      showToast(context, saved ? 'JSON 已导出' : '已取消');
    } catch (error) {
      if (mounted) showToast(context, '导出失败：$error');
    }
  }

  Future<void> _exportPng() async {
    final Map<String, dynamic>? character = _character;
    if (character == null) return;
    try {
      final String avatarPath = '${character['avatar'] ?? ''}';
      Uint8List? image;
      if (avatarPath.isNotEmpty && File(avatarPath).existsSync()) {
        image = await File(avatarPath).readAsBytes();
      }
      final Uint8List png = CardIo.exportPng(_toCard(character), image: image);
      final String name = '${character['name'] ?? 'character'}';
      final bool saved = await saveBytes(fileName: '$name.png', bytes: png);
      if (!mounted) return;
      showToast(context, saved ? 'PNG 角色卡已导出' : '已取消');
    } catch (error) {
      if (mounted) showToast(context, '导出失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? character = _character;
    if (character == null) {
      return const Scaffold(
        backgroundColor: TavernColors.bg,
        body: Center(child: Text('角色不存在')),
      );
    }
    final List<dynamic> tags =
        character['tags'] is List ? character['tags'] as List : <dynamic>[];
    final List<dynamic> worldIds =
        character['worldIds'] is List ? character['worldIds'] as List : <dynamic>[];
    final String worldNames = worldIds
        .map((Object? id) => '${TavernStore.instance.world('$id')?['name'] ?? ''}')
        .where((String name) => name.isNotEmpty)
        .join('、');

    return Scaffold(
      backgroundColor: TavernColors.bg,
      body: Column(
        children: <Widget>[
          NavBar(
            title: '${character['name'] ?? ''}',
            actions: <Widget>[
              TextButton(
                onPressed: () => unawaited(_edit()),
                child: const Text('编辑', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _avatar(character),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('${character['name'] ?? ''}', style: TavernText.largeTitle),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: <Widget>[
                              for (final Object? tag in tags.take(6))
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: TavernColors.accent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(TavernRadius.pill),
                                  ),
                                  child: Text('$tag', style: TavernText.tiny),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => unawaited(_startChat()),
                  style: FilledButton.styleFrom(
                    backgroundColor: TavernColors.accent,
                    minimumSize: const Size.fromHeight(46),
                  ),
                  child: const Text('开始对话'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => unawaited(_exportJson()),
                        child: const Text('导出 JSON'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => unawaited(_exportPng()),
                        child: const Text('导出 PNG'),
                      ),
                    ),
                  ],
                ),
                const SectionTitle('角色设定'),
                CardBox(
                  child: Column(
                    children: <Widget>[
                      InfoRow(label: '描述', value: '${character['description'] ?? ''}'),
                      InfoRow(label: '性格', value: '${character['personality'] ?? ''}'),
                      InfoRow(label: '场景', value: '${character['scenario'] ?? ''}'),
                      InfoRow(
                        label: '世界书',
                        value: worldNames,
                        onTap: worldIds.isEmpty
                            ? null
                            : () => unawaited(pushPage<void>(
                                  context,
                                  WorldPage(worldId: '${worldIds.first}'),
                                )),
                      ),
                    ],
                  ),
                ),
                const SectionTitle('其他'),
                CardBox(
                  child: Column(
                    children: <Widget>[
                      InfoRow(label: '创作者', value: '${character['creator'] ?? ''}'),
                      InfoRow(label: '版本', value: '${character['characterVersion'] ?? ''}'),
                      InfoRow(label: '开场白数量', value: '${1 + (character['alternateGreetings'] is List ? (character['alternateGreetings'] as List).length : 0)}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(Map<String, dynamic> character) {
    final String path = '${character['avatar'] ?? ''}';
    if (path.isNotEmpty && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(File(path), width: 88, height: 88, fit: BoxFit.cover),
      );
    }
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: TavernColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        '${character['name'] ?? '?'}'.substring(0, 1),
        style: const TextStyle(fontSize: 30, color: TavernColors.accent),
      ),
    );
  }
}

/// 系统「另存为」。取消返回 false。
Future<bool> saveBytes({required String fileName, required Uint8List bytes}) async {
  final Uri? saved = await FilePicker.saveFile(
    fileName: fileName,
    bytes: bytes,
  );
  return saved != null;
}
