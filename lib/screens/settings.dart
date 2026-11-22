import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../core/store.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/theme.dart';
import 'about.dart';
import 'appearance.dart';
import 'automation.dart';
import 'data.dart';
import 'generation.dart';
import 'interaction.dart';
import 'lore.dart';
import 'media.dart';
import 'memory.dart';
import 'presets.dart';
import 'prompts.dart';
import 'sheets.dart';
import 'stats.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.onOpenConnect});

  final VoidCallback onOpenConnect;

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    // The profile card and the counters below all read from AppStore, so the
    // page has to rebuild after persona / quick reply / character edits.
    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) => _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final p = AppPalette.of(context);
    final settings = AppStore.instance.settings;
    final personaName = settings.personaName.trim();
    final personaDesc = settings.personaDescription.trim();
    final quickSets = AppStore.instance.quickReplySets.length;
    final api = settings.api;
    final preset = AppStore.instance.activePreset;
    final promptCount = preset?.entries.length ?? 0;
    final loreCount = AppStore.instance.lorebooks.fold<int>(
      0,
      (sum, book) => sum + book.entries.length,
    );
    final summaryCount =
        AppStore.instance.sessions.where((s) => s.summary.trim().isNotEmpty).length;
    final messageCount = AppStore.instance.sessions.fold<int>(
      0,
      (sum, s) => sum + s.messages.length,
    );
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 168),
        physics: const BouncingScrollPhysics(),
        children: [
          const PageHeader(
            eyebrow: 'LOCAL FIRST',
            title: '设置',
            subtitle: '所有数据只留在这台设备上。',
          ),
          const SizedBox(height: 20),
          Glass(
            radius: 26,
            blur: 26,
            padding: const EdgeInsets.all(13),
            onTap: () => _open(context, const InteractionPage()),
            child: Row(
              children: [
                SizedBox(
                  width: 54,
                  height: 54,
                  child: Portrait(
                    initial: personaName.isEmpty
                        ? '?'
                        : personaName.characters.first,
                    colors: const [
                      Color(0xFF6B4E3D),
                      Color(0xFFC99A6B),
                      Color(0xFF2A1E17),
                    ],
                    radius: 17,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              personaName.isEmpty ? '未设置人格' : personaName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: appText(
                                17,
                                FontWeight.w600,
                                p.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: p.sage.withValues(alpha: .16),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '本地档案',
                              style: appText(8.5, FontWeight.w600, p.sage),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        personaDesc.isEmpty
                            ? '$quickSets 组快捷回复 · 点击设置人格'
                            : personaDesc,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appText(11.5, FontWeight.w400, p.textTertiary),
                      ),
                    ],
                  ),
                ),
                GlassCircleButton(
                  icon: Icons.edit_outlined,
                  size: 34,
                  iconSize: 15,
                  blur: 0,
                  onTap: () => _open(context, const InteractionPage()),
                ),
              ],
            ),
          ),
          const SectionLabel('模型'),
          Glass(
            radius: 24,
            blur: 24,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                SettingRow(
                  icon: Icons.bolt_rounded,
                  title: 'API 连接',
                  value: api.model.trim().isEmpty ? '未配置' : api.model,
                  iconColor: p.amber,
                  onTap: onOpenConnect,
                  trailing: Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      color: api.apiKey.trim().isEmpty ? p.textTertiary : p.sage,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const Hairline(indent: 56),
                SettingRow(
                  icon: Icons.tune_rounded,
                  title: '生成参数',
                  value: '温度 ${api.temperature.toStringAsFixed(2)}',
                  iconColor: p.violet,
                  onTap: () => _open(context, const GenerationPage()),
                ),
                const Hairline(indent: 56),
                SettingRow(
                  icon: Icons.layers_outlined,
                  title: '预设',
                  value: preset?.name ?? '默认',
                  iconColor: p.rose,
                  onTap: () => _open(context, const PresetsPage()),
                ),
              ],
            ),
          ),
          const SectionLabel('创作'),
          Glass(
            radius: 24,
            blur: 24,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                SettingRow(
                  icon: Icons.subject_rounded,
                  title: '提示词',
                  value: '$promptCount 条提示词',
                  iconColor: p.amber,
                  onTap: () => _open(context, const PromptManagerPage()),
                ),

                const Hairline(indent: 56),
                SettingRow(
                  icon: Icons.auto_stories_rounded,
                  title: '世界书',
                  value: '${AppStore.instance.lorebooks.length} 本 · $loreCount 条',
                  iconColor: p.sage,
                  onTap: () => _open(context, const LoreScreen()),
                ),
                const Hairline(indent: 56),
                SettingRow(
                  icon: Icons.psychology_alt_outlined,
                  title: '记忆与知识',
                  value: '$summaryCount 段摘要',
                  iconColor: p.violet,
                  onTap: () => _open(context, const MemoryPage()),
                ),
                const Hairline(indent: 56),
              ],
            ),
          ),
          const SectionLabel('交互'),
          Glass(
            radius: 24,
            blur: 24,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                SettingRow(
                  icon: Icons.face_retouching_natural_rounded,
                  title: '人格与快捷回复',
                  value: '${AppStore.instance.quickReplySets.length} 组快捷回复',
                  iconColor: p.amber,
                  onTap: () => _open(context, const InteractionPage()),
                ),
                const Hairline(indent: 56),
                SettingRow(
                  icon: Icons.find_replace_rounded,
                  title: '正则与宏',
                  value: '${AppStore.instance.regexScripts.length} 个正则',
                  iconColor: p.violet,
                  onTap: () => _open(context, const AutomationPage()),
                ),
                const Hairline(indent: 56),
                SettingRow(
                  icon: Icons.insights_rounded,
                  title: '统计',
                  value: '$messageCount 条消息',
                  iconColor: p.sage,
                  onTap: () => _open(context, const StatsPage()),
                ),
              ],
            ),
          ),
          const SectionLabel('媒体'),
          Glass(
            radius: 24,
            blur: 24,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                SettingRow(
                  icon: Icons.record_voice_over_rounded,
                  title: '语音、图像与翻译',
                  value: '未启用',
                  iconColor: p.rose,
                  onTap: () => _open(context, const MediaPage()),
                ),
              ],
            ),
          ),
          const SectionLabel('外观'),
          Glass(
            radius: 24,
            blur: 24,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SettingRow(
              icon: Icons.palette_outlined,
              title: '外观与显示',
              subtitle: '主题 · 液态玻璃 · 字号与气泡',
              value: '默认外观',
              iconColor: p.amber,
              onTap: () => _open(context, const AppearancePage()),
            ),
          ),
          const SectionLabel('数据'),
          Glass(
            radius: 24,
            blur: 24,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                SettingRow(
                  icon: Icons.file_download_outlined,
                  title: '导入角色',
                  value: 'PNG · JSON',
                  iconColor: p.amber,
                  onTap: () => _open(context, const ImportSheetScreen()),
                ),
                const Hairline(indent: 56),
                SettingRow(
                  icon: Icons.archive_outlined,
                  title: '数据与备份',
                  value: '手动导入 / 导出',
                  iconColor: p.sage,
                  onTap: () => _open(context, const DataPage()),
                ),
                const Hairline(indent: 56),
                SettingRow(
                  icon: Icons.storage_rounded,
                  title: '存储空间',
                  value: '本地目录',
                  iconColor: p.violet,
                  onTap: () => _open(context, const DataPage()),
                ),
              ],
            ),
          ),
          const SectionLabel('关于'),
          Glass(
            radius: 24,
            blur: 24,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                SettingRow(
                  icon: Icons.science_outlined,
                  title: '实验室与关于',
                  value: '版本与说明',
                  iconColor: p.amber,
                  onTap: () => _open(context, const AboutPage()),
                ),
                const Hairline(indent: 56),
                SettingRow(
                  icon: Icons.info_outline_rounded,
                  title: '版本',
                  value: '1.0.0',
                  iconColor: p.textTertiary,
                  chevron: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Text(
              '本地运行 · 无账号 · 无追踪',
              style: appText(10.5, FontWeight.w400, p.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}
