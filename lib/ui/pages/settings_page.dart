/// 设置入口：身份 / 供应商 / 生成 / 提示词 / 记忆 / 备份 / 关于。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/settings/app_settings.dart';
import '../../core/store/tavern_store.dart';
import '../nav.dart';
import '../theme.dart';
import 'backup_page.dart';
import 'settings_sub_pages.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AppSettings _settings = AppSettings.instance;
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
      if (mounted) setState(() => _version = '未知');
    }
  }

  String get _providerSubtitle {
    final String kind = _settings.providerKind;
    if (kind == 'none' || !_settings.hasProvider) {
      return '未配置 · 不配置无法对话';
    }
    final String label = const <String, String>{
          'deepseek': 'DeepSeek',
          'openrouter': 'OpenRouter',
          'custom': '自定义',
        }[kind] ??
        kind;
    return '$label · ${_settings.providerModel}';
  }

  Future<void> _open(Widget page) async {
    await pushPage<void>(context, page);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final TavernStore store = TavernStore.instance;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: <Widget>[
          const Text('设置', style: TavernText.largeTitle),
          const SectionTitle('账号'),
          CardBox(
            child: _row('身份与称呼', '${_settings.userName} · 用户设定', () {
              unawaited(_open(const ProfilePage()));
            }),
          ),
          const SectionTitle('模型'),
          CardBox(
            child: _row('AI 供应商', _providerSubtitle, () {
              unawaited(_open(const ProviderPage()));
            }),
          ),
          CardBox(
            child: _row('生成参数', '历史 ${_settings.historyLimit} 条 · 温度 ${_settings.temperature.toStringAsFixed(2)}', () {
              unawaited(_open(const GenerationPage()));
            }),
          ),
          CardBox(
            child: _row('提示词', '段落顺序与主提示词', () {
              unawaited(_open(const PromptSettingsPage()));
            }),
          ),
          CardBox(
            child: _row('剧情记忆', _settings.memoryAuto ? '自动压缩开' : '仅手动压缩', () {
              unawaited(_open(const MemorySettingsPage()));
            }),
          ),
          const SectionTitle('数据'),
          CardBox(
            child: _row('数据与备份', '${store.characters.length} 角色 · ${store.chats.length} 对话', () {
              unawaited(_open(const BackupPage()));
            }),
          ),
          const SectionTitle('关于'),
          CardBox(
            child: Column(
              children: <Widget>[
                InfoRow(label: '版本', value: _version),
                InfoRow(label: '存储位置', value: store.dataFilePath),
                const InfoRow(label: '说明', value: '单机版：数据只保存在本机，AI 直连你配置的供应商。'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      title: Text(title, style: TavernText.body),
      subtitle: Text(subtitle, style: TavernText.caption),
      trailing: const Icon(Icons.chevron_right, size: 18, color: TavernColors.textFaint),
      onTap: onTap,
    );
  }
}
