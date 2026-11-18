import 'package:flutter/material.dart';

import '../data/demo.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/routes.dart';
import '../design/theme.dart';
import 'editors.dart';

class PromptManagerPage extends StatelessWidget {
  const PromptManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final total = demoPrompts.fold<int>(0, (sum, item) => sum + item.tokens);
    return DetailPage(
      eyebrow: 'PROMPT MANAGER',
      title: '提示词',
      subtitle: '决定模型看到什么，以及按什么顺序看到。',
      footer: const GlassPrimaryButton(
        label: '保存顺序',
        icon: Icons.check_rounded,
      ),
      children: [
        const SizedBox(height: 16),
        Glass(
          radius: 24,
          blur: 24,
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
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
                  const TagBadge('Chat Completion'),
                  const Spacer(),
                  Text(
                    '预算 8k',
                    style: appText(10.5, FontWeight.w400, p.textTertiary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$total',
                    style: appText(
                      30,
                      FontWeight.w700,
                      p.amber,
                      letterSpacing: -1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5, left: 4),
                    child: Text(
                      '/ 8192 tokens',
                      style: appText(11, FontWeight.w400, p.textTertiary),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(total / 8192 * 100).toStringAsFixed(0)}%',
                    style: appText(12, FontWeight.w600, p.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ProgressLine(value: total / 8192),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ActionGrid(
          items: [
            ActionSpec(
              icon: Icons.receipt_long_rounded,
              label: '拆分',
              color: p.amber,
              onTap: () {},
            ),
            ActionSpec(
              icon: Icons.code_rounded,
              label: '原始',
              color: p.sage,
              onTap: () {},
            ),
            ActionSpec(
              icon: Icons.difference_rounded,
              label: '对比',
              color: p.violet,
              onTap: () {},
            ),
            ActionSpec(
              icon: Icons.copy_rounded,
              label: '复制',
              color: p.rose,
              onTap: () {},
            ),
          ],
        ),
        SettingsGroup(
          title: '提示词顺序',
          footnote: '拖动左侧手柄调整顺序；开关只影响当前预设。灰色是运行时填充的占位条目。',
          trailing: Text(
            '12 条',
            style: appText(11, FontWeight.w400, p.textTertiary),
          ),
          children: [
            for (final prompt in demoPrompts)
              _PromptRow(
                prompt: prompt,
                onTap: () => openGlassPage(
                  context,
                  PromptEditorSheet(prompt: prompt),
                ),
              ),
            const Hairline(indent: 52),
            SettingRow(
              icon: Icons.add_rounded,
              title: '添加提示词',
              value: '从模板 / 空白',
              iconColor: p.amber,
              onTap: () => openGlassPage(
                context,
                const PromptEditorSheet(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        HintCard(
          text: '提示词条目有稳定 ID（如 main、worldInfoBefore），角色覆盖与预设迁移都依赖它。重命名只改显示名，不要改 ID。',
          color: p.sage,
        ),
      ],
    );
  }
}

class _PromptRow extends StatelessWidget {
  const _PromptRow({required this.prompt, this.onTap});

  final DemoPrompt prompt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final alpha = prompt.enabled ? 1.0 : .4;
    return Opacity(
      opacity: alpha,
      child: Pressable(
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
        child: Row(
          children: [
            Icon(
              Icons.drag_indicator_rounded,
              size: 16,
              color: p.textTertiary,
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 28,
              child: Text(
                prompt.role,
                style: appText(
                  8.5,
                  FontWeight.w700,
                  prompt.role == 'SYS' ? p.amber : p.sage,
                  letterSpacing: .4,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          prompt.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appText(
                            13,
                            FontWeight.w500,
                            p.textPrimary,
                          ),
                        ),
                      ),
                      if (prompt.marker) ...[
                        const SizedBox(width: 5),
                        Icon(
                          Icons.bolt_rounded,
                          size: 11,
                          color: p.textTertiary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${prompt.tokens} tokens',
                        style: appText(9.5, FontWeight.w400, p.textTertiary),
                      ),
                      if (prompt.injection) ...[
                        const SizedBox(width: 6),
                        Text(
                          '@D${prompt.depth}',
                          style: appText(9.5, FontWeight.w600, p.violet),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            TavernSwitch(value: prompt.enabled, onChanged: (_) {}),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: p.textTertiary,
            ),
          ],
        ),
      ),
      ),
    );
  }
}
