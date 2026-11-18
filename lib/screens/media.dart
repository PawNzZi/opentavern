import 'package:flutter/material.dart';

import '../data/demo.dart';
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
      eyebrow: 'VOICE & VISION',
      title: '语音、图像与翻译',
      subtitle: '让角色开口、让场景可见、让语言不再是障碍。',
      children: [
        SettingsGroup(
          title: '语音合成（TTS）',
          children: [
            SettingRow(
              icon: Icons.record_voice_over_rounded,
              title: '服务商',
              value: 'ElevenLabs',
              iconColor: p.amber,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            const SwitchLine(
              title: '自动朗读新消息',
              subtitle: '只朗读角色消息，不朗读动作描写',
              value: true,
            ),
            const Hairline(indent: 56),
            const SliderLine(
              title: '语速',
              value: 1,
              min: .5,
              max: 2,
              display: '1.0×',
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.volume_up_rounded,
              title: '试听当前音色',
              value: 'Aurora',
              iconColor: p.sage,
              onTap: () {},
            ),
          ],
        ),
        SettingsGroup(
          title: '角色音色',
          footnote: '按角色映射声音；未映射的角色使用「默认音色」。',
          trailing: Text(
            '4 个',
            style: appText(11, FontWeight.w400, p.textTertiary),
          ),
          children: [
            for (var i = 0; i < demoVoices.length; i++) ...[
              _VoiceRow(voice: demoVoices[i]),
              if (i != demoVoices.length - 1) const Hairline(indent: 56),
            ],
          ],
        ),
        SettingsGroup(
          title: '语音输入（STT）',
          children: [
            SettingRow(
              icon: Icons.mic_rounded,
              title: '识别方式',
              value: 'Whisper（本地）',
              iconColor: p.violet,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.language_rounded,
              title: '识别语言',
              value: '中文 / 自动',
              iconColor: p.rose,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            const SwitchLine(
              title: '按住说话',
              subtitle: '松开后自动发送',
              value: true,
            ),
          ],
        ),
        SettingsGroup(
          title: '图像生成',
          children: [
            SettingRow(
              icon: Icons.brush_rounded,
              title: '服务商',
              value: 'ComfyUI（本地）',
              iconColor: p.amber,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.memory_rounded,
              title: '模型',
              value: 'Flux Dev · FP8',
              iconColor: p.violet,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.aspect_ratio_rounded,
              title: '尺寸',
              value: '1024 × 1536',
              iconColor: p.sage,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            const SliderLine(
              title: '采样步数',
              value: 28,
              min: 8,
              max: 60,
              divisions: 52,
              display: '28',
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.text_snippet_outlined,
              title: '提示词模板',
              value: '角色 + 场景 + 光线',
              iconColor: p.rose,
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 138,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: demoGallery.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final item = demoGallery[i];
              return ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: 98,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: item.colors,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: Text(
                          item.size,
                          style: appText(
                            8.5,
                            FontWeight.w500,
                            Colors.white.withValues(alpha: .8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SettingsGroup(
          title: '表情立绘',
          children: [
            SettingRow(
              icon: Icons.face_retouching_natural_rounded,
              title: '情绪分类',
              value: '本地 ONNX',
              iconColor: p.sage,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.view_sidebar_rounded,
              title: '显示方式',
              value: '头像旁',
              iconColor: p.violet,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.shield_outlined,
              title: '分类失败时',
              value: '使用 neutral',
              iconColor: p.rose,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.folder_special_rounded,
              title: '角色表情目录',
              value: '3 个角色已配置',
              iconColor: p.amber,
              onTap: () {},
            ),
          ],
        ),
        SettingsGroup(
          title: '翻译',
          children: [
            SettingRow(
              icon: Icons.translate_rounded,
              title: '服务商',
              value: 'Google',
              iconColor: p.amber,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.language_rounded,
              title: '目标语言',
              value: '中文（简体）',
              iconColor: p.sage,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            const SwitchLine(
              title: '自动翻译输入',
              subtitle: '发送前把中文转成角色语言',
              value: false,
            ),
            const Hairline(indent: 56),
            const SwitchLine(
              title: '自动翻译回复',
              subtitle: '显示译文，原文保留在气泡下方',
              value: true,
            ),
          ],
        ),
        const SizedBox(height: 18),
        const HintCard(
          text: '语音、图像和翻译都是可选能力：关闭时不加载模型、不产生费用。首次使用本地模型会下载到设备。',
          color: Color(0xFF8FD0BE),
        ),
      ],
    );
  }
}

class _VoiceRow extends StatelessWidget {
  const _VoiceRow({required this.voice});

  final DemoVoice voice;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Opacity(
      opacity: voice.enabled ? 1 : .45,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                color: p.amber.withValues(alpha: .14),
              ),
              child: Icon(
                Icons.graphic_eq_rounded,
                size: 16,
                color: p.amber,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voice.character,
                    style: appText(13, FontWeight.w500, p.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${voice.provider} · ${voice.voice}',
                    style: appText(9.5, FontWeight.w400, p.textTertiary),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.play_circle_outline_rounded,
              size: 19,
              color: p.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
