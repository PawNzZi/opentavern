import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/store.dart';
import '../data/demo.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/routes.dart';
import '../design/theme.dart';
import 'editors.dart';

class InteractionPage extends StatelessWidget {
  const InteractionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final quick = AppStore.instance.activeQuickSet;
    return DetailPage(
      eyebrow: 'IDENTITY & COMMANDS',
      title: '交互',
      subtitle: '你是谁、怎么快捷操作、有哪些命令。',
      children: [
        SettingsGroup(
          title: '人格（Persona）',
          footnote: '人格决定 {{user}} 的名字、头像与描述，也可以绑定独立的世界书。',
          trailing: Text(
            '3 个',
            style: appText(11, FontWeight.w400, p.textTertiary),
          ),
          children: [
            for (var i = 0; i < demoPersonas.length; i++) ...[
              _PersonaRow(
                persona: demoPersonas[i],
                onTap: () => openGlassPage(
                  context,
                  PersonaEditorSheet(persona: demoPersonas[i]),
                ),
              ),
              if (i != demoPersonas.length - 1) const Hairline(indent: 66),
            ],
            const Hairline(indent: 66),
            SettingRow(
              icon: Icons.add_rounded,
              title: '新建人格',
              value: '头像 + 描述',
              iconColor: p.amber,
              onTap: () => openGlassPage(
                context,
                const PersonaEditorSheet(),
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: '人格描述注入',
          children: const [
            SegmentLine(
              title: '位置',
              options: ['提示词内', '作者笔记上', '深度'],
              index: 0,
            ),
            StepperRow(
              title: '注入深度',
              subtitle: '仅「深度」模式生效',
              value: '4',
            ),
            SwitchLine(
              title: '切换人格时提示',
              subtitle: '避免误用其他人格说话',
              value: true,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Glass(
          radius: 24,
          blur: 24,
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '快捷回复',
                    style: appText(15, FontWeight.w600, p.textPrimary),
                  ),
                  const SizedBox(width: 7),
                  TagBadge(quick?.name ?? '快捷回复'),
                  const Spacer(),
                  Text(
                    '${quick?.replies.length ?? 0} 个按钮',
                    style: appText(10.5, FontWeight.w400, p.textTertiary),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final reply in quick?.replies ?? const <QuickReply>[])
                    GlassPill(label: reply.label, height: 32),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  GlassPill(
                    label: '编辑按钮',
                    icon: Icons.edit_outlined,
                    height: 32,
                    onTap: () => openGlassPage(
                      context,
                      QuickReplyEditorSheet(quickSet: quick),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const GlassPill(
                    label: '管理集合',
                    icon: Icons.layers_outlined,
                    height: 32,
                  ),
                  const Spacer(),
                  Text(
                    '显示在输入框上方',
                    style: appText(9.5, FontWeight.w400, p.textTertiary),
                  ),
                ],
              ),
            ],
          ),
        ),
        SettingsGroup(
          title: '快捷回复集合',
          children: [
            for (var i = 0; i < demoQuickSets.length; i++) ...[
              _QuickSetRow(set: demoQuickSets[i]),
              if (i != demoQuickSets.length - 1) const Hairline(indent: 56),
            ],
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.add_rounded,
              title: '新建集合',
              value: '从空白 / 模板',
              iconColor: p.amber,
              onTap: () {},
            ),
          ],
        ),
        SettingsGroup(
          title: '命令与脚本',
          children: [
            SettingRow(
              icon: Icons.terminal_rounded,
              title: '斜杠命令',
              value: '150+ 个',
              iconColor: p.amber,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.data_object_rounded,
              title: '宏浏览器',
              value: '120+ 个',
              iconColor: p.violet,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.code_rounded,
              title: 'STscript 脚本',
              value: '3 个',
              iconColor: p.sage,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.bug_report_outlined,
              title: '调试控制台',
              value: '事件与命令',
              iconColor: p.rose,
              onTap: () {},
            ),
          ],
        ),
        SettingsGroup(
          title: '作者笔记默认值',
          children: [
            const FieldBlock(
              label: '默认内容',
              value: '保持叙事节奏，多描写环境与身体语言，避免替用户做决定。',
              multiline: true,
            ),
            const SizedBox(height: 8),
            const StepperRow(
              title: '插入间隔',
              subtitle: '每 N 条消息注入一次',
              value: '3 条',
            ),
            const SegmentLine(
              title: '位置',
              options: ['作者笔记上', '作者笔记下', '深度'],
              index: 2,
            ),
            const StepperRow(
              title: '深度',
              value: '4',
            ),
          ],
        ),
        const SizedBox(height: 18),
        const HintCard(
          text: '这些默认值只影响新聊天。单个聊天里的作者笔记、人格锁定和快捷回复，可以在聊天信息里单独修改。',
        ),
      ],
    );
  }
}

class _PersonaRow extends StatelessWidget {
  const _PersonaRow({required this.persona, this.onTap});

  final DemoPersona persona;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Pressable(
      onTap: onTap,
      child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: Portrait(
              initial: persona.initial,
              colors: persona.colors,
              radius: 13,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      persona.name,
                      style: appText(13.5, FontWeight.w500, p.textPrimary),
                    ),
                    if (persona.isDefault) ...[
                      const SizedBox(width: 6),
                      const TagBadge('默认'),
                    ],
                    if (persona.lockedTo != null) ...[
                      const SizedBox(width: 6),
                      TagBadge(
                        '锁定 ${persona.lockedTo}',
                        color: p.violet,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  persona.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appText(10, FontWeight.w400, p.textTertiary),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 17,
            color: p.textTertiary,
          ),
        ],
      ),
      ),
    );
  }
}

class _QuickSetRow extends StatelessWidget {
  const _QuickSetRow({required this.set});

  final DemoQuickSet set;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: (set.active ? p.amber : p.textTertiary).withValues(
                alpha: .14,
              ),
            ),
            child: Icon(
              Icons.bolt_rounded,
              size: 17,
              color: set.active ? p.amber : p.textTertiary,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      set.name,
                      style: appText(13, FontWeight.w500, p.textPrimary),
                    ),
                    if (set.active) ...[
                      const SizedBox(width: 6),
                      const TagBadge('启用中'),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  set.description,
                  style: appText(9.5, FontWeight.w400, p.textTertiary),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 17,
            color: p.textTertiary,
          ),
        ],
      ),
    );
  }
}
