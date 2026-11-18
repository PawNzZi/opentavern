import 'package:flutter/material.dart';

import '../data/demo.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';

class PresetsPage extends StatelessWidget {
  const PresetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DetailPage(
      eyebrow: 'PRESETS',
      title: '预设',
      subtitle: '采样参数、提示词与格式，一起版本化。',
      footer: const GlassPrimaryButton(
        label: '新建预设',
        icon: Icons.add_rounded,
      ),
      children: [
        const SizedBox(height: 18),
        Glass(
          radius: 24,
          blur: 26,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [
                      p.amber.withValues(alpha: .8),
                      p.rose.withValues(alpha: .6),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.layers_rounded,
                  size: 21,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '长夜 · 叙事',
                          style: appText(16, FontWeight.w600, p.textPrimary),
                        ),
                        const SizedBox(width: 7),
                        const TagBadge('当前'),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '温度 0.85 · 12 条提示词 · 128k',
                      style: appText(10.5, FontWeight.w400, p.textTertiary),
                    ),
                  ],
                ),
              ),
              const TagBadge('已绑定 Claude', color: Color(0xFF8FD0BE)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: const [
              GlassPill(label: '全部', selected: true),
              SizedBox(width: 8),
              GlassPill(label: 'Chat'),
              SizedBox(width: 8),
              GlassPill(label: 'Text'),
              SizedBox(width: 8),
              GlassPill(label: 'Instruct'),
              SizedBox(width: 8),
              GlassPill(label: 'Context'),
              SizedBox(width: 8),
              GlassPill(label: 'Reasoning'),
            ],
          ),
        ),
        SettingsGroup(
          title: '我的预设',
          trailing: Text(
            '6 个',
            style: appText(11, FontWeight.w400, p.textTertiary),
          ),
          children: [
            for (var i = 0; i < demoPresets.length; i++) ...[
              _PresetRow(preset: demoPresets[i]),
              if (i != demoPresets.length - 1) const Hairline(indent: 52),
            ],
          ],
        ),
        SettingsGroup(
          title: '管理',
          children: [
            SettingRow(
              icon: Icons.file_download_outlined,
              title: '导入预设',
              value: 'JSON',
              iconColor: p.amber,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.file_upload_outlined,
              title: '导出当前预设',
              value: '含连接配置',
              iconColor: p.sage,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.restore_rounded,
              title: '恢复默认预设',
              value: '4 个内置',
              iconColor: p.violet,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.link_rounded,
              title: '绑定到连接',
              value: 'Claude 长文',
              iconColor: p.rose,
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 18),
        const HintCard(
          text: '预设里既有滑块，也有提示词列表和格式设置。导出时可以携带连接配置，但永远不会导出 API 密钥。',
        ),
      ],
    );
  }
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({required this.preset});

  final DemoPreset preset;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: (preset.selected ? p.amber : p.textTertiary).withValues(
                alpha: .14,
              ),
            ),
            child: Icon(
              preset.selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 17,
              color: preset.selected ? p.amber : p.textTertiary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        preset.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appText(14, FontWeight.w500, p.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 6),
                    TagBadge(
                      preset.kind,
                      color: preset.kind == 'Chat Completion'
                          ? p.amber
                          : p.violet,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  preset.meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appText(10, FontWeight.w400, p.textTertiary),
                ),
              ],
            ),
          ),
          Icon(
            Icons.more_horiz_rounded,
            size: 18,
            color: p.textTertiary,
          ),
        ],
      ),
    );
  }
}
