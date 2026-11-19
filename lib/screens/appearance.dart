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
      title: '外观与交互',
      subtitle: '玻璃、字体、气泡与背景，都可以按你的方式调。',
      children: [
        const SettingsGroup(
          title: '主题',
          children: [
            SegmentLine(
              title: '模式',
              options: ['深色', '浅色', '跟随系统'],
              index: 0,
            ),
            SegmentLine(
              title: '玻璃强度',
              options: ['标准', '减弱', '关闭'],
              index: 0,
            ),
            SliderLine(
              title: '模糊半径',
              value: 26,
              min: 0,
              max: 40,
              divisions: 40,
              display: '26px',
            ),
            SliderLine(
              title: '字号',
              value: 1,
              min: .85,
              max: 1.15,
              display: '100%',
            ),
          ],
        ),
        const SizedBox(height: 14),
        Glass(
          radius: 24,
          blur: 24,
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Row(
            children: [
              Text(
                '强调色',
                style: appText(13.5, FontWeight.w500, p.textPrimary),
              ),
              const Spacer(),
              _AccentDot(color: p.amber, selected: true),
              const SizedBox(width: 9),
              _AccentDot(color: p.rose),
              const SizedBox(width: 9),
              _AccentDot(color: p.sage),
              const SizedBox(width: 9),
              _AccentDot(color: p.violet),
            ],
          ),
        ),
        SettingsGroup(
          title: '聊天显示',
          children: const [
            SwitchLine(
              title: '气泡样式',
              subtitle: '关闭后使用无气泡的纯文本排版',
              value: true,
            ),
            SwitchLine(
              title: '显示头像',
              subtitle: '角色消息左侧的小头像',
              value: true,
            ),
            SwitchLine(
              title: '显示时间戳',
              subtitle: '每条消息下方的发送时间',
              value: true,
            ),
            SliderLine(
              title: '消息宽度',
              value: .74,
              min: .5,
              max: .9,
              display: '74%',
            ),
          ],
        ),
        Glass(
          radius: 24,
          blur: 24,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '聊天背景',
                    style: appText(14, FontWeight.w500, p.textPrimary),
                  ),
                  const Spacer(),
                  const TagBadge('仅当前聊天', color: Color(0xFF8FD0BE)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 108,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF8C4A3F),
                              Color(0xFFD98E5F),
                              Color(0xFF2A1A20),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        bottom: 10,
                        child: Text(
                          '王都的雨夜.jpg',
                          style: appText(
                            10,
                            FontWeight.w500,
                            Colors.white70,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: GlassPill(
                          label: '更换',
                          height: 30,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const SliderLine(
                title: '背景模糊',
                value: 12,
                min: 0,
                max: 40,
                divisions: 40,
                display: '12px',
              ),
              const SliderLine(
                title: '暗化',
                value: .35,
                display: '35%',
              ),
            ],
          ),
        ),
        SettingsGroup(
          title: '动效与布局',
          children: const [
            SwitchLine(
              title: '减弱动态效果',
              subtitle: '关闭位移与缩放，只保留淡入',
              value: false,
            ),
            SwitchLine(
              title: '可视化小说模式',
              subtitle: '全屏立绘 + 底部文本框',
              value: false,
            ),
            SwitchLine(
              title: '可移动 UI',
              subtitle: '长按面板拖动位置',
              value: false,
            ),
            SettingRow(
              icon: Icons.keyboard_rounded,
              title: '快捷键',
              value: '8 个',
              iconColor: Color(0xFFA9A0E8),
              onTap: null,
            ),
          ],
        ),
        const SizedBox(height: 18),
        const HintCard(
          text: '玻璃效果越强，GPU 开销越高。低电量模式或旧设备建议使用「减弱」；「关闭」会改用实色卡片，最省电。',
          color: Color(0xFF8FD0BE),
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
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Colors.white : Colors.transparent,
          width: 1.2,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}
