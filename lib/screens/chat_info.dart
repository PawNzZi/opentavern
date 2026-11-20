import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/prompt.dart';
import '../core/store.dart';
import '../data/demo.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/routes.dart';
import '../design/theme.dart';
import 'editors.dart';
import 'lore.dart';
import 'search.dart';
import 'prompt_preview.dart';
import 'system_prompt.dart';
import 'stats.dart';
import '../design/toast.dart';

class ChatInfoSheet extends StatelessWidget {
  const ChatInfoSheet({
    super.key,
    required this.session,
    required this.character,
    this.onSummarize,
  });

  final ChatSession session;
  final DemoCharacter character;
  final Future<void> Function()? onSummarize;

  Future<void> _export(BuildContext context) async {
    final data = AppStore.instance.exportChatJsonl(session);
    final name = '${session.characterName}-chat.jsonl'.replaceAll('/', '_');
    final uri = await FilePickerPlatform.instance.saveFile(
      fileName: name,
      bytes: Uint8List.fromList(utf8.encode(data)),
      mimeType: 'application/jsonl',
      dialogTitle: '导出聊天 JSONL',
    );
    if (!context.mounted) return;
    showTavernToast(context, uri == null ? '已取消导出' : '聊天已导出');
  }

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

  Future<void> _clearChat(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空聊天'),
        content: const Text('删除本会话的全部消息，角色与设定保留。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('清空')),
        ],
      ),
    );
    if (ok != true) return;
    session.messages.clear();
    session.summary = '';
    session.summaryUpTo = 0;
    await AppStore.instance.saveSessions();
    if (context.mounted) showTavernToast(context, '聊天已清空');
  }

  Future<void> _deleteChat(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除聊天'),
        content: const Text('删除后不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    await AppStore.instance.deleteSession(session.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final c = character;
    final settings = AppStore.instance.settings;
    final messageCount = session.messages.length;
    final charCount = session.messages.fold<int>(0, (n, m) => n + m.text.length);
    Lorebook? linkedBook;
    for (final book in AppStore.instance.lorebooks) {
      if (book.name == character.lorebook) linkedBook = book;
    }
    final created = session.messages.isEmpty
        ? null
        : DateTime.fromMillisecondsSinceEpoch(session.messages.first.createdAt);
    String createdText() => created == null
        ? '暂无消息'
        : '${created.year}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')} ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
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
                onTap: () => _export(context),
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
                value: settings.authorNote.trim().isEmpty ? '跟随全局' : '已设置',
                iconColor: p.rose,
                onTap: () => openGlassPage(context, const AuthorNoteSheet()),
              ),
              const Hairline(indent: 56),
              SettingRow(
                icon: Icons.auto_awesome_rounded,
                title: '记忆与总结',
                value: session.summary.isEmpty ? '未生成' : '已生成',
                iconColor: p.violet,
                onTap: () async {
                  if (onSummarize == null) {
                    showTavernToast(context, session.summary);
                    return;
                  }
                  showTavernToast(context, '正在生成摘要…');
                  await onSummarize!();
                  if (context.mounted) {
                    showTavernToast(
                      context,
                      session.summary.isEmpty ? '摘要生成失败' : '摘要已更新',
                    );
                  }
                },
              ),
              const Hairline(indent: 56),
              SettingRow(
                icon: Icons.auto_stories_rounded,
                title: '聊天世界书',
                value: c.lorebook,
                iconColor: p.sage,
                onTap: () {
                  if (linkedBook == null) {
                    showTavernToast(context, '未找到关联世界书');
                    return;
                  }
                  openGlassPage(
                    context,
                    LorebookPage(book: linkedBook!),
                  );
                },
              ),
              const Hairline(indent: 56),
              SettingRow(
                icon: Icons.face_rounded,
                title: '当前人格',
                value: settings.personaName.trim().isEmpty ? '未设置' : settings.personaName,
                iconColor: p.amber,
                onTap: () => showTavernToast(context, '人格在「交互」里修改'),
              ),
            ],
          ),
          SettingsGroup(
            title: 'Prompt',
            children: [
              SettingRow(
                icon: Icons.code_rounded,
                title: 'System Prompt',
                value: '查看',
                iconColor: p.sage,
                onTap: () => openGlassPage(
                  context,
                  SystemPromptPage(character: character, session: session),
                ),
              ),
              const Hairline(indent: 56),
              SettingRow(
                icon: Icons.account_tree_outlined,
                title: '完整构建顺序',
                value: '顺序与 Token',
                iconColor: p.violet,
                onTap: () => openGlassPage(context, const PromptPreviewPage()),
              ),
            ],
          ),
          SettingsGroup(
            title: '数据',
            children: [
              SettingRow(
                icon: Icons.analytics_outlined,
                title: '聊天统计',
                value: '$messageCount 条 · $charCount 字',
                iconColor: p.sage,
                onTap: () => openGlassPage(context, const StatsPage()),
              ),
              const Hairline(indent: 56),
              SettingRow(
                icon: Icons.backup_outlined,
                title: '备份',
                value: '手动导出',
                iconColor: p.violet,
                onTap: () => showTavernToast(context, '请在「数据与备份」里导出'),
              ),
              const Hairline(indent: 56),
              SettingRow(
                icon: Icons.schedule_rounded,
                title: '创建时间',
                value: createdText(),
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
                onTap: () => _clearChat(context),
              ),
              const Hairline(indent: 56),
              SettingRow(
                icon: Icons.delete_forever_rounded,
                title: '删除聊天',
                value: '不可撤销',
                iconColor: p.danger,
                onTap: () => _deleteChat(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
