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
import 'chat.dart';
import 'editors.dart';
import 'lore.dart';
import 'prompt_preview.dart';
import 'search.dart';
import 'stats.dart';
import 'system_prompt.dart';

/// 摘要注入位置的取值顺序，与 [AppSettings.summaryPosition] 一一对应。
const List<String> _summaryPositionKeys = [
  'in_prompt',
  'after_history',
  'at_depth',
];

/// 摘要注入角色的取值顺序，与 [AppSettings.summaryRole] 一一对应。
const List<String> _summaryRoleKeys = ['system', 'user', 'assistant'];

String _summaryPositionLabel(String position) {
  switch (position) {
    case 'after_history':
      return '历史后';
    case 'at_depth':
      return '按深度';
    case 'in_prompt':
    default:
      return '提示词内';
  }
}

String _safeFileName(String value) {
  final cleaned = value
      .replaceAll(RegExp(r'[\\/:*?"<>|\r\n\t]'), '_')
      .trim();
  return cleaned.isEmpty ? 'chat' : cleaned;
}

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

  DemoCharacter _characterFor(ChatSession target) {
    for (final c in AppStore.instance.characters) {
      if (c.name == target.characterName) return c;
    }
    return character;
  }

  /// 打开已经在 store 里的会话（导入结果、父聊天、子分支、主线）。
  Future<void> _openSession(BuildContext context, ChatSession target) {
    return openGlassPage(
      context,
      ChatScreen(character: _characterFor(target), sessionId: target.id),
    );
  }

  Future<void> _exportJsonl(BuildContext context) async {
    final data = AppStore.instance.exportChatJsonl(session);
    final name =
        '${_safeFileName('${session.characterName}-${session.title}')}.jsonl';
    final uri = await FilePickerPlatform.instance.saveFile(
      fileName: name,
      bytes: Uint8List.fromList(utf8.encode(data)),
      mimeType: 'application/jsonl',
      dialogTitle: '导出聊天 JSONL',
    );
    if (!context.mounted) return;
    showTavernToast(context, uri == null ? '已取消导出' : '聊天已导出为 JSONL');
  }

  Future<void> _exportTxt(BuildContext context) async {
    final data = AppStore.instance.exportChatTxt(session);
    final name =
        '${_safeFileName('${session.characterName}-${session.title}')}.txt';
    final uri = await FilePickerPlatform.instance.saveFile(
      fileName: name,
      bytes: Uint8List.fromList(utf8.encode(data)),
      mimeType: 'text/plain',
      dialogTitle: '导出聊天 TXT',
    );
    if (!context.mounted) return;
    showTavernToast(context, uri == null ? '已取消导出' : '聊天已导出为 TXT');
  }

  Future<void> _importChat(BuildContext context) async {
    final file = await FilePickerPlatform.instance.pickFile(
      dialogTitle: '导入聊天（JSONL / TXT）',
      type: FileType.custom,
      allowedExtensions: const ['jsonl', 'txt'],
    );
    if (file == null) return;
    final extension = (file.extension ?? '').toLowerCase();
    if (extension != 'jsonl' && extension != 'txt') {
      if (context.mounted) showTavernToast(context, '只支持 .jsonl 或 .txt 聊天记录');
      return;
    }
    final bytes = await file.readAsBytes();
    if (!context.mounted) return;
    final imported = await AppStore.instance.importChatText(
      character.name,
      utf8.decode(bytes, allowMalformed: true),
      jsonl: extension == 'jsonl',
    );
    if (!context.mounted) return;
    if (imported == null) {
      showTavernToast(context, '没有解析到可导入的消息');
      return;
    }
    showTavernToast(
      context,
      '已导入 ${imported.messages.length} 条消息，正在打开新会话',
    );
    await _openSession(context, imported);
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
    // 分支的 parentId / mainChatId 由 core 负责写入；这里做一次兜底，
    // 让「分支关系」区块在核心尚未补齐时间之前也能显示来源。
    final mainId = session.mainChatId ?? session.id;
    session.mainChatId ??= session.id;
    branch.parentId ??= session.id;
    branch.mainChatId ??= mainId;
    await AppStore.instance.saveSessions();
    if (!context.mounted) return;
    showTavernToast(
      context,
      checkpoint ? '已创建检查点：${branch.title}' : '已创建分支：${branch.title}',
    );
    // 新分支是一个真实会话：直接打开它，同时它也会出现在对话列表里。
    await _openSession(context, branch);
  }

  Future<void> _openAuthorNote(BuildContext context) {
    return openGlassPage(context, _ChatAuthorNoteSheet(session: session));
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

  Future<void> _applySummarySettings(
    AppSettings Function(AppSettings current) change,
  ) async {
    final store = AppStore.instance;
    store.settings = change(store.settings);
    await store.saveSettings();
  }

  Future<void> _setSummaryPosition(int index) async {
    if (index < 0 || index >= _summaryPositionKeys.length) return;
    await _applySummarySettings(
      (current) => current.copyWith(summaryPosition: _summaryPositionKeys[index]),
    );
  }

  Future<void> _setSummaryRole(int index) async {
    if (index < 0 || index >= _summaryRoleKeys.length) return;
    await _applySummarySettings(
      (current) => current.copyWith(summaryRole: _summaryRoleKeys[index]),
    );
  }

  Future<void> _setSummaryDepth(int depth) async {
    final clamped = depth.clamp(1, 20).toInt();
    await _applySummarySettings(
      (current) => current.copyWith(summaryDepth: clamped),
    );
  }

  int _indexOf(List<String> values, String current) {
    final index = values.indexOf(current);
    return index < 0 ? 0 : index;
  }

  /// 作者笔记这一行必须如实说明当前生效的是「本聊天」还是「全局」。
  String _authorNoteValue(AppSettings settings) {
    if (session.authorNoteOverride) {
      return session.authorNote.trim().isEmpty ? '本聊天 · 空' : '本聊天 · 已覆盖';
    }
    return settings.authorNote.trim().isEmpty ? '跟随全局 · 未设置' : '跟随全局 · 已设置';
  }

  String? _authorNoteSubtitle(AppSettings settings) {
    final effective =
        session.authorNoteOverride ? session.authorNote : settings.authorNote;
    final trimmed = effective.replaceAll('\n', ' ').trim();
    return trimmed.isEmpty ? null : trimmed;
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
    final store = AppStore.instance;
    final settings = store.settings;
    final messageCount = session.messages.length;
    final charCount = session.messages.fold<int>(0, (n, m) => n + m.text.length);
    Lorebook? linkedBook;
    for (final book in store.lorebooks) {
      if (book.name == c.lorebook) linkedBook = book;
    }
    final created = session.messages.isEmpty
        ? null
        : DateTime.fromMillisecondsSinceEpoch(session.messages.first.createdAt);
    String createdText() => created == null
        ? '暂无消息'
        : '${created.year}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')} ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';

    final parentSession = store.sessionById(session.parentId);
    // 主线指针可能指向自己（主线会话本身），也可能与父聊天相同，
    // 这两种情况都不重复展示「主线聊天」。
    final mainLinkId = session.mainChatId != null &&
            session.mainChatId != session.id &&
            session.mainChatId != session.parentId
        ? session.mainChatId
        : null;
    final mainSession = store.sessionById(mainLinkId);
    final childBranches = <ChatSession>[
      for (final s in store.sessions)
        if (s.parentId == session.id) s,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final hasBranchLink = parentSession != null ||
        mainSession != null ||
        childBranches.isNotEmpty;

    final summaryIndex = _indexOf(_summaryPositionKeys, settings.summaryPosition);
    final roleIndex = _indexOf(_summaryRoleKeys, settings.summaryRole);

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
              icon: Icons.file_open_outlined,
              label: '导入聊天',
              color: p.violet,
              onTap: () => _importChat(context),
            ),
            ActionSpec(
              icon: Icons.search_rounded,
              label: '搜索',
              color: p.rose,
              onTap: () => openGlassPage(context, SearchPage(sessionId: session.id)),
            ),
          ],
        ),
        if (hasBranchLink)
          SettingsGroup(
            title: '分支关系',
            footnote: '分支复制创建时的消息；父聊天、主线与子分支都可以直接打开。',
            children: [
              if (parentSession != null) ...[
                SettingRow(
                  icon: Icons.call_split_rounded,
                  title: '父聊天',
                  subtitle: parentSession == null
                      ? '原聊天已删除'
                      : parentSession.title,
                  value: parentSession == null
                      ? '已删除'
                      : '${parentSession.messages.length} 条消息',
                  iconColor: p.amber,
                  chevron: parentSession != null,
                  onTap: parentSession == null
                      ? null
                      : () => _openSession(context, parentSession),
                ),
                if (mainSession != null) const Hairline(indent: 56),
              ],
              if (mainLinkId != null)
                SettingRow(
                  icon: Icons.account_tree_outlined,
                  title: '主线聊天',
                  subtitle: mainSession == null
                      ? '原聊天已删除'
                      : mainSession.title,
                  value: mainSession == null
                      ? '已删除'
                      : '${mainSession.messages.length} 条消息',
                  iconColor: p.violet,
                  chevron: mainSession != null,
                  onTap: mainSession == null
                      ? null
                      : () => _openSession(context, mainSession),
                ),
              if (mainSession != null && childBranches.isNotEmpty)
                const Hairline(indent: 56),
              for (var i = 0; i < childBranches.length; i++) ...[
                SettingRow(
                  icon: Icons.alt_route_rounded,
                  title: '子分支 ${i + 1}',
                  subtitle: childBranches[i].title,
                  value: '${childBranches[i].messages.length} 条消息',
                  iconColor: p.sage,
                  onTap: () => _openSession(context, childBranches[i]),
                ),
                if (i != childBranches.length - 1) const Hairline(indent: 56),
              ],
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
              subtitle: _authorNoteSubtitle(settings),
              value: _authorNoteValue(settings),
              iconColor: p.rose,
              onTap: () => _openAuthorNote(context),
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
              value: '当前聊天',
              iconColor: p.violet,
              onTap: () => openGlassPage(
                context,
                PromptPreviewPage(character: character, session: session),
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: '摘要注入',
          footnote: '摘要内容见「记忆与总结」。位置、角色与深度会立即保存到全局设置，'
              '并作用于所有会话的 Prompt 构建。',
          children: [
            SegmentLine(
              title: '位置',
              options: const ['提示词内', '历史后', '按深度'],
              index: summaryIndex,
              onChanged: _setSummaryPosition,
            ),
            const Hairline(indent: 56),
            SegmentLine(
              title: '角色',
              options: const ['System', 'User', 'Assistant'],
              index: roleIndex,
              onChanged: _setSummaryRole,
            ),
            const Hairline(indent: 56),
            StepperRow(
              title: '注入深度',
              subtitle: '仅「按深度」生效，范围 1–20',
              value: '${settings.summaryDepth.clamp(1, 20)}',
              onMinus: settings.summaryDepth > 1
                  ? () => _setSummaryDepth(settings.summaryDepth - 1)
                  : null,
              onPlus: settings.summaryDepth < 20
                  ? () => _setSummaryDepth(settings.summaryDepth + 1)
                  : null,
            ),
          ],
        ),
        SettingsGroup(
          title: '聊天文件',
          footnote: 'JSONL 与 SillyTavern 的聊天记录兼容；TXT 是「说话人: 内容」的纯文本。',
          children: [
            SettingRow(
              icon: Icons.data_object_rounded,
              title: '导出聊天 JSONL',
              subtitle: '逐行 JSON，保留 swipes 与元数据',
              value: '.jsonl',
              iconColor: p.violet,
              onTap: () => _exportJsonl(context),
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.description_outlined,
              title: '导出聊天 TXT',
              subtitle: '纯文本对话，便于阅读与分享',
              value: '.txt',
              iconColor: p.sage,
              onTap: () => _exportTxt(context),
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.backup_outlined,
              title: '导出完整备份',
              subtitle: '包含全部角色、聊天、世界书与设置',
              value: 'JSON',
              iconColor: p.violet,
              onTap: () => _backup(context),
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

/// 单个会话的「作者笔记」编辑器。
///
/// 开关决定本聊天是否覆盖全局作者笔记：打开时只写 session.authorNote /
/// session.authorNoteOverride，关闭时回退到全局且不改动已保存的覆盖内容。
class _ChatAuthorNoteSheet extends StatefulWidget {
  const _ChatAuthorNoteSheet({required this.session});

  final ChatSession session;

  @override
  State<_ChatAuthorNoteSheet> createState() => _ChatAuthorNoteSheetState();
}

class _ChatAuthorNoteSheetState extends State<_ChatAuthorNoteSheet> {
  late bool _override;
  late final TextEditingController _content;

  @override
  void initState() {
    super.initState();
    _override = widget.session.authorNoteOverride;
    _content = TextEditingController(text: widget.session.authorNote);
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  void _toggleOverride(bool value) {
    setState(() {
      _override = value;
      // 从「跟随全局」切到「本聊天」时，先用全局内容占位，便于在此基础上修改。
      if (value && _content.text.trim().isEmpty) {
        _content.text = AppStore.instance.settings.authorNote;
      }
    });
  }

  Future<void> _editGlobal() async {
    await openGlassPage(context, const AuthorNoteSheet());
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final session = widget.session;
    if (_override) session.authorNote = _content.text.trim();
    session.authorNoteOverride = _override;
    await AppStore.instance.saveSessions();
    if (!mounted) return;
    showTavernToast(
      context,
      _override ? '已保存本聊天的作者笔记' : '已切换为跟随全局作者笔记',
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SheetStage(
      title: '作者笔记',
      subtitle: _override ? '仅作用于当前聊天' : '当前跟随全局作者笔记',
      heightFactor: .82,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: p.rose.withValues(alpha: .16),
        ),
        child: Icon(Icons.sticky_note_2_outlined, size: 18, color: p.rose),
      ),
      footer: GlassPrimaryButton(
        label: '保存',
        icon: Icons.check_rounded,
        onTap: _save,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Glass(
            radius: 18,
            blur: 18,
            shadow: false,
            padding: EdgeInsets.zero,
            child: SwitchLine(
              title: '本聊天单独设置',
              subtitle: '关闭时使用全局作者笔记',
              value: _override,
              onChanged: _toggleOverride,
            ),
          ),
          const SizedBox(height: 12),
          if (_override) ...[
            Text(
              '本聊天的作者笔记',
              style: appText(10.5, FontWeight.w500, p.textTertiary),
            ),
            const SizedBox(height: 6),
            Glass(
              radius: 18,
              blur: 18,
              shadow: false,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: TextField(
                controller: _content,
                maxLines: 7,
                minLines: 4,
                style: appText(14, FontWeight.w400, p.textPrimary, height: 1.5),
                cursorColor: p.amber,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: '保持叙事节奏，多描写环境与身体语言，避免替用户做决定。',
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '只影响当前聊天。关闭「本聊天单独设置」后会自动回退到全局，'
              '这里的内容会保留但不再注入。',
              style: appText(10.5, FontWeight.w400, p.textTertiary, height: 1.5),
            ),
          ] else
            AnimatedBuilder(
              animation: AppStore.instance,
              builder: (context, _) {
                final global =
                    AppStore.instance.settings.authorNote.trim();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '全局作者笔记',
                      style: appText(10.5, FontWeight.w500, p.textTertiary),
                    ),
                    const SizedBox(height: 6),
                    Glass(
                      radius: 18,
                      blur: 18,
                      shadow: false,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Text(
                        global.isEmpty ? '（全局未设置作者笔记）' : global,
                        style: appText(
                          global.isEmpty ? 11.5 : 13,
                          FontWeight.w400,
                          global.isEmpty ? p.textTertiary : p.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        GlassPill(
                          label: '编辑全局作者笔记',
                          icon: Icons.edit_outlined,
                          height: 34,
                          onTap: _editGlobal,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
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
    final settings = AppStore.instance.settings;
    final positionHint = settings.summaryPosition == 'in_prompt'
        ? '提示词内'
        : '${_summaryPositionLabel(settings.summaryPosition)} · 角色 ${settings.summaryRole}'
            '${settings.summaryPosition == 'at_depth' ? ' · 深度 ${settings.summaryDepth.clamp(1, 20)}' : ''}';
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
        const SizedBox(height: 10),
        HintCard(
          text: '当前注入：$positionHint。可在「聊天信息 → 摘要注入」调整位置、角色与深度。',
          icon: Icons.alt_route_rounded,
          color: p.sage,
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
