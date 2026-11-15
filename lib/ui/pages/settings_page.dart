/// 设置入口：身份 / 供应商 / 生成 / 提示词 / 记忆 / 备份 / 关于。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/settings/app_settings.dart';
import '../../core/store/tavern_store.dart';
import '../ios_kit.dart';
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
          const IosSectionHeader('账号'),
          IosGroup(
            children: <Widget>[
              IosCell(
                title: '身份与称呼',
                subtitle: '${_settings.userName} · 用户设定',
                onTap: () => unawaited(_open(const ProfilePage())),
              ),
            ],
          ),
          const IosSectionHeader('模型'),
          IosGroup(
            children: <Widget>[
              IosCell(
                title: 'AI 供应商',
                subtitle: _providerSubtitle,
                onTap: () => unawaited(_open(const ProviderPage())),
              ),
              IosCell(
                title: '生成参数',
                subtitle: '历史 ${_settings.historyLimit} 条 · 温度 ${_settings.temperature.toStringAsFixed(2)}',
                onTap: () => unawaited(_open(const GenerationPage())),
              ),
              IosCell(
                title: '提示词',
                subtitle: '段落顺序与主提示词',
                onTap: () => unawaited(_open(const PromptSettingsPage())),
              ),
              IosCell(
                title: '剧情记忆',
                subtitle: _settings.memoryAuto ? '自动压缩开' : '仅手动压缩',
                onTap: () => unawaited(_open(const MemorySettingsPage())),
              ),
            ],
          ),
          const IosSectionHeader('数据'),
          IosGroup(
            children: <Widget>[
              IosCell(
                title: '数据与备份',
                subtitle: '${store.characters.length} 角色 · ${store.chats.length} 对话',
                onTap: () => unawaited(_open(const BackupPage())),
              ),
            ],
          ),
          const IosSectionHeader('关于'),
          IosGroup(
            children: <Widget>[
              IosCell(title: '版本', trailing: Text(_version, style: TavernText.caption)),
              IosCell(
                title: '存储位置',
                subtitle: store.dataFilePath,
              ),
              const IosCell(
                title: '说明',
                subtitle: '单机版：数据只保存在本机，AI 直连你配置的供应商。',
              ),
            ],
          ),
        ],
      ),
    );
  }

}
