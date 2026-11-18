import 'package:flutter/material.dart';

import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';

class GenerationPage extends StatelessWidget {
  const GenerationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DetailPage(
      eyebrow: 'GENERATION',
      title: '生成参数',
      subtitle: '控制模型怎么写，而不是写什么。',
      footer: const GlassPrimaryButton(
        label: '保存为当前预设',
        icon: Icons.check_rounded,
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
                        Text(
                          '长夜 · 叙事',
                          style: appText(15, FontWeight.w600, p.textPrimary),
                        ),
                        const SizedBox(width: 7),
                        const TagBadge('当前'),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Chat Completion · 12 条提示词',
                      style: appText(10.5, FontWeight.w400, p.textTertiary),
                    ),
                  ],
                ),
              ),
              Text(
                '另存为',
                style: appText(12, FontWeight.w500, p.amber),
              ),
            ],
          ),
        ),
        SettingsGroup(
          title: '采样',
          footnote: '温度越高越发散；top_p 与 top_k 限制候选范围。',
          children: const [
            SliderLine(
              title: '温度',
              value: .85,
              min: 0,
              max: 2,
              display: '0.85',
            ),
            SliderLine(
              title: 'Top P',
              value: .95,
              min: 0,
              max: 1,
              display: '0.95',
            ),
            SliderLine(
              title: 'Top K',
              value: 40,
              min: 0,
              max: 100,
              divisions: 100,
              display: '40',
            ),
            SliderLine(
              title: '频率惩罚',
              value: .1,
              min: -2,
              max: 2,
              display: '0.10',
            ),
            SliderLine(
              title: '存在惩罚',
              value: .1,
              min: -2,
              max: 2,
              display: '0.10',
            ),
            SliderLine(
              title: '重复惩罚',
              value: 1.05,
              min: 1,
              max: 1.5,
              display: '1.05',
            ),
          ],
        ),
        SettingsGroup(
          title: '长度',
          children: const [
            StepperRow(
              title: '上下文长度',
              subtitle: '模型一次能看到的 token 数',
              value: '128k',
            ),
            StepperRow(
              title: '回复长度',
              subtitle: '预留给模型输出的 token',
              value: '4096',
            ),
            StepperRow(
              title: 'Tokenizer',
              subtitle: '用于预算与计数',
              value: 'Claude',
            ),
          ],
        ),
        SettingsGroup(
          title: '随机与停止',
          children: [
            const FieldBlock(
              label: '种子',
              value: '随机（每次不同）',
              trailing: Icon(
                Icons.casino_outlined,
                size: 16,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '停止字符串',
                    style: appText(13.5, FontWeight.w500, p.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: const [
                      GlassPill(label: '\\nUser:', height: 30),
                      GlassPill(label: '\\nSeraphina:', height: 30),
                      GlassPill(label: '+ 添加', height: 30),
                    ],
                  ),
                ],
              ),
            ),
            const SwitchLine(
              title: '流式输出',
              subtitle: '逐字显示，可随时停止',
              value: true,
            ),
            const SwitchLine(
              title: '自动继续',
              subtitle: '回复被截断时自动续写',
              value: false,
            ),
          ],
        ),
        SettingsGroup(
          title: '高级',
          footnote: '这些选项会影响可复现性与费用，不确定时保持默认。',
          children: [
            SettingRow(
              icon: Icons.tune_rounded,
              title: 'Logit Bias',
              value: '2 组',
              iconColor: p.violet,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.speed_rounded,
              title: 'CFG Scale',
              value: '关闭',
              iconColor: p.rose,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.analytics_outlined,
              title: 'Logprobs',
              value: '关闭',
              iconColor: p.sage,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.shuffle_rounded,
              title: '采样器顺序',
              value: '默认',
              iconColor: p.amber,
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 18),
        const HintCard(
          text: '修改后不会立刻覆盖预设。点底部「保存为当前预设」，或另存为新预设，才能在不同角色间复用。',
        ),
      ],
    );
  }
}
