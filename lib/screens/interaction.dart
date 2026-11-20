import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/store.dart';
import '../design/glass.dart';
import '../design/routes.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';
import 'editors.dart';

class InteractionPage extends StatelessWidget {
  const InteractionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final settings = AppStore.instance.settings;
    final quick = AppStore.instance.activeQuickSet;
    final personaName = settings.personaName.trim();
    final personaDesc = settings.personaDescription.trim();
    final note = settings.authorNote.trim();
    return DetailPage(
      eyebrow: 'IDENTITY & COMMANDS',
      title: '交互',
      subtitle: '你是谁、怎么快捷操作。',
      children: [
        SettingsGroup(
          title: '人格（Persona）',
          footnote: '人格名字与描述会替换 Prompt 中的 {{user}} 相关内容。',
          trailing: Text(
            personaName.isEmpty ? '未设置' : '1 个',
            style: appText(11, FontWeight.w400, p.textTertiary),
          ),
          children: [
            SettingRow(
              icon: Icons.person_outline_rounded,
              title: personaName.isEmpty ? '未设置人格' : personaName,
              subtitle: personaDesc.isEmpty ? '点击编辑名字与描述' : personaDesc,
              iconColor: p.amber,
              onTap: () => openGlassPage(
                context,
                const PersonaEditorSheet(),
              ),
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
                  TagBadge(quick?.name ?? '未选择'),
                  const Spacer(),
                  Text(
                    '${quick?.replies.length ?? 0} 个按钮',
                    style: appText(10.5, FontWeight.w400, p.textTertiary),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              if (quick == null || quick.replies.isEmpty)
                Text(
                  '还没有快捷回复集合',
                  style: appText(11.5, FontWeight.w400, p.textTertiary),
                )
              else
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final reply in quick.replies)
                      GlassPill(label: reply.label, height: 32),
                  ],
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  GlassPill(
                    label: quick == null ? '新建集合' : '编辑按钮',
                    icon: Icons.edit_outlined,
                    height: 32,
                    onTap: () async {
                      if (quick == null) {
                        final set = QuickReplySet(
                          id: 'qr-${DateTime.now().microsecondsSinceEpoch}',
                          name: '新集合 1',
                          replies: [
                            QuickReply(
                              id: 'qr-${DateTime.now().microsecondsSinceEpoch}-1',
                              label: '继续',
                              message: '继续',
                            ),
                          ],
                        );
                        AppStore.instance.quickReplySets.add(set);
                        AppStore.instance.activeQuickSetId = set.id;
                        await AppStore.instance.saveQuickReplies();
                        return;
                      }
                      await openGlassPage(
                        context,
                        QuickReplyEditorSheet(quickSet: quick),
                      );
                    },
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
        AnimatedBuilder(
          animation: AppStore.instance,
          builder: (context, _) => SettingsGroup(
            title: '快捷回复集合',
            children: [
              for (var i = 0;
                  i < AppStore.instance.quickReplySets.length;
                  i++) ...[
                SettingRow(
                  icon: Icons.bolt_rounded,
                  title: AppStore.instance.quickReplySets[i].name,
                  subtitle:
                      '${AppStore.instance.quickReplySets[i].replies.length} 个按钮',
                  value: AppStore.instance.quickReplySets[i].id ==
                          AppStore.instance.activeQuickSetId
                      ? '当前'
                      : '',
                  iconColor: p.amber,
                  onTap: () async {
                    AppStore.instance.activeQuickSetId =
                        AppStore.instance.quickReplySets[i].id;
                    await AppStore.instance.saveQuickReplies();
                  },
                  trailing: GlassCircleButton(
                    icon: Icons.edit_outlined,
                    size: 30,
                    iconSize: 14,
                    blur: 0,
                    onTap: () => openGlassPage(
                      context,
                      QuickReplyEditorSheet(
                        quickSet: AppStore.instance.quickReplySets[i],
                      ),
                    ),
                  ),
                ),
                if (i != AppStore.instance.quickReplySets.length - 1)
                  const Hairline(indent: 56),
              ],
              if (AppStore.instance.quickReplySets.isNotEmpty)
                const Hairline(indent: 56),
              SettingRow(
                icon: Icons.add_rounded,
                title: '新建集合',
                value: '空白集合',
                iconColor: p.amber,
                onTap: () async {
                  final set = QuickReplySet(
                    id: 'qr-${DateTime.now().microsecondsSinceEpoch}',
                    name:
                        '新集合 ${AppStore.instance.quickReplySets.length + 1}',
                    replies: [
                      QuickReply(
                        id: 'qr-${DateTime.now().microsecondsSinceEpoch}-1',
                        label: '继续',
                        message: '继续',
                      ),
                    ],
                  );
                  AppStore.instance.quickReplySets.add(set);
                  AppStore.instance.activeQuickSetId = set.id;
                  await AppStore.instance.saveQuickReplies();
                },
              ),
            ],
          ),
        ),
        SettingsGroup(
          title: '作者笔记',
          children: [
            SettingRow(
              icon: Icons.sticky_note_2_outlined,
              title: '默认内容',
              subtitle: note.isEmpty ? '未设置' : note,
              iconColor: p.violet,
              onTap: () => openGlassPage(context, const AuthorNoteSheet()),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const HintCard(
          text: '作者笔记会进入每次请求的 Prompt；人格和快捷回复只保存在本机。',
        ),
      ],
    );
  }
}
