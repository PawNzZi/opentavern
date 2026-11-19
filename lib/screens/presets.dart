import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/store.dart';
import '../design/glass.dart';
import '../design/routes.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';
import '../design/toast.dart';
import 'prompts.dart';

class PresetsPage extends StatefulWidget {
  const PresetsPage({super.key});

  @override
  State<PresetsPage> createState() => _PresetsPageState();
}

class _PresetsPageState extends State<PresetsPage> {
  @override
  void initState() {
    super.initState();
    AppStore.instance.addListener(_sync);
  }

  @override
  void dispose() {
    AppStore.instance.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (mounted) setState(() {});
  }

  Future<void> _create() async {
    final source = AppStore.instance.activePreset;
    final preset = PromptPreset(
      id: 'preset-${DateTime.now().microsecondsSinceEpoch}',
      name: '新预设 ${AppStore.instance.presets.length + 1}',
      mainPrompt: source?.mainPrompt ?? '',
      entries: [
        for (final entry in source?.entries ?? const <PromptEntry>[])
          PromptEntry(
            id: 'entry-${DateTime.now().microsecondsSinceEpoch}-${entry.order}',
            name: entry.name,
            content: entry.content,
            role: entry.role,
            enabled: entry.enabled,
            order: entry.order,
          ),
      ],
    );
    await AppStore.instance.addPreset(preset);
    if (!mounted) return;
    setState(() {});
    openGlassPage(context, PromptManagerPage(preset: preset));
  }

  Future<void> _select(PromptPreset preset) async {
    await AppStore.instance.setActivePreset(preset.id);
    if (!mounted) return;
    showTavernToast(context, '已应用 ${preset.name}');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final presets = AppStore.instance.presets;
    final active = AppStore.instance.activePreset;
    return DetailPage(
      eyebrow: 'PRESETS',
      title: '预设',
      subtitle: '主提示词、附加条目与采样参数，一起版本化。',
      footer: GlassPrimaryButton(
        label: '新建预设',
        icon: Icons.add_rounded,
        onTap: _create,
      ),
      children: [
        const SizedBox(height: 18),
        if (active != null)
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
                      Text(
                        active.name,
                        style: appText(16, FontWeight.w600, p.textPrimary),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '温度 ${active.temperature.toStringAsFixed(2)} · ${active.entries.length} 条附加提示词',
                        style: appText(10.5, FontWeight.w400, p.textTertiary),
                      ),
                    ],
                  ),
                ),
                const TagBadge('当前'),
              ],
            ),
          ),
        const SizedBox(height: 14),
        SettingsGroup(
          title: '我的预设',
          trailing: Text(
            '${presets.length} 个',
            style: appText(11, FontWeight.w400, p.textTertiary),
          ),
          children: [
            for (var i = 0; i < presets.length; i++) ...[
              SettingRow(
                icon: Icons.layers_outlined,
                title: presets[i].name,
                subtitle:
                    '温度 ${presets[i].temperature.toStringAsFixed(2)} · ${presets[i].entries.length} 条附加提示词',
                value: presets[i].id == AppStore.instance.activePresetId
                    ? '当前'
                    : '',
                iconColor: p.amber,
                onTap: () => _select(presets[i]),
                trailing: GlassCircleButton(
                  icon: Icons.tune_rounded,
                  size: 30,
                  iconSize: 14,
                  blur: 0,
                  onTap: () => openGlassPage(
                    context,
                    PromptManagerPage(preset: presets[i]),
                  ),
                ),
              ),
              if (i != presets.length - 1) const Hairline(indent: 56),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '预设只影响 Prompt 组装与条目，不会改写角色卡本身。',
          style: appText(10.5, FontWeight.w400, p.textTertiary, height: 1.5),
        ),
      ],
    );
  }
}
