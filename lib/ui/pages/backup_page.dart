/// 数据与备份：导出/导入整库 JSON。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/store/tavern_store.dart';
import '../nav.dart';
import '../theme.dart';
import '../toast.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _busy = false;

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final String json = const JsonEncoder.withIndent('  ')
          .convert(TavernStore.instance.snapshot());
      final Uri? saved = await FilePicker.saveFile(
        fileName: 'openTavern-backup.json',
        bytes: Uint8List.fromList(utf8.encode(json)),
      );
      if (!mounted) return;
      showToast(context, saved != null ? '备份已导出' : '已取消');
    } catch (error) {
      if (mounted) showToast(context, '导出失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['json'],
      );
      if (files.isEmpty) return;
      final List<int> bytes = await files.first.readAsBytes();
      if (!mounted) return;
      final Object? parsed = jsonDecode(utf8.decode(bytes, allowMalformed: true));
      if (parsed is! Map) {
        throw '备份文件不是 JSON 对象';
      }
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Text('覆盖导入？', style: TavernText.title),
          content: const Text(
            '当前的角色、世界书与对话会被备份内容替换。',
            style: TavernText.secondary,
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('覆盖', style: TextStyle(color: TavernColors.danger)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await TavernStore.instance.replaceAll(Map<String, dynamic>.from(parsed));
      if (!mounted) return;
      showToast(context, '已导入备份');
      setState(() {});
    } catch (error) {
      if (mounted) showToast(context, '导入失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TavernStore store = TavernStore.instance;
    return Scaffold(
      backgroundColor: TavernColors.bg,
      body: Column(
        children: <Widget>[
          const NavBar(title: '数据与备份'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                CardBox(
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        title: const Text('导出备份', style: TavernText.body),
                        subtitle: const Text('角色 / 世界书 / 对话 / 设置，单个 JSON', style: TavernText.caption),
                        trailing: const Icon(Icons.ios_share, size: 18, color: TavernColors.accent),
                        onTap: _busy ? null : () => unawaited(_export()),
                      ),
                      ListTile(
                        title: const Text('导入备份', style: TavernText.body),
                        subtitle: const Text('会覆盖当前全部数据', style: TavernText.caption),
                        trailing: const Icon(Icons.download, size: 18, color: TavernColors.accent),
                        onTap: _busy ? null : () => unawaited(_import()),
                      ),
                    ],
                  ),
                ),
                const SectionTitle('当前数据'),
                CardBox(
                  child: Column(
                    children: <Widget>[
                      InfoRow(label: '角色', value: '${store.characters.length}'),
                      InfoRow(label: '世界书', value: '${store.worlds.length}'),
                      InfoRow(label: '对话', value: '${store.chats.length}'),
                      InfoRow(label: '存储位置', value: store.dataFilePath),
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
}
