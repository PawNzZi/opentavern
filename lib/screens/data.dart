import 'package:flutter/material.dart';

import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';

class DataPage extends StatelessWidget {
  const DataPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DetailPage(
      eyebrow: 'DATA & BACKUP',
      title: '数据与备份',
      subtitle: '你的数据只在这台设备上，也随时可以带走。',
      children: [
        const SizedBox(height: 18),
        Glass(
          radius: 24,
          blur: 24,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '存储空间',
                    style: appText(14, FontWeight.w500, p.textPrimary),
                  ),
                  const Spacer(),
                  Text(
                    '128 MB',
                    style: appText(15, FontWeight.w700, p.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 46,
                        child: ColoredBox(color: p.amber),
                      ),
                      Expanded(
                        flex: 24,
                        child: ColoredBox(
                          color: p.violet.withValues(alpha: .8),
                        ),
                      ),
                      Expanded(
                        flex: 18,
                        child: ColoredBox(
                          color: p.sage.withValues(alpha: .8),
                        ),
                      ),
                      Expanded(
                        flex: 12,
                        child: ColoredBox(
                          color: p.rose.withValues(alpha: .7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  _Legend(color: p.amber, label: '聊天 59 MB'),
                  _Legend(color: p.violet, label: '角色 31 MB'),
                  _Legend(color: p.sage, label: '图片 23 MB'),
                  _Legend(color: p.rose, label: '其他 15 MB'),
                ],
              ),
            ],
          ),
        ),
        SettingsGroup(
          title: '导入',
          children: const [
            SettingRow(
              icon: Icons.person_add_alt_rounded,
              title: '角色卡',
              value: 'PNG · JSON · CHARX',
              iconColor: Color(0xFFF0B36A),
              onTap: null,
            ),
            Hairline(indent: 56),
            SettingRow(
              icon: Icons.forum_outlined,
              title: '聊天记录',
              value: 'JSONL · TXT',
              iconColor: Color(0xFF8FD0BE),
              onTap: null,
            ),
            Hairline(indent: 56),
            SettingRow(
              icon: Icons.auto_stories_rounded,
              title: '世界书',
              value: 'JSON · 角色卡内嵌',
              iconColor: Color(0xFFA9A0E8),
              onTap: null,
            ),
            Hairline(indent: 56),
            SettingRow(
              icon: Icons.layers_outlined,
              title: '预设 / 人格 / 主题',
              value: 'JSON',
              iconColor: Color(0xFFEE9AA8),
              onTap: null,
            ),
          ],
        ),
        SettingsGroup(
          title: '导出',
          children: [
            SettingRow(
              icon: Icons.archive_outlined,
              title: '全量备份',
              value: 'ZIP · 可直接还原',
              iconColor: p.amber,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.file_upload_outlined,
              title: '导出全部聊天',
              value: 'JSONL',
              iconColor: p.sage,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.image_outlined,
              title: '导出角色卡',
              value: 'PNG（含元数据）',
              iconColor: p.violet,
              onTap: () {},
            ),
          ],
        ),
        SettingsGroup(
          title: '自动备份',
          footnote: '备份写在本地 backups/ 目录，不联网、不上传。',
          children: const [
            SwitchLine(
              title: '自动备份聊天',
              subtitle: '每次保存前保留一个版本',
              value: true,
            ),
            SwitchLine(
              title: '备份设置变更',
              subtitle: '保留最近 20 次设置快照',
              value: true,
            ),
            StepperRow(
              title: '保留份数',
              subtitle: '超出后自动删除最旧',
              value: '50',
            ),
            SettingRow(
              icon: Icons.schedule_rounded,
              title: '上次备份',
              value: '今天 21:40 · 128 MB',
              iconColor: Color(0xFF8FD0BE),
              onTap: null,
              chevron: false,
            ),
          ],
        ),
        SettingsGroup(
          title: '维护',
          children: [
            SettingRow(
              icon: Icons.cleaning_services_outlined,
              title: '数据体检',
              subtitle: '查找孤立文件、重复图片、空目录',
              value: '扫描',
              iconColor: p.amber,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.compress_rounded,
              title: '压缩缩略图',
              value: '可释放 18 MB',
              iconColor: p.sage,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.restore_rounded,
              title: '从备份还原',
              value: '3 个可用',
              iconColor: p.violet,
              onTap: () {},
            ),
          ],
        ),
        SettingsGroup(
          title: '危险操作',
          children: [
            SettingRow(
              icon: Icons.delete_forever_rounded,
              title: '清空所有聊天',
              value: '不可撤销',
              iconColor: p.danger,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.restart_alt_rounded,
              title: '恢复出厂设置',
              value: '删除全部本地数据',
              iconColor: p.danger,
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 18),
        HintCard(
          text: '删除前至少做一次全量备份。备份文件包含角色卡、聊天、世界书、预设与设置，但不包含 API 密钥。',
          color: p.danger,
          icon: Icons.warning_amber_rounded,
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: appText(9.5, FontWeight.w400, p.textTertiary),
        ),
      ],
    );
  }
}
