import 'package:flutter/material.dart';

import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DetailPage(
      eyebrow: 'ABOUT',
      title: '关于酒馆',
      subtitle: '本地运行，数据属于你。',
      children: [
        const SizedBox(height: 18),
        Glass(
          radius: 26,
          blur: 26,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(19),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [p.userBubbleStart, p.userBubbleEnd],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: p.amber.withValues(alpha: .3),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.local_bar_rounded,
                  size: 30,
                  color: p.onUserBubble,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '酒馆',
                style: appText(
                  24,
                  FontWeight.w700,
                  p.textPrimary,
                  letterSpacing: -.8,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '1.0.0 (1) · iOS 26',
                style: appText(10.5, FontWeight.w400, p.textTertiary),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  TagBadge('本地优先', color: Color(0xFF8FD0BE)),
                  SizedBox(width: 6),
                  TagBadge('无账号'),
                  SizedBox(width: 6),
                  TagBadge('无追踪', color: Color(0xFFA9A0E8)),
                ],
              ),
            ],
          ),
        ),
        SettingsGroup(
          title: '链接',
          children: const [
            SettingRow(
              icon: Icons.code_rounded,
              title: 'GitHub',
              value: 'SillyTavern',
              iconColor: Color(0xFFF0B36A),
              onTap: null,
            ),
            Hairline(indent: 56),
            SettingRow(
              icon: Icons.menu_book_rounded,
              title: '使用文档',
              value: 'docs.sillytavern.app',
              iconColor: Color(0xFF8FD0BE),
              onTap: null,
            ),
            Hairline(indent: 56),
            SettingRow(
              icon: Icons.privacy_tip_outlined,
              title: '隐私说明',
              value: '数据不出设备',
              iconColor: Color(0xFFA9A0E8),
              onTap: null,
            ),
            Hairline(indent: 56),
            SettingRow(
              icon: Icons.gavel_rounded,
              title: '开源许可',
              value: 'AGPL-3.0',
              iconColor: Color(0xFFEE9AA8),
              onTap: null,
            ),
          ],
        ),
        SettingsGroup(
          title: '实验室',
          footnote: '这些功能仍在打磨，可能影响稳定性。默认关闭。',
          children: const [
            SwitchLine(
              title: '工具调用',
              subtitle: '允许模型调用搜索、绘图等工具',
              value: false,
            ),
            Hairline(indent: 14),
            SettingRow(
              icon: Icons.build_circle_outlined,
              title: '已注册工具',
              value: '3 个',
              iconColor: Color(0xFFF0B36A),
              onTap: null,
            ),
            Hairline(indent: 56),
            SwitchLine(
              title: '实验性宏引擎',
              subtitle: '支持嵌套与稳定求值顺序',
              value: true,
            ),
            Hairline(indent: 14),
            SettingRow(
              icon: Icons.account_tree_outlined,
              title: '推理解析器',
              value: '自动',
              iconColor: Color(0xFFA9A0E8),
              onTap: null,
            ),
            Hairline(indent: 56),
            SettingRow(
              icon: Icons.extension_outlined,
              title: '插件管理',
              value: '即将推出',
              iconColor: Color(0xFF8FD0BE),
              onTap: null,
            ),
          ],
        ),
        SettingsGroup(
          title: '调试',
          children: const [
            SettingRow(
              icon: Icons.code_rounded,
              title: '查看原始 Prompt',
              value: '最近一次',
              iconColor: Color(0xFFF0B36A),
              onTap: null,
            ),
            Hairline(indent: 56),
            SettingRow(
              icon: Icons.receipt_long_outlined,
              title: '事件日志',
              value: '104 类事件',
              iconColor: Color(0xFF8FD0BE),
              onTap: null,
            ),
            Hairline(indent: 56),
            SettingRow(
              icon: Icons.folder_open_rounded,
              title: '数据目录',
              value: '/Documents/Tavern',
              iconColor: Color(0xFFA9A0E8),
              onTap: null,
            ),
          ],
        ),
        const SizedBox(height: 22),
        Center(
          child: Text(
            '为长期陪伴而设计 · Made with care',
            style: appText(10, FontWeight.w400, p.textTertiary),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '角色与对话均为演示数据',
            style: appText(9.5, FontWeight.w400, p.textTertiary),
          ),
        ),
      ],
    );
  }
}
