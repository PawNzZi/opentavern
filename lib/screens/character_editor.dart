import 'package:flutter/material.dart';

import '../data/demo.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';

class CharacterEditorPage extends StatelessWidget {
  const CharacterEditorPage({super.key, this.character});

  final DemoCharacter? character;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final c = character ?? demoCharacters.first;
    return DetailPage(
      eyebrow: 'CHARACTER EDITOR',
      title: '编辑角色',
      subtitle: '所有字段都可以改，保存后立即生效。',
      footer: const GlassPrimaryButton(
        label: '保存角色',
        icon: Icons.check_rounded,
      ),
      children: [
        const SizedBox(height: 16),
        Glass(
          radius: 24,
          blur: 24,
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Portrait(
                  initial: c.initial,
                  colors: c.colors,
                  radius: 18,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '角色立绘',
                      style: appText(14, FontWeight.w500, p.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '建议 512×768，PNG 会同时写入 V2/V3 元数据',
                      style: appText(9.5, FontWeight.w400, p.textTertiary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: const [
                        GlassPill(label: '更换', height: 30),
                        SizedBox(width: 7),
                        GlassPill(label: '裁剪', height: 30),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        FieldBlock(label: '名字', value: c.name),
        FieldBlock(label: '作者', value: 'Nyx'),
        FieldBlock(label: '版本', value: '1.2'),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 12, 2, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 6),
                child: Text(
                  '标签',
                  style: appText(10.5, FontWeight.w500, p.textTertiary),
                ),
              ),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final t in c.tags) GlassPill(label: t, height: 30),
                  const GlassPill(
                    label: '添加',
                    icon: Icons.add_rounded,
                    height: 30,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SectionLabel('人设'),
        FieldBlock(label: '描述（Description）', value: c.description, multiline: true),
        const FieldBlock(
          label: '性格（Personality）',
          value: '冷静、克制、观察力强；说话慢，但很少说废话。',
          multiline: true,
        ),
        FieldBlock(label: '场景（Scenario）', value: c.greeting, multiline: true),
        const SectionLabel('开场'),
        FieldBlock(label: '开场白（First message）', value: c.greeting, multiline: true),
        Glass(
          radius: 18,
          blur: 18,
          shadow: false,
          child: SettingRow(
            icon: Icons.add_comment_outlined,
            title: '备选开场白',
            value: '2 条',
            iconColor: p.amber,
            onTap: () {},
          ),
        ),
        const SectionLabel('示例对话'),
        const FieldBlock(
          label: 'Example messages',
          value:
              '<START>\n{{user}}: 今晚的星象怎么样？\n{{char}}: *她抬起眼，指尖停在星图上。* 不太好。你带来了一个变量。\n<START>\n{{user}}: 你相信预言吗？\n{{char}}: 我相信星图，不相信解读它的人。',
          multiline: true,
        ),
        const SectionLabel('高级'),
        const FieldBlock(
          label: '主提示词覆盖',
          value: 'Write {{char}}\'s next reply in a fictional chat...',
          multiline: true,
        ),
        const FieldBlock(
          label: 'Post-History Instructions',
          value: '保持角色口吻，不要替 {{user}} 行动。',
          multiline: true,
        ),
        const FieldBlock(
          label: '@Depth 注入',
          value: '她记得王都每一场雨。',
          multiline: true,
        ),
        Glass(
          radius: 22,
          blur: 22,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: const [
              StepperRow(
                title: '注入深度',
                value: '4',
              ),
              Hairline(indent: 14),
              SegmentLine(
                title: '注入角色',
                options: ['系统', '用户', '角色'],
                index: 0,
              ),
              Hairline(indent: 14),
              SwitchLine(
                title: '内嵌世界书',
                subtitle: '把角色卡中的 Character Book 保存为独立世界书',
                value: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '角色专属提示词会覆盖全局预设；留空则跟随预设。',
          style: appText(10.5, FontWeight.w400, p.textTertiary, height: 1.45),
        ),
        SettingsGroup(
          title: '角色正则',
          children: const [
            SettingRow(
              icon: Icons.find_replace_rounded,
              title: '名字修正',
              value: '2 条脚本',
              iconColor: Color(0xFFA9A0E8),
              onTap: null,
            ),
            Hairline(indent: 56),
            SettingRow(
              icon: Icons.add_rounded,
              title: '添加角色正则',
              value: '仅对当前角色生效',
              iconColor: Color(0xFFF0B36A),
              onTap: null,
            ),
          ],
        ),
        const SizedBox(height: 18),
        const HintCard(
          text: '编辑角色卡不会自动改写历史聊天。若要让新设定立即生效，请开始一个新对话，或在聊天信息里更新聊天级覆盖。',
        ),
      ],
    );
  }
}
