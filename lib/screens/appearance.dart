import 'package:flutter/material.dart';

import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';

class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DetailPage(
      eyebrow: 'APPEARANCE',
      title: '外观',
      subtitle: '当前版本使用固定的液态玻璃视觉。',
      children: [
        const SizedBox(height: 18),
        Glass(
          radius: 28,
          blur: 30,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '液态玻璃',
                style: appText(17, FontWeight.w600, p.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                '半透明卡片、细描边与柔和阴影；打开聊天时会自动降低模糊开销。',
                style: appText(11.5, FontWeight.w400, p.textTertiary, height: 1.5),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _AccentDot(color: p.amber, selected: true),
                  const SizedBox(width: 9),
                  _AccentDot(color: p.rose),
                  const SizedBox(width: 9),
                  _AccentDot(color: p.sage),
                  const SizedBox(width: 9),
                  _AccentDot(color: p.violet),
                ],
              ),
            ],
          ),
        ),
        SettingsGroup(
          title: '当前行为',
          children: const [
            SettingRow(
              icon: Icons.dark_mode_outlined,
              title: '深浅色',
              value: '跟随系统',
              iconColor: Color(0xFFD98E5F),
            ),
            Hairline(indent: 56),
            SettingRow(
              icon: Icons.blur_on_rounded,
              title: '玻璃模糊',
              value: '标准',
              iconColor: Color(0xFF7FA893),
            ),
            Hairline(indent: 56),
            SettingRow(
              icon: Icons.chat_bubble_outline_rounded,
              title: '消息气泡',
              value: '头像 + 时间',
              iconColor: Color(0xFFA9A0E8),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '字号、玻璃强度、强调色与聊天布局的自定义尚未接入；当前版本只提供这套固定外观。',
          style: appText(11, FontWeight.w400, p.textTertiary, height: 1.6),
        ),
      ],
    );
  }
}

class _AccentDot extends StatelessWidget {
  const _AccentDot({required this.color, this.selected = false});

  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Colors.white : Colors.white.withValues(alpha: .35),
          width: selected ? 2 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: .35),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
    );
  }
}
