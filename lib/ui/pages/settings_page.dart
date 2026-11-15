/// 设置（阶段 0：显示本地数据位置与版本）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/store/tavern_store.dart';
import '../theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = '…';

  @override
  void initState() {
    super.initState();
    unawaited(_loadVersion());
  }

  Future<void> _loadVersion() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = '${info.version} (${info.buildNumber})');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _version = '未知');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final TavernStore store = TavernStore.instance;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('设置', style: TavernText.largeTitle),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: TavernColors.surface,
                borderRadius: BorderRadius.circular(TavernRadius.card),
              ),
              child: Column(
                children: <Widget>[
                  _row('数据位置', store.directoryPath),
                  const Divider(height: 0.5, thickness: 0.5, color: TavernColors.separator),
                  _row('角色 / 世界书 / 对话',
                      '${store.characters.length} / ${store.worlds.length} / ${store.chats.length}'),
                  const Divider(height: 0.5, thickness: 0.5, color: TavernColors.separator),
                  _row('版本', _version),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(title, style: TavernText.body)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TavernText.caption,
            ),
          ),
        ],
      ),
    );
  }
}
