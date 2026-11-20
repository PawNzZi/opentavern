import 'package:flutter/material.dart';

import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';

class MediaPage extends StatelessWidget {
  const MediaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DetailPage(
      eyebrow: 'MEDIA',
      title: '语音与图像',
      subtitle: '当前版本只支持聊天里的图片附件。',
      children: [
        const SizedBox(height: 18),
        SettingsGroup(
          title: '语音',
          children: [
            const SettingRow(
              icon: Icons.record_voice_over_outlined,
              title: 'TTS 朗读',
              value: '未接入',
              iconColor: Color(0xFFD98E5F),
            ),
            const Hairline(indent: 56),
            const SettingRow(
              icon: Icons.mic_none_rounded,
              title: '语音输入 / 转写',
              value: '未接入',
              iconColor: Color(0xFF7FA893),
            ),
          ],
        ),
        SettingsGroup(
          title: '图像',
          children: [
            const SettingRow(
              icon: Icons.image_outlined,
              title: '聊天图片附件',
              value: '已支持',
              iconColor: Color(0xFFD98E5F),
            ),
            const Hairline(indent: 56),
            const SettingRow(
              icon: Icons.auto_awesome_outlined,
              title: 'AI 绘图',
              value: '未接入',
              iconColor: Color(0xFFA9A0E8),
            ),
            const Hairline(indent: 56),
            const SettingRow(
              icon: Icons.face_retouching_natural_outlined,
              title: '角色表情',
              value: '未接入',
              iconColor: Color(0xFFEE9AA8),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '这些功能需要额外的服务或本地模型，当前 IPA 不包含相关依赖；'
          '图片附件会随聊天一起保存，并通过多模态接口发送。',
          style: appText(11.5, FontWeight.w400, p.textTertiary, height: 1.6),
        ),
      ],
    );
  }
}
