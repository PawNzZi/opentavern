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
import 'search.dart';
import 'stats.dart';
import '../design/toast.dart';

class ChatInfoSheet extends StatelessWidget {
  const ChatInfoSheet({super.key, required this.session, required this.character});

  final ChatSession session;
  final DemoCharacter character;

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: session.title);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名聊天'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '聊天标题'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    session.title = name.trim();
    await AppStore.instance.saveSessions();
    if (context.mounted) showTavernToast(context, '标题已更新');
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final c = character;
    return SheetStage(
      title: '聊天信息',
      subtitle: '${c.name} · ${session.title}',
      heightFactor: .95,
      leading: SizedBox(
        width: 40,
        height: 40,
        child: Portrait(
          initial: c.initial,
          colors: c.colors,
          radius: 12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ActionGrid(
            items: [
              ActionSpec(
                icon: Icons.call_split_rounded,
                label: '分支',
                color: p.amber,
                onTap: () {
                  AppStore.instance.branchSession(
                    session,
                    throughIndex: session.messages.length - 1,
                  );
                  showTavernToast(context, '已创建分支');
                },
              ),
              ActionSpec(
                icon: Icons.bookmark_add_outlined,
                label: '检查点',
                color: p.sage,
                onTap: () {
                  AppStore.instance.branchSession(
                    session,
                    throughIndex: session.messages.length - 1,
                    title: '${session.title} · 检查点',
                  );
                  showTavernToast(context, '已创建检查点');
                },
              ),
              ActionSpec(
                icon: Icons.ios_share_rounded,
                label: '导出',
                color: p.violet,
                onTap: () => showTavernToast(context, '已导出 JSONL'),
              ),
              ActionSpec(
                icon: Icons.search_rounded,
                label: '搜索',
                color: p.rose,
                onTap: () => openGlassPage(context, const SearchPage()),
              ),
            ],
          ),
          SettingsGroup(
            title: '本聊天',
            children: [
              SettingRow(
                icon: Icons.title_rounded,
                title: '聊天标题',
                value: session.title,
                iconColor: p.amber,
                onTap: () => _rename(context),
              ),
              const Hairline(indent: 56),
              SettingRow(
                icon: Icons.sticky_note_2_outlined,
                title: '作者笔记',
                value: '每 3 条 · 深度 4',
                iconColor: p.rose,
                onTap: () => openGlassPage(context, const AuthorNoteSheet()),
              ),
              const Hairline(indent: 56),
              SettingRow(
                icon: Icons.auto_awesome_rounded,
                title: '记忆与总结',
                value: '已总结 12 段',
                iconColor: p.violet,
                onTap: () => showTavernToast(context, '已总结 12 段'),
              ),
              const Hairline(indent: 56),
              SettingRow(
                icon: Icons.auto_stories_rounded,
                title: '聊天世界书',
                value: '未绑定',
                iconColor: p.sage,
                onTap: () => showTavernToast(context, '未绑定聊天世界书'),
              ),
              const Hairline(indent: 56),
              SettingRow(
                icon: Icons.face_rounded,
                title: '锁定人格',
                value: '旅人',
                iconColor: p.amber,
                onTap: () => showTavernToast(context, '已锁定人格：旅人'),
              ),
            ],
          ),
          SettingsGroup(
            title: '数据',
            children: [
              SettingRow(
                icon: Icons.analytics_outlined,
                title: '聊天统计',
                value: '128 条 · 32k 字',
                iconColor: p.sage,
                onTap: () => openGlassPage(context, const StatsPage()),
              ),
              const Hairline(indent: 56),
              SettingRow(
                icon: Icons.backup_outlined,
                title: '备份',
                value: '最近 2 天前 · 12 份',
                iconColor: p.violet,
                onTap: () => showTavernToast(context, '已恢复最近备份'),
              ),
              const Hairline(indent: 56),
              SettingRow(
                icon: Icons.schedule_rounded,
                title: '创建时间',
                value: '2026-11-02 21:14',
                iconColor: p.amber,
                chevron: false,
              ),
            ],
          ),
          SettingsGroup(
            title: '危险操作',
            children: [
              SettingRow(
                icon: Icons.delete_outline_rounded,
                title: '清空聊天',
                value: '保留角色与设定',
                iconColor: p.danger,
                onTap: () => showTavernToast(context, '清空需要二次确认'),
              ),
              const Hairline(indent: 56),
              SettingRow(
                icon: Icons.delete_forever_rounded,
                title: '删除聊天',
                value: '不可撤销',
                iconColor: p.danger,
                onTap: () => showTavernToast(context, '删除需要二次确认'),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
