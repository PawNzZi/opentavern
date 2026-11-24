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
      title: '关于',
      subtitle: '本地优先的单机角色聊天客户端。',
      children: [
        const SizedBox(height: 18),
        SettingsGroup(
          title: '应用',
          children: [
            const SettingRow(
              icon: Icons.info_outline_rounded,
              title: '版本',
              value: '1.0.0',
              iconColor: Color(0xFFD98E5F),
            ),
            const Hairline(indent: 56),
            const SettingRow(
              icon: Icons.storage_rounded,
              title: '数据目录',
              value: '/Documents/tavern',
              iconColor: Color(0xFF7FA893),
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.cloud_off_rounded,
              title: '网络',
              value: '只连接你配置的 API',
              iconColor: p.violet,
            ),
          ],
        ),
        SettingsGroup(
          title: '兼容性',
          children: [
            const SettingRow(
              icon: Icons.style_outlined,
              title: '角色卡',
              value: 'PNG / JSON V2 V3',
              iconColor: Color(0xFFD98E5F),
            ),
            const Hairline(indent: 56),
            const SettingRow(
              icon: Icons.menu_book_outlined,
              title: '世界书',
              value: 'JSON / ZIP',
              iconColor: Color(0xFF7FA893),
            ),
            const Hairline(indent: 56),
            const SettingRow(
              icon: Icons.bolt_rounded,
              title: 'API',
              value: 'OpenAI 兼容 / Claude / Gemini 等',
              iconColor: Color(0xFFA9A0E8),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          '这是一个单机应用：没有账号、没有云同步，所有角色、聊天和设置都保存在本机。'
          '删除 App 会同时删除这些数据，请定期在「数据与备份」里导出。',
          style: appText(11.5, FontWeight.w400, p.textTertiary, height: 1.6),
        ),
      ],
    );
  }
}
