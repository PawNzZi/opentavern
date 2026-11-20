import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/store.dart';
import '../design/glass.dart';
import '../design/routes.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';
import '../design/toast.dart';
import 'editors.dart';

class InteractionPage extends StatelessWidget {
  const InteractionPage({super.key});

  /// 创建一个真正的空白集合（不伪造任何按钮），落盘后立刻打开编辑器。
  Future<void> _createSet(BuildContext context) async {
    final store = AppStore.instance;
    final set = QuickReplySet(
      id: 'qr-${DateTime.now().microsecondsSinceEpoch}',
      name: '新集合 ${store.quickReplySets.length + 1}',
      replies: [],
    );
    store.quickReplySets.add(set);
    store.activeQuickSetId = set.id;
    await store.saveQuickReplies();
    if (!context.mounted) return;
    await openGlassPage(context, QuickReplyEditorSheet(quickSet: set));
    if (!context.mounted) return;
    // 取消编辑后不留下空集合。
    if (set.replies.isEmpty && store.quickReplySets.contains(set)) {
      store.quickReplySets.remove(set);
      if (store.activeQuickSetId == set.id) {
        store.activeQuickSetId =
            store.quickReplySets.isEmpty ? '' : store.quickReplySets.first.id;
      }
      await store.saveQuickReplies();
    }
  }

  Future<void> _activate(BuildContext context, QuickReplySet set) async {
    final store = AppStore.instance;
    if (store.activeQuickSetId == set.id) return;
    store.activeQuickSetId = set.id;
    await store.saveQuickReplies();
    if (context.mounted) showTavernToast(context, '已切换到「${set.name}」');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) => _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final p = AppPalette.of(context);
    final store = AppStore.instance;
    final settings = store.settings;
    final quick = store.activeQuickSet;
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
            personaName.isEmpty ? '未设置' : '已设置',
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
                      GlassPill(
                        label: reply.label,
                        height: 32,
                        onTap: () => openGlassPage(
                          context,
                          QuickReplyEditorSheet(quickSet: quick),
                        ),
                      ),
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
                        await _createSet(context);
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
                    '聊天中点击会填入输入框',
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
            for (var i = 0; i < store.quickReplySets.length; i++) ...[
              SettingRow(
                icon: Icons.bolt_rounded,
                title: store.quickReplySets[i].name,
                subtitle: '${store.quickReplySets[i].replies.length} 个按钮',
                value: store.quickReplySets[i].id == store.activeQuickSetId
                    ? '当前'
                    : '',
                iconColor: p.amber,
                onTap: () => _activate(context, store.quickReplySets[i]),
                trailing: GlassCircleButton(
                  icon: Icons.edit_outlined,
                  size: 30,
                  iconSize: 14,
                  blur: 0,
                  onTap: () => openGlassPage(
                    context,
                    QuickReplyEditorSheet(
                      quickSet: store.quickReplySets[i],
                    ),
                  ),
                ),
              ),
              if (i != store.quickReplySets.length - 1)
                const Hairline(indent: 56),
            ],
            if (store.quickReplySets.isNotEmpty)
              const Hairline(indent: 56),
            SettingRow(
              icon: Icons.add_rounded,
              title: '新建集合',
              value: '空白集合',
              iconColor: p.amber,
              onTap: () => _createSet(context),
            ),
          ],
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
