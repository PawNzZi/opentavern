import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/store.dart';
import '../design/glass.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';
import '../design/toast.dart';

/// 外观与显示：主题、强调色、聊天字号 / 头像 / 时间。所有控件都直接写入
/// AppStore.settings 并立即生效（MaterialApp 与聊天页都监听 store）。
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  Future<void> _update(AppSettings Function(AppSettings) change) async {
    final store = AppStore.instance;
    store.settings = change(store.settings);
    await store.saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) => _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final s = AppStore.instance.settings;
    final themeIndex = switch (s.themeMode) {
      'light' => 1,
      'system' => 2,
      _ => 0,
    };
    return DetailPage(
      eyebrow: 'APPEARANCE',
      title: '外观与显示',
      subtitle: '主题、强调色与聊天显示，改完立即生效。',
      trailing: GlassCircleButton(
        icon: Icons.restart_alt_rounded,
        size: 40,
        iconSize: 17,
        onTap: () async {
          await _update((x) => x.copyWith(
                themeMode: 'dark',
                accent: 'amber',
                chatFontSize: 15,
                showAvatar: true,
                showTimestamp: true,
              ));
          if (context.mounted) showTavernToast(context, '已恢复默认外观');
        },
      ),
      children: [
        SettingsGroup(
          title: '主题',
          footnote: '深色是酒馆的默认夜色；浅色适合白天阅读，跟随系统则自动切换。',
          children: [
            SegmentLine(
              title: '深浅色',
              options: const ['深色', '浅色', '跟随系统'],
              index: themeIndex,
              onChanged: (i) => _update(
                (x) => x.copyWith(
                  themeMode: switch (i) { 1 => 'light', 2 => 'system', _ => 'dark' },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SettingsGroup(
          title: '强调色',
          footnote: '影响按钮、滑块、选中态与你的消息气泡。',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: _AccentPicker(
                selected: s.accent,
                onChanged: (a) => _update((x) => x.copyWith(accent: a)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SettingsGroup(
          title: '聊天显示',
          children: [
            SliderLine(
              title: '消息字号',
              value: s.chatFontSize,
              min: 12,
              max: 20,
              divisions: 8,
              display: s.chatFontSize.toStringAsFixed(0),
              onChanged: (v) => _update((x) => x.copyWith(chatFontSize: v)),
            ),
            const Hairline(indent: 14),
            SwitchLine(
              title: '显示角色头像',
              subtitle: '在每条角色消息左侧显示头像',
              value: s.showAvatar,
              onChanged: (v) => _update((x) => x.copyWith(showAvatar: v)),
            ),
            const Hairline(indent: 14),
            SwitchLine(
              title: '显示消息时间',
              subtitle: '在气泡下方显示发送时间',
              value: s.showTimestamp,
              onChanged: (v) => _update((x) => x.copyWith(showTimestamp: v)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const SectionLabel('预览'),
        _Preview(settings: s),
        const SizedBox(height: 16),
        const HintCard(
          text: '以上设置只保存在本机，会立刻应用到整个界面与聊天页。',
        ),
      ],
    );
  }
}

class _AccentPicker extends StatelessWidget {
  const _AccentPicker({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  static const _options = [
    ('amber', '琥珀', Color(0xFFF0B36A)),
    ('rose', '玫瑰', Color(0xFFEE9AA8)),
    ('sage', '青瓷', Color(0xFF8FD0BE)),
    ('violet', '紫罗兰', Color(0xFFA9A0E8)),
  ];

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      children: [
        for (final (key, label, color) in _options)
          Expanded(
            child: Pressable(
              onTap: () => onChanged(key),
              child: Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected == key
                            ? p.textPrimary
                            : Colors.transparent,
                        width: 2.4,
                      ),
                      boxShadow: selected == key
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: .4),
                                blurRadius: 12,
                              ),
                            ]
                          : null,
                    ),
                    child: selected == key
                        ? Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.black.withValues(alpha: .6),
                          )
                        : null,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    label,
                    style: appText(
                      10.5,
                      selected == key ? FontWeight.w600 : FontWeight.w400,
                      selected == key ? p.textPrimary : p.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 即时预览：用当前字号 / 头像 / 时间 / 强调色渲染一条角色消息和一条用户消息。
class _Preview extends StatelessWidget {
  const _Preview({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final fs = settings.chatFontSize;
    return Glass(
      radius: 24,
      blur: 24,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (settings.showAvatar) ...[
                SizedBox(
                  width: 26,
                  height: 26,
                  child: Portrait(
                    initial: '艾',
                    colors: const [
                      Color(0xFF6B4E3D),
                      Color(0xFFC99A6B),
                      Color(0xFF2A1E17),
                    ],
                    radius: 8,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Glass(
                      radius: 16,
                      blur: 18,
                      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
                      child: Text(
                        '“今晚的酒馆，格外安静。”',
                        style: appText(fs, FontWeight.w400, p.textPrimary,
                            height: 1.5),
                      ),
                    ),
                    if (settings.showTimestamp) ...[
                      const SizedBox(height: 4),
                      Text(
                        '21:41',
                        style: appText(8.5, FontWeight.w400, p.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(13, 9, 13, 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [p.userBubbleStart, p.userBubbleEnd],
                    ),
                  ),
                  child: Text(
                    '给我讲个故事吧。',
                    style: appText(fs, FontWeight.w400, p.onUserBubble,
                        height: 1.5),
                  ),
                ),
                if (settings.showTimestamp) ...[
                  const SizedBox(height: 4),
                  Text(
                    '21:42',
                    style: appText(8.5, FontWeight.w400, p.textTertiary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
