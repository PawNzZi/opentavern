import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/store.dart';
import '../data/demo.dart';
import '../design/glass.dart';
import '../design/routes.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';
import '../design/toast.dart';
import 'editors.dart';
import 'lore.dart';
import 'search.dart';
import 'prompt_preview.dart';
import 'system_prompt.dart';
import 'stats.dart';

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

  Future<void> _backup(BuildContext context) async {
    final bytes = Uint8List.fromList(
      utf8.encode(AppStore.instance.exportBackup()),
    );
    final uri = await FilePickerPlatform.instance.saveFile(
      fileName: 'opentavern-backup.json',
      bytes: bytes,
      mimeType: 'application/json',
      dialogTitle: '导出完整备份',
    );
    if (!context.mounted) return;
    showTavernToast(context, uri == null ? '已取消备份' : '备份已导出');
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
    if (!context.mounted) return;
    // 聊天本身已经被删除，返回列表而不是停在一个失效的会话上。
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _branch(BuildContext context, {bool checkpoint = false}) async {
    if (session.messages.isEmpty) {
      showTavernToast(context, '当前聊天还没有可分支的消息');
      return;
    }
    final branch = AppStore.instance.branchSession(
      session,
      throughIndex: session.messages.length - 1,
      title: checkpoint ? '${session.title} · 检查点' : null,
    );
    showTavernToast(
      context,
      checkpoint ? '已创建检查点：${branch.title}' : '已创建分支：${branch.title}',
    );
  }

  void _openWorldBook(BuildContext context, Lorebook? linkedBook) {
    if (linkedBook == null) {
      openGlassPage(context, const LoreScreen());
      return;
    }
    openGlassPage(context, LorebookPage(book: linkedBook));
  }

  void _openMemory(BuildContext context) {
    openGlassPage(
      context,
      _SessionMemoryPage(session: session, onGenerate: onSummarize),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Chat info reads mutable store state (persona, world books, summaries,
    // message counts) so it has to follow AppStore notifications.
    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) => _content(context),
    );
  }

  Widget _content(BuildContext context) {
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
    return DetailPage(
      eyebrow: 'CHAT INFO',
      title: '聊天信息',
      subtitle: '${c.name} · ${session.title}',
      children: [
        ActionGrid(
          items: [
            ActionSpec(
              icon: Icons.call_split_rounded,
              label: '分支',
              color: p.amber,
              onTap: () => _branch(context),
            ),
            ActionSpec(
              icon: Icons.bookmark_add_outlined,
              label: '检查点',
              color: p.sage,
              onTap: () => _branch(context, checkpoint: true),
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
              onTap: () => openGlassPage(context, SearchPage(sessionId: session.id)),
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
              subtitle: session.summary.isEmpty ? null : session.summary,
              value: session.summary.isEmpty ? '未生成' : '已生成',
              iconColor: p.violet,
              onTap: () => _openMemory(context),
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.auto_stories_rounded,
              title: '聊天世界书',
              value: c.lorebook,
              iconColor: p.sage,
              onTap: () => _openWorldBook(context, linkedBook),
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.face_rounded,
              title: '当前人格',
              value: settings.personaName.trim().isEmpty
                  ? '未设置'
                  : settings.personaName,
              iconColor: p.amber,
              onTap: () => openGlassPage(context, const PersonaEditorSheet()),
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
              onTap: () => openGlassPage(context, StatsPage(sessionId: session.id)),
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.backup_outlined,
              title: '备份',
              value: '导出完整备份',
              iconColor: p.violet,
              onTap: () => _backup(context),
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
    );
  }
}

/// 单个会话的“记忆与总结”编辑器：真正修改 session.summary 并落盘。
class _SessionMemoryPage extends StatefulWidget {
  const _SessionMemoryPage({required this.session, this.onGenerate});

  final ChatSession session;
  final Future<void> Function()? onGenerate;

  @override
  State<_SessionMemoryPage> createState() => _SessionMemoryPageState();
}

class _SessionMemoryPageState extends State<_SessionMemoryPage> {
  late final TextEditingController _summary = TextEditingController(
    text: widget.session.summary,
  );
  bool _generating = false;

  @override
  void dispose() {
    _summary.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final generate = widget.onGenerate;
    if (generate == null) {
      showTavernToast(context, '请从聊天页进入，才能调用模型生成摘要');
      return;
    }
    if (_generating) return;
    setState(() => _generating = true);
    showTavernToast(context, '正在生成摘要…');
    await generate();
    if (!mounted) return;
    setState(() {
      _generating = false;
      _summary.text = widget.session.summary;
    });
    showTavernToast(
      context,
      widget.session.summary.isEmpty ? '摘要生成失败或聊天为空' : '摘要已更新',
    );
  }

  Future<void> _save() async {
    widget.session.summary = _summary.text.trim();
    widget.session.summaryUpTo = widget.session.messages.length;
    await AppStore.instance.saveSessions();
    if (!mounted) return;
    showTavernToast(context, '记忆已保存');
    Navigator.of(context).maybePop();
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空摘要'),
        content: const Text('只删除本会话的摘要，聊天消息会保留。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('清空')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    widget.session.summary = '';
    widget.session.summaryUpTo = 0;
    _summary.clear();
    await AppStore.instance.saveSessions();
    if (!mounted) return;
    setState(() {});
    showTavernToast(context, '摘要已清空');
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DetailPage(
      eyebrow: 'MEMORY',
      title: '记忆与总结',
      subtitle:
          '${widget.session.title} · ${widget.session.messages.length} 条消息',
      footer: GlassPrimaryButton(
        label: '保存记忆',
        icon: Icons.check_rounded,
        onTap: _save,
      ),
      children: [
        const SizedBox(height: 12),
        HintCard(
          text: widget.session.summary.isEmpty
              ? '还没有摘要。摘要会压缩早期剧情并注入之后的 Prompt。'
              : '摘要会作为上下文注入之后的每次请求；可以手动改写。',
          icon: Icons.psychology_alt_outlined,
          color: p.violet,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            GlassPill(
              label: _generating ? '生成中…' : 'AI 生成摘要',
              icon: Icons.auto_awesome_rounded,
              height: 32,
              onTap: _generating ? null : _generate,
            ),
            const SizedBox(width: 8),
            GlassPill(
              label: '清空摘要',
              icon: Icons.delete_outline_rounded,
              height: 32,
              onTap: _clear,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Glass(
          radius: 18,
          blur: 18,
          shadow: false,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '摘要内容',
                style: appText(10.5, FontWeight.w500, p.textTertiary),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _summary,
                maxLines: 8,
                minLines: 4,
                style: appText(14, FontWeight.w400, p.textPrimary, height: 1.5),
                cursorColor: p.amber,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: '还没有摘要',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
