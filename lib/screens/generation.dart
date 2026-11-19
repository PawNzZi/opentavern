import 'package:flutter/material.dart';

import '../core/store.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';
import '../design/toast.dart';

class GenerationPage extends StatefulWidget {
  const GenerationPage({super.key});

  @override
  State<GenerationPage> createState() => _GenerationPageState();
}

class _GenerationPageState extends State<GenerationPage> {
  late double _temperature;
  late double _maxTokens;
  late bool _streaming;

  @override
  void initState() {
    super.initState();
    final api = AppStore.instance.settings.api;
    _temperature = api.temperature;
    _maxTokens = api.maxTokens.toDouble();
    _streaming = api.streaming;
  }

  Future<void> _save() async {
    final settings = AppStore.instance.settings;
    AppStore.instance.settings = settings.copyWith(
      api: settings.api.copyWith(
        temperature: _temperature,
        maxTokens: _maxTokens.round(),
        streaming: _streaming,
      ),
    );
    await AppStore.instance.saveSettings();
    if (!mounted) return;
    showTavernToast(context, '生成参数已保存');
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final preset = AppStore.instance.activePreset;
    return DetailPage(
      eyebrow: 'GENERATION',
      title: '生成参数',
      subtitle: '控制模型怎么写，而不是写什么。',
      footer: GlassPrimaryButton(
        label: '保存生成参数',
        icon: Icons.check_rounded,
        onTap: _save,
      ),
      children: [
        const SizedBox(height: 18),
        Glass(
          radius: 24,
          blur: 24,
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: p.amber.withValues(alpha: .16),
                ),
                child: Icon(Icons.tune_rounded, size: 20, color: p.amber),
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
                            preset?.name ?? '默认预设',
                            overflow: TextOverflow.ellipsis,
                            style: appText(15, FontWeight.w600, p.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 7),
                        const TagBadge('当前'),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${AppStore.instance.settings.api.model} · ${AppStore.instance.settings.api.provider}',
                      style: appText(10.5, FontWeight.w400, p.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SettingsGroup(
          title: '采样',
          footnote: '温度越高越发散。Top P / Top K / 频率惩罚尚未接入 API 请求。',
          children: [
            SliderLine(
              title: '温度',
              value: _temperature,
              min: 0,
              max: 2,
              display: _temperature.toStringAsFixed(2),
              onChanged: (v) => setState(() => _temperature = v),
            ),
            SliderLine(
              title: '最大回复长度',
              value: _maxTokens,
              min: 128,
              max: 4096,
              divisions: 31,
              display: '${_maxTokens.round()} tokens',
              onChanged: (v) => setState(() => _maxTokens = v),
            ),
          ],
        ),
        SettingsGroup(
          title: '流式',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '流式输出',
                          style: appText(13.5, FontWeight.w500, p.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '逐字显示回复，可随时停止',
                          style: appText(10.5, FontWeight.w400, p.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  TavernSwitch(
                    value: _streaming,
                    onChanged: (v) => setState(() => _streaming = v),
                  ),
                ],
              ),
            ),
          ],
        ),
        const HintCard(
          text: '生成的温度与最大长度会立即用于下一次请求；预设里的提示词内容不受影响。',
          color: Color(0xFFD9B48A),
        ),
      ],
    );
  }
}
