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
                      '对话时，世界书会扫描最近的消息，命中关键词的条目会自动进入提示词。'
                      '你也可以把条目设为「常驻」，让它始终在场。',
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
              subtitle:
                  '${book.entries.length} 条 · ${book.linked ?? (book.isGlobal ? "全局" : "未绑定")}',
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
                      SettingRow(
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
                      if (i != entryList.length - 1)
                        const Hairline(indent: 56),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Text(
              '条目内容会按关键词自动进入上下文；「常驻」条目每次都会注入。',
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
  late final TextEditingController _name;
  late final TextEditingController _keys;
  late final TextEditingController _content;
  late final TextEditingController _secondary;
  late bool _constant;
  late bool _enabled;
  late bool _selective;
  late String _position;
  late int _order;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _name = TextEditingController(text: e?.name ?? '');
    _keys = TextEditingController(text: e?.keys.join(', ') ?? '');
    _content = TextEditingController(text: e?.content ?? '');
    _secondary = TextEditingController(text: e?.secondaryKeys.join(', ') ?? '');
    _constant = e?.constant ?? false;
    _enabled = e?.enabled ?? true;
    _selective = e?.selective ?? false;
    _position = e?.position ?? 'before';
    _order = e?.order ?? 100;
  }

  @override
  void dispose() {
    _name.dispose();
    _keys.dispose();
    _content.dispose();
    _secondary.dispose();
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
    if (context.mounted) Navigator.of(context).pop();
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
          minLines: 10,
          maxLines: null,
        ),
        _LoreField(
          label: '次要关键词（可选）',
          controller: _secondary,
          hint: '启用选择性匹配时使用',
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
              options: const ['角色前', '角色后'],
              index: _position == 'after' ? 1 : 0,
              onChanged: (i) =>
                  setState(() => _position = i == 1 ? 'after' : 'before'),
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
    this.minLines = 1,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final int minLines;
  final int? maxLines;

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
            Text(label, style: appText(10.5, FontWeight.w500, p.textTertiary)),
            const SizedBox(height: 4),
            TextField(
              controller: controller,
              minLines: minLines,
              maxLines: maxLines,
              style: appText(14, FontWeight.w400, p.textPrimary, height: 1.45),
              cursorColor: p.amber,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: appText(12.5, FontWeight.w400, p.textTertiary),
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
                  '${book.entries.length} 条 · ${book.linked ?? (book.isGlobal ? "全局" : "未绑定")}',
                  style: appText(11, FontWeight.w400, p.textTertiary),
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
