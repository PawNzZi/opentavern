import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/store.dart';
import '../design/glass.dart';
import '../design/routes.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';
import '../design/toast.dart';
import 'novel_import.dart';

/// 世界书在 Prompt 构建中的生效状态，用于列表 / 详情页提示。
///
/// 非全局且未绑定角色的世界书不会被任何对话扫描，这是最容易误以为
/// 「世界书已经导入却没有拼接」的原因。
String _bookStatusLabel(Lorebook book) {
  if (book.isGlobal) return '全局';
  final linked = (book.linked ?? '').trim();
  if (linked.isNotEmpty) return '绑定：$linked';
  return '未绑定 · 不生效';
}

class LoreScreen extends StatefulWidget {
  const LoreScreen({super.key, this.standalone = true});
  final bool standalone;

  @override
  State<LoreScreen> createState() => _LoreScreenState();
}

class _LoreScreenState extends State<LoreScreen> {
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    AppStore.instance.addListener(_sync);
  }

  @override
  void dispose() {
    AppStore.instance.removeListener(_sync);
    _query.dispose();
    super.dispose();
  }

  void _sync() {
    if (mounted) setState(() {});
  }

  Future<void> _importBook() async {
    final file = await FilePickerPlatform.instance.pickFile();
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (file.name.toLowerCase().endsWith('.zip')) {
      final archive = ZipDecoder().decodeBytes(bytes);
      var imported = 0;
      final failed = <String>[];
      for (final entry in archive.files) {
        if (!entry.isFile || !entry.name.toLowerCase().endsWith('.json')) {
          continue;
        }
        final data = entry.content as List<int>;
        final book = await AppStore.instance.importLorebook(
          Uint8List.fromList(data),
          entry.name.split('/').last,
        );
        if (book != null) {
          imported++;
        } else {
          failed.add(entry.name);
        }
      }
      if (!mounted) return;
      showTavernToast(
        context,
        failed.isEmpty
            ? '已导入 $imported 本世界书'
            : '导入 $imported 本，失败 ${failed.length} 个',
      );
      if (failed.isNotEmpty) {
        await AppStore.instance.logImportFailures(
          failed,
          source: '世界书 ZIP 导入',
        );
        if (!mounted) return;
        await showImportFailures(context, failed);
      }
      if (!mounted) return;
      setState(() {});
      return;
    }
    final book = await AppStore.instance.importLorebook(bytes, file.name);
    if (!mounted) return;
    showTavernToast(
      context,
      book == null
          ? '不是有效的世界书 JSON'
          : '已导入 ${book.name} · ${book.entries.length} 条',
    );
    if (book != null) setState(() {});
  }

  Future<void> _newBook() async {
    final name = await Navigator.of(context).push<String>(
      CupertinoPageRoute(builder: (_) => const _NewLorebookPage()),
    );
    if (name == null || name.trim().isEmpty) return;
    final book = Lorebook(
      id: 'book-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
    );
    await AppStore.instance.addLorebook(book);
    if (!mounted) return;
    openGlassPage(context, LorebookPage(book: book));
  }

  Future<void> _editGlobalBudget() async {
    final controller = TextEditingController(
      text: AppStore.instance.settings.loreMaxTokens > 0
          ? '${AppStore.instance.settings.loreMaxTokens}'
          : '',
    );
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('世界书 Token 上限'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('全局生效。0 或「无限制」= 所有命中条目全部注入，不做任何裁剪；'
                '填数字则按该 Token 上限裁剪。无限制时请把「最大上下文」调大，否则历史可能被挤掉。'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '例如 2000',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, -1), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, 0), child: const Text('无限制')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text.trim()) ?? -1),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result < 0) return;
    final settings = AppStore.instance.settings;
    AppStore.instance.settings = settings.copyWith(loreMaxTokens: result);
    await AppStore.instance.saveSettings();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final q = _query.text.trim().toLowerCase();
    final books = AppStore.instance.lorebooks.where((book) {
      if (q.isEmpty) return true;
      if (book.name.toLowerCase().contains(q)) return true;
      return book.entries.any(
        (e) =>
            e.name.toLowerCase().contains(q) ||
            e.content.toLowerCase().contains(q) ||
            e.keys.any((k) => k.toLowerCase().contains(q)),
      );
    }).toList();
    return TavernScaffold(
      intensity: 1.05,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 40),
          physics: const BouncingScrollPhysics(),
          children: [
            Row(
              children: [
                GlassCircleButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  size: 40,
                  iconSize: 15,
                  onTap: () => Navigator.maybePop(context),
                ),
                const Spacer(),
                GlassCircleButton(
                  icon: Icons.auto_stories_outlined,
                  size: 40,
                  iconSize: 17,
                  onTap: () => openGlassPage(context, const NovelImportPage()),
                ),
                const SizedBox(width: 8),
                GlassCircleButton(
                  icon: Icons.file_download_outlined,
                  size: 40,
                  iconSize: 17,
                  onTap: _importBook,
                ),
                const SizedBox(width: 8),
                GlassCircleButton(
                  icon: Icons.add_rounded,
                  size: 40,
                  onTap: _newBook,
                ),
              ],
            ),
            const SizedBox(height: 18),
            const PageHeader(
              eyebrow: 'LORE',
              title: '世界书',
              subtitle: '关键词触发的设定集，让角色记得整个世界。',
            ),
            const SizedBox(height: 20),
            SearchField(
              hint: '搜索世界书或条目',
              controller: _query,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Glass(
              radius: 20,
              blur: 20,
              shadow: false,
              child: SettingRow(
                icon: Icons.speed_rounded,
                title: '世界书 Token 上限',
                subtitle: '全局设置；0 = 无限制，全部命中条目注入；填数字按上限裁剪',
                value: AppStore.instance.settings.loreMaxTokens > 0
                    ? '${AppStore.instance.settings.loreMaxTokens}'
                    : '无限制',
                onTap: _editGlobalBudget,
              ),
            ),
            const SizedBox(height: 14),
            const SectionLabel('全部世界书'),
            for (final book in books) ...[
              _LoreCard(
                book: book,
                onTap: () => openGlassPage(context, LorebookPage(book: book)),
              ),
              const SizedBox(height: 11),
            ],
            if (books.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Text(
                    '还没有世界书，点右上角 + 新建',
                    style: appText(12.5, FontWeight.w400, p.textTertiary),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Glass(
              radius: 20,
              blur: 20,
              shadow: false,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded, size: 16, color: p.amber),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '对话时，世界书会扫描最近的消息、角色卡、人格与作者笔记，'
                      '命中关键词的条目会自动进入提示词。'
                      '只有「全局」世界书或绑定了当前角色的世界书会参与构建；'
                      '把条目设为「常驻」可以让它始终在场。',
                      style: appText(11.5, FontWeight.w400, p.textSecondary, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LorebookPage extends StatefulWidget {
  const LorebookPage({super.key, required this.book});
  final Lorebook book;

  @override
  State<LorebookPage> createState() => _LorebookPageState();
}

class _LorebookPageState extends State<LorebookPage> {
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    AppStore.instance.addListener(_sync);
  }

  @override
  void dispose() {
    AppStore.instance.removeListener(_sync);
    _query.dispose();
    super.dispose();
  }

  void _sync() {
    if (mounted) setState(() {});
  }

  Future<void> _add() async {
    await openGlassPage(context, LoreEntryEditorPage(book: widget.book));
    if (mounted) setState(() {});
  }

  Future<void> _exportBook() async {
    final data = AppStore.instance.exportLorebookJson(widget.book);
    final uri = await FilePickerPlatform.instance.saveFile(
      fileName: '${widget.book.name}.json',
      bytes: Uint8List.fromList(utf8.encode(data)),
      mimeType: 'application/json',
      dialogTitle: '导出世界书 JSON',
    );
    if (!mounted) return;
    showTavernToast(context, uri == null ? '已取消导出' : '世界书已导出');
  }

  Future<void> _deleteBook() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除世界书'),
        content: Text('确定删除「${widget.book.name}」及其全部条目？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    await AppStore.instance.deleteLorebook(widget.book.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _setBookEnabled(bool value) async {
    widget.book.enabled = value;
    widget.book.updatedAt = DateTime.now().millisecondsSinceEpoch;
    setState(() {});
    await AppStore.instance.saveLorebooks();
  }

  Future<void> _setBookGlobal(bool value) async {
    widget.book.isGlobal = value;
    widget.book.updatedAt = DateTime.now().millisecondsSinceEpoch;
    setState(() {});
    await AppStore.instance.saveLorebooks();
  }

  Future<void> _pickLinkedCharacter() async {
    final names = AppStore.instance.characters
        .map((c) => c.name.trim())
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('绑定角色'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('不绑定（未绑定且非全局的世界书不会生效）'),
          ),
          for (final name in names)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, name),
              child: Text(name),
            ),
          if (names.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Text('还没有角色，可先在角色页创建角色。'),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    widget.book.linked = picked.trim().isEmpty ? null : picked.trim();
    widget.book.updatedAt = DateTime.now().millisecondsSinceEpoch;
    setState(() {});
    await AppStore.instance.saveLorebooks();
  }

  Future<void> _moveEntry(LoreEntry entry, int delta) async {
    final index = widget.book.entries.indexOf(entry);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= widget.book.entries.length) {
      return;
    }
    widget.book.entries.removeAt(index);
    widget.book.entries.insert(target, entry);
    await AppStore.instance.saveLorebooks();
    if (mounted) setState(() {});
  }

  Future<void> _deleteEntry(LoreEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除条目'),
        content: Text('确定删除「${entry.name}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    widget.book.entries.removeWhere((e) => e.id == entry.id);
    await AppStore.instance.saveLorebooks();
    if (mounted) setState(() {});
  }

  String _entryTitle(LoreEntry entry) {
    if (entry.name.trim().isNotEmpty) return entry.name.trim();
    if (entry.keys.isNotEmpty) return entry.keys.first;
    return '无标题条目';
  }

  /// 列表里直接展示正文开头，这样导入后不打开编辑器也能确认内容已解析出来。
  String _entrySubtitle(LoreEntry entry) {
    final preview = entry.content.replaceAll(RegExp(r'\s+'), ' ').trim();
    final head = entry.keys.isNotEmpty
        ? entry.keys.join(' · ')
        : entry.constant
            ? '常驻'
            : '无关键词';
    return preview.isEmpty ? head : '$head · $preview';
  }

  String _entryStatus(LoreEntry entry) {
    if (!entry.enabled) return '关闭';
    if (entry.constant) return '常驻';
    if (entry.keys.isEmpty) return '未生效';
    return '启用';
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final book = widget.book;
    final q = _query.text.trim().toLowerCase();
    final entryList = book.entries.where((e) {
      if (q.isEmpty) return true;
      return e.name.toLowerCase().contains(q) ||
          e.content.toLowerCase().contains(q) ||
          e.keys.any((k) => k.toLowerCase().contains(q));
    }).toList();
    return TavernScaffold(
      intensity: 1.05,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 40),
          children: [
            Row(
              children: [
                GlassCircleButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  size: 40,
                  iconSize: 15,
                  onTap: () => Navigator.maybePop(context),
                ),
                const Spacer(),
                GlassCircleButton(
                  icon: Icons.ios_share_rounded,
                  size: 40,
                  iconSize: 17,
                  onTap: _exportBook,
                ),
                const SizedBox(width: 8),
                GlassCircleButton(
                  icon: Icons.delete_outline_rounded,
                  size: 40,
                  iconSize: 17,
                  onTap: _deleteBook,
                ),
                const SizedBox(width: 8),
                GlassCircleButton(
                  icon: Icons.add_rounded,
                  size: 40,
                  onTap: _add,
                ),
              ],
            ),
            const SizedBox(height: 18),
            PageHeader(
              eyebrow: 'LOREBOOK',
              title: book.name,
              subtitle: '${book.entries.length} 条 · ${_bookStatusLabel(book)}',
            ),
            const SizedBox(height: 14),
            SettingsGroup(
              title: '世界书设置',
              footnote: '关闭「启用」后，整本书不会参与关键词匹配；'
                  '「全局」世界书对所有角色生效；非全局世界书只对绑定的角色生效，'
                  '既未绑定角色、也没开启「全局」的世界书不会进入任何 Prompt。'
                  '这里的修改会立即保存。',
              children: [
                SwitchLine(
                  title: '启用世界书',
                  subtitle: '关闭后本书所有条目都不会进入 Prompt',
                  value: book.enabled,
                  onChanged: _setBookEnabled,
                ),
                SwitchLine(
                  title: '全局世界书',
                  subtitle: '开启后所有角色的对话都会扫描本书',
                  value: book.isGlobal,
                  onChanged: _setBookGlobal,
                ),
                SettingRow(
                  icon: Icons.person_outline_rounded,
                  title: '绑定角色',
                  subtitle: book.isGlobal
                      ? '全局世界书无需绑定；这里仅记录关联角色'
                      : '仅该角色的对话会额外扫描本书',
                  value: (book.linked ?? '').trim().isEmpty
                      ? (book.isGlobal ? '未绑定' : '未绑定 · 不生效')
                      : book.linked,
                  onTap: _pickLinkedCharacter,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                GlassPill(
                  label: book.entries.every((e) => e.enabled)
                      ? '全部停用'
                      : '全部启用',
                  icon: Icons.toggle_on_outlined,
                  height: 30,
                  onTap: () async {
                    final enable = !book.entries.every((e) => e.enabled);
                    for (final e in book.entries) {
                      e.enabled = enable;
                    }
                    await AppStore.instance.saveLorebooks();
                    if (mounted) setState(() {});
                  },
                ),
                const Spacer(),
                Text(
                  '${entryList.length} 条',
                  style: appText(11, FontWeight.w400, p.textTertiary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (entryList.isEmpty)
              Glass(
                radius: 22,
                blur: 22,
                shadow: false,
                padding: const EdgeInsets.all(22),
                child: Center(
                  child: Text(
                    '还没有条目，点右上角 + 添加',
                    style: appText(13, FontWeight.w400, p.textTertiary),
                  ),
                ),
              )
            else
              Glass(
                radius: 24,
                blur: 24,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < entryList.length; i++) ...[
                      GestureDetector(
                        onLongPress: () => _deleteEntry(entryList[i]),
                        child: SettingRow(
                          icon: Icons.article_outlined,
                          title: _entryTitle(entryList[i]),
                          subtitle: _entrySubtitle(entryList[i]),
                          value: _entryStatus(entryList[i]),
                          chevron: false,
                          iconColor: entryList[i].enabled
                              ? p.amber
                              : p.textTertiary,
                          onTap: () async {
                            await openGlassPage(
                              context,
                              LoreEntryEditorPage(
                                book: book,
                                entry: entryList[i],
                              ),
                            );
                            if (mounted) setState(() {});
                          },
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GlassCircleButton(
                                icon: Icons.keyboard_arrow_up_rounded,
                                size: 28,
                                iconSize: 15,
                                blur: 0,
                                onTap: () => _moveEntry(entryList[i], -1),
                              ),
                              const SizedBox(width: 2),
                              GlassCircleButton(
                                icon: Icons.keyboard_arrow_down_rounded,
                                size: 28,
                                iconSize: 15,
                                blur: 0,
                                onTap: () => _moveEntry(entryList[i], 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (i != entryList.length - 1)
                        const Hairline(indent: 56),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: GlassPrimaryButton(
                label: '添加条目',
                icon: Icons.add_rounded,
                onTap: _add,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '条目内容会按关键词自动进入上下文；「常驻」条目每次都会注入。长按条目可删除。',
              style: appText(10.5, FontWeight.w400, p.textTertiary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class LoreEntryEditorPage extends StatefulWidget {
  const LoreEntryEditorPage({super.key, required this.book, this.entry});
  final Lorebook book;
  final LoreEntry? entry;

  @override
  State<LoreEntryEditorPage> createState() => _LoreEntryEditorPageState();
}

class _LoreEntryEditorPageState extends State<LoreEntryEditorPage> {
  static const _logicValues = ['AND_ANY', 'AND_ALL', 'NOT_ANY', 'NOT_ALL'];
  static const _roles = ['system', 'user', 'assistant'];

  late final TextEditingController _name;
  late final TextEditingController _keys;
  late final TextEditingController _content;
  late final TextEditingController _secondary;
  late final TextEditingController _group;
  late bool _constant;
  late bool _enabled;
  late bool _selective;
  late String _position;
  late int _order;
  late int _probability;
  late int _groupWeight;
  late int _sticky;
  late int _cooldown;
  late int _delay;
  late bool _caseSensitive;
  late bool _matchWholeWords;
  late String _selectiveLogic;
  late bool _excludeRecursion;
  late bool _preventRecursion;
  late int _depth;
  late String _role;

  int get _logicIndex =>
      _logicValues.indexOf(_selectiveLogic).clamp(0, _logicValues.length - 1).toInt();

  int get _roleIndex =>
      _roles.indexOf(_role).clamp(0, _roles.length - 1).toInt();

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _name = TextEditingController(text: e?.name ?? '');
    _keys = TextEditingController(text: e?.keys.join(', ') ?? '');
    _content = TextEditingController(text: e?.content ?? '');
    _secondary = TextEditingController(text: e?.secondaryKeys.join(', ') ?? '');
    _group = TextEditingController(text: e?.group ?? '');
    _constant = e?.constant ?? false;
    _enabled = e?.enabled ?? true;
    _selective = e?.selective ?? false;
    _position = e?.position ?? 'before';
    _order = e?.order ?? 100;
    _probability = (e?.probability ?? 100).clamp(0, 100).toInt();
    _groupWeight = (e?.groupWeight ?? 100).clamp(0, 1000).toInt();
    _sticky = (e?.sticky ?? 0).clamp(0, 999).toInt();
    _cooldown = (e?.cooldown ?? 0).clamp(0, 999).toInt();
    _delay = (e?.delay ?? 0).clamp(0, 999).toInt();
    _caseSensitive = e?.caseSensitive ?? false;
    _matchWholeWords = e?.matchWholeWords ?? false;
    _selectiveLogic =
        _logicValues.contains(e?.selectiveLogic) ? e!.selectiveLogic : 'AND_ANY';
    _excludeRecursion = e?.excludeRecursion ?? false;
    _preventRecursion = e?.preventRecursion ?? false;
    _depth = (e?.depth ?? 4).clamp(0, 999).toInt();
    _role = _roles.contains(e?.role) ? e!.role : 'system';
  }

  @override
  void dispose() {
    _name.dispose();
    _keys.dispose();
    _content.dispose();
    _secondary.dispose();
    _group.dispose();
    super.dispose();
  }

  List<String> _split(String value) => value
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _save() async {
    final keys = _split(_keys.text);
    final content = _content.text.trim();
    if (content.isEmpty) {
      showTavernToast(context, '条目内容不能为空');
      return;
    }
    final name = _name.text.trim();
    final resolvedName = name.isNotEmpty
        ? name
        : keys.isNotEmpty
            ? keys.first
            : _constant
                ? '常驻条目'
                : '无关键词条目';
    final entry = widget.entry ??
        LoreEntry(id: 'entry-${DateTime.now().microsecondsSinceEpoch}');
    entry
      ..name = resolvedName
      ..keys = keys
      ..secondaryKeys = _split(_secondary.text)
      ..content = content
      ..constant = _constant
      ..enabled = _enabled
      ..selective = _selective
      ..position = _position
      ..order = _order
      ..probability = _probability.clamp(0, 100).toInt()
      ..group = _group.text.trim()
      ..groupWeight = _groupWeight.clamp(0, 1000).toInt()
      ..sticky = _sticky.clamp(0, 999).toInt()
      ..cooldown = _cooldown.clamp(0, 999).toInt()
      ..delay = _delay.clamp(0, 999).toInt()
      ..caseSensitive = _caseSensitive
      ..matchWholeWords = _matchWholeWords
      ..selectiveLogic = _logicValues[_logicIndex]
      ..excludeRecursion = _excludeRecursion
      ..preventRecursion = _preventRecursion
      ..depth = _depth.clamp(0, 999).toInt()
      ..role = _roles[_roleIndex]
      ..comment = resolvedName;
    if (widget.entry == null) widget.book.entries.add(entry);
    widget.book.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await AppStore.instance.saveLorebooks();
    if (!mounted) return;
    showTavernToast(
      context,
      keys.isEmpty && !_constant
          ? '条目已保存（无关键词且未常驻，不会自动生效）'
          : '条目已保存',
    );
    Navigator.of(context).maybePop();
  }

  Future<void> _deleteEntry() async {
    final entry = widget.entry;
    if (entry == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除条目'),
        content: Text('确定删除「${entry.name.isEmpty ? entry.keys.join(' · ') : entry.name}」？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    widget.book.entries.removeWhere((e) => e.id == entry.id);
    await AppStore.instance.saveLorebooks();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final isNew = widget.entry == null;
    final status = !_enabled
        ? '已关闭'
        : _constant
            ? '常驻'
            : '关键词触发';
    return DetailPage(
      eyebrow: isNew ? 'NEW LORE ENTRY' : 'LORE ENTRY',
      title: isNew ? '新建条目' : '编辑条目',
      subtitle: '${widget.book.name} · $status',
      trailing: isNew
          ? null
          : GlassCircleButton(
              icon: Icons.delete_outline_rounded,
              size: 38,
              iconSize: 17,
              blur: 0,
              onTap: _deleteEntry,
            ),
      footer: GlassPrimaryButton(
        label: '保存条目',
        icon: Icons.check_rounded,
        onTap: _save,
      ),
      children: [
        const SizedBox(height: 6),
        _LoreField(label: '条目名', controller: _name, hint: '例如：王都的雨'),
        _LoreField(
          label: '关键词（逗号分隔）',
          controller: _keys,
          hint: '王都, 雨, 预言',
        ),
        _LoreField(
          label: '内容',
          controller: _content,
          hint: '命中关键词后注入模型的世界设定…',
          height: 220,
          onFullscreen: () async {
            final value = await Navigator.of(context).push<String>(
              CupertinoPageRoute(
                builder: (_) => _FullscreenLoreEditor(initial: _content.text),
              ),
            );
            if (value != null && mounted) {
              setState(() => _content.text = value);
            }
          },
        ),
        _LoreField(
          label: '次要关键词（可选）',
          controller: _secondary,
          hint: '启用选择性匹配时使用',
        ),
        _LoreField(
          label: '分组名（可选）',
          controller: _group,
          hint: '同组条目只保留组内权重最高的一条，例如：天气',
        ),
        const SizedBox(height: 16),
        SettingsGroup(
          title: '条目设置',
          children: [
            SwitchLine(
              title: '常驻',
              subtitle: '不扫描关键词，每次对话都注入',
              value: _constant,
              onChanged: (v) => setState(() => _constant = v),
            ),
            const Hairline(indent: 14),
            SwitchLine(
              title: '启用',
              subtitle: '关闭后不会进入 Prompt，但仍保留在列表中',
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            const Hairline(indent: 14),
            SwitchLine(
              title: '选择性匹配',
              subtitle: '同时命中次要关键词才注入（ST selective）',
              value: _selective,
              onChanged: (v) => setState(() => _selective = v),
            ),
            const Hairline(indent: 14),
            SegmentLine(
              title: '注入位置',
              options: const ['角色前', '角色后', '按深度'],
              index: _position == 'at_depth'
                  ? 2
                  : _position == 'after'
                      ? 1
                      : 0,
              onChanged: (i) => setState(
                () => _position = i == 2
                    ? 'at_depth'
                    : i == 1
                        ? 'after'
                        : 'before',
              ),
            ),
            const Hairline(indent: 14),
            StepperRow(
              title: '插入顺序',
              subtitle: '对应 ST 的 insertion_order，数字越大越靠前',
              value: '$_order',
              onMinus: () => setState(() => _order--),
              onPlus: () => setState(() => _order++),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsGroup(
          title: '触发设置',
          footnote: '概率 0 = 永不触发，100 = 必定触发，中间值按对话内容生成稳定随机结果。'
              '选择性逻辑仅在开启「选择性匹配」且有次要关键词时生效：'
              '任一 = 命中任一次要词；全部 = 全部命中；均不 = 一个都不命中；非全 = 未全部命中。',
          children: [
            SliderLine(
              title: '触发概率',
              value: _probability.toDouble(),
              display: '$_probability%',
              min: 0,
              max: 100,
              divisions: 100,
              onChanged: (v) => setState(() => _probability = v.round()),
            ),
            if (_selective) ...[
              SegmentLine(
                title: '选择性逻辑',
                options: const ['任一', '全部', '均不', '非全'],
                index: _logicIndex,
                onChanged: (i) =>
                    setState(() => _selectiveLogic = _logicValues[i]),
              ),
            ],
            SwitchLine(
              title: '区分大小写',
              subtitle: '关闭时忽略英文大小写；/正则/ 关键词同样遵循此设置',
              value: _caseSensitive,
              onChanged: (v) => setState(() => _caseSensitive = v),
            ),
            SwitchLine(
              title: '全词匹配',
              subtitle: '关键词必须是独立单词，避免命中更长单词的一部分',
              value: _matchWholeWords,
              onChanged: (v) => setState(() => _matchWholeWords = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsGroup(
          title: '分组与递归',
          footnote: '同组只保留组内权重最高的一条；'
              '「排除递归」= 该条目内容不会再去触发其他条目；'
              '「阻止递归」= 该条目不会被其他条目的内容再次激活。',
          children: [
            StepperRow(
              title: '分组权重',
              subtitle: '同组中权重高者优先进入 Prompt（默认 100）',
              value: '$_groupWeight',
              onMinus: () => setState(
                () => _groupWeight = (_groupWeight - 10).clamp(0, 1000).toInt(),
              ),
              onPlus: () => setState(
                () => _groupWeight = (_groupWeight + 10).clamp(0, 1000).toInt(),
              ),
            ),
            SwitchLine(
              title: '排除递归',
              subtitle: '该条目的内容不再参与递归扫描',
              value: _excludeRecursion,
              onChanged: (v) => setState(() => _excludeRecursion = v),
            ),
            SwitchLine(
              title: '阻止递归',
              subtitle: '其他条目触发的内容不会再次激活本条',
              value: _preventRecursion,
              onChanged: (v) => setState(() => _preventRecursion = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsGroup(
          title: '深度注入',
          footnote: '「注入角色」的三个选项分别保存为 system / user / assistant，'
              '「注入深度」对应 ST 的 depth 字段；当前版本会保存并导出这两个值，'
              '注入位置选「按深度」时会按深度和角色插入历史；角色前 / 后仍合并为 system 段。',
          children: [
            StepperRow(
              title: '注入深度',
              subtitle: '从对话末尾往前计数的消息条数（ST depth，0 = 末尾）',
              value: '$_depth',
              onMinus: () => setState(
                () => _depth = (_depth - 1).clamp(0, 999).toInt(),
              ),
              onPlus: () => setState(
                () => _depth = (_depth + 1).clamp(0, 999).toInt(),
              ),
            ),
            SegmentLine(
              title: '注入角色',
              options: const ['系统', '用户', '助手'],
              index: _roleIndex,
              onChanged: (i) => setState(() => _role = _roles[i]),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsGroup(
          title: '时序控制',
          footnote: '与 SillyTavern 保持字段兼容：数值会随条目保存与导出，'
              '当前版本的触发判定尚未使用 sticky / cooldown / delay（单位：对话轮次）。',
          children: [
            StepperRow(
              title: '粘滞轮数',
              subtitle: '激活后保持注入的轮数（0 = 关闭）',
              value: '$_sticky',
              onMinus: () => setState(
                () => _sticky = (_sticky - 1).clamp(0, 999).toInt(),
              ),
              onPlus: () => setState(
                () => _sticky = (_sticky + 1).clamp(0, 999).toInt(),
              ),
            ),
            StepperRow(
              title: '冷却轮数',
              subtitle: '触发后冷却、不再触发的轮数（0 = 关闭）',
              value: '$_cooldown',
              onMinus: () => setState(
                () => _cooldown = (_cooldown - 1).clamp(0, 999).toInt(),
              ),
              onPlus: () => setState(
                () => _cooldown = (_cooldown + 1).clamp(0, 999).toInt(),
              ),
            ),
            StepperRow(
              title: '延迟轮数',
              subtitle: '对话达到该轮数后才允许触发（0 = 关闭）',
              value: '$_delay',
              onMinus: () => setState(
                () => _delay = (_delay - 1).clamp(0, 999).toInt(),
              ),
              onPlus: () => setState(
                () => _delay = (_delay + 1).clamp(0, 999).toInt(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '关键词支持逗号分隔多个；当前版本按最近 8 条消息扫描。'
          '无关键词且未设为常驻的条目会被保留，但不会自动触发。',
          style: appText(10.5, FontWeight.w400, p.textTertiary, height: 1.5),
        ),
      ],
    );
  }
}

class _LoreField extends StatelessWidget {
  const _LoreField({
    required this.label,
    required this.controller,
    required this.hint,
    this.height,
    this.onFullscreen,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final double? height;
  final VoidCallback? onFullscreen;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Glass(
        radius: 18,
        blur: 18,
        shadow: false,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: appText(10.5, FontWeight.w500, p.textTertiary))),
                if (onFullscreen != null)
                  GlassPill(
                    label: '全屏编辑',
                    icon: Icons.open_in_full_rounded,
                    height: 26,
                    onTap: onFullscreen,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: height,
              child: TextField(
                controller: controller,
                minLines: height == null ? 1 : null,
                maxLines: height == null ? 1 : null,
                expands: height != null,
                textAlignVertical: height == null ? null : TextAlignVertical.top,
                style: appText(14, FontWeight.w400, p.textPrimary, height: 1.45),
                cursorColor: p.amber,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: appText(12.5, FontWeight.w400, p.textTertiary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoreCard extends StatelessWidget {
  const _LoreCard({required this.book, required this.onTap});

  final Lorebook book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final color = book.isGlobal ? p.violet : p.amber;
    return Glass(
      radius: 24,
      blur: 24,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: .85), color.withValues(alpha: .38)],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: .18), width: .8),
            ),
            child: const Icon(Icons.auto_stories_rounded, size: 21, color: Colors.white),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        book.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appText(15, FontWeight.w600, p.textPrimary),
                      ),
                    ),
                    if (book.isGlobal) ...[
                      const SizedBox(width: 6),
                      const TagBadge('全局'),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${book.entries.length} 条 · ${_bookStatusLabel(book)}',
                  style: appText(
                    11,
                    FontWeight.w400,
                    book.isGlobal ||
                            (book.linked ?? '').trim().isNotEmpty
                        ? p.textTertiary
                        : p.rose,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: p.textTertiary),
        ],
      ),
    );
  }
}

class _NewLorebookPage extends StatefulWidget {
  const _NewLorebookPage();

  @override
  State<_NewLorebookPage> createState() => _NewLorebookPageState();
}

class _NewLorebookPageState extends State<_NewLorebookPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetailPage(
      eyebrow: 'NEW LOREBOOK',
      title: '新建世界书',
      subtitle: '只会在本机保存。',
      footer: GlassPrimaryButton(
        label: '创建',
        icon: Icons.check_rounded,
        onTap: () => Navigator.of(context).pop(_controller.text),
      ),
      children: [
        const SizedBox(height: 12),
        Glass(
          radius: 18,
          blur: 18,
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _controller,
            autofocus: true,
            style: const TextStyle(fontSize: 15),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '世界书名称',
            ),
          ),
        ),
      ],
    );
  }
}

class _FullscreenLoreEditor extends StatefulWidget {
  const _FullscreenLoreEditor({required this.initial});
  final String initial;

  @override
  State<_FullscreenLoreEditor> createState() => _FullscreenLoreEditorState();
}

class _FullscreenLoreEditorState extends State<_FullscreenLoreEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: p.canvasTop,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [p.canvasTop, p.canvasBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(
                  children: [
                    GlassCircleButton(
                      icon: Icons.close_rounded,
                      size: 40,
                      iconSize: 17,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '编辑世界书内容',
                        style: appText(17, FontWeight.w600, p.textPrimary),
                      ),
                    ),
                    GlassPill(
                      label: '保存',
                      icon: Icons.check_rounded,
                      onTap: () => Navigator.of(context).pop(_controller.text),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Glass(
                    radius: 22,
                    blur: 22,
                    padding: const EdgeInsets.all(14),
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      style: appText(14.5, FontWeight.w400, p.textPrimary, height: 1.55),
                      cursorColor: p.amber,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '输入世界书条目内容…',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
