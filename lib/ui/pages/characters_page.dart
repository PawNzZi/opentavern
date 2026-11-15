/// 角色列表：导入角色卡（PNG / JSON / charx）、展示已有角色。
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/card/card_io.dart';
import '../../core/store/tavern_store.dart';
import '../theme.dart';
import '../toast.dart';

class CharactersPage extends StatefulWidget {
  const CharactersPage({super.key});

  @override
  State<CharactersPage> createState() => _CharactersPageState();
}

class _CharactersPageState extends State<CharactersPage> {
  List<Map<String, dynamic>> _characters = TavernStore.instance.characters;
  bool _busy = false;

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['png', 'json', 'charx', 'byaf', 'zip'],
      );
      if (files.isEmpty) {
        return;
      }
      final PlatformFile file = files.first;
      final List<int> bytes = await file.readAsBytes();
      final CardImportResult parsed = CardIo.parse(
        Uint8List.fromList(bytes),
        fileName: file.name,
      );
      final Map<String, dynamic> record =
          await TavernStore.instance.importCard(parsed.card, avatar: parsed.image);
      if (!mounted) {
        return;
      }
      setState(() => _characters = TavernStore.instance.characters);
      showToast(context, '已导入「${record['name']}」');
    } on CardException catch (error) {
      if (mounted) {
        showToast(context, error.message);
      }
    } catch (error) {
      if (mounted) {
        showToast(context, '导入失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _remove(Map<String, dynamic> character) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('删除角色？', style: TavernText.title),
        content: Text(
          '「${character['name']}」以及它的头像、内嵌世界书都会被删除。',
          style: TavernText.secondary,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除', style: TextStyle(color: TavernColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await TavernStore.instance.deleteCharacter('${character['id']}');
    if (!mounted) return;
    setState(() => _characters = TavernStore.instance.characters);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text('角色', style: TavernText.largeTitle),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : () => unawaited(_import()),
                  icon: _busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add, size: 18),
                  label: Text(_busy ? '导入中…' : '导入'),
                  style: TextButton.styleFrom(
                    foregroundColor: TavernColors.accent,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _characters.isEmpty ? _empty() : _list(),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.person_outline, size: 40, color: TavernColors.textFaint),
          const SizedBox(height: 12),
          const Text('还没有角色卡', style: TavernText.title),
          const SizedBox(height: 6),
          const Text('支持 PNG（SillyTavern 卡）/ JSON / charx', style: TavernText.caption),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: _busy ? null : () => unawaited(_import()),
            child: const Text('导入角色卡'),
          ),
        ],
      ),
    );
  }

  Widget _list() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      itemCount: _characters.length,
      separatorBuilder: (BuildContext _, int _) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final Map<String, dynamic> character = _characters[index];
        return GestureDetector(
          onLongPress: () => unawaited(_remove(character)),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TavernColors.surface,
              borderRadius: BorderRadius.circular(TavernRadius.card),
            ),
            child: Row(
              children: <Widget>[
                _avatar(character),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${character['name'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TavernText.title,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _subtitle(character),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TavernText.caption,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(character['worldIds'] as List?)?.length ?? 0}',
                  style: TavernText.tiny,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _subtitle(Map<String, dynamic> character) {
    final List<dynamic> tags = character['tags'] is List ? character['tags'] as List : <dynamic>[];
    if (tags.isNotEmpty) {
      return '标签：${tags.take(4).join(' · ')}';
    }
    final String description = '${character['description'] ?? ''}'.replaceAll('\n', ' ');
    return description.isEmpty ? '没有描述' : description;
  }

  Widget _avatar(Map<String, dynamic> character) {
    final String path = '${character['avatar'] ?? ''}';
    if (path.isNotEmpty && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(path),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: TavernColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        '${character['name'] ?? '?'}'.substring(0, 1),
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: TavernColors.accent,
        ),
      ),
    );
  }
}
