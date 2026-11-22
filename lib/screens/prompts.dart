import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/store.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';
import '../design/toast.dart';
import 'prompt_preview.dart';

class PromptManagerPage extends StatefulWidget {
  const PromptManagerPage({super.key, this.preset});

  final PromptPreset? preset;

  @override
  State<PromptManagerPage> createState() => _PromptManagerPageState();
}

class _PromptManagerPageState extends State<PromptManagerPage> {
  PromptPreset get _preset {
    final active = widget.preset ?? AppStore.instance.activePreset;
    if (active != null) return active;
    final preset = PromptPreset(
      id: 'preset-${DateTime.now().microsecondsSinceEpoch}',
      name: '默认预设',
      mainPrompt: AppStore.instance.settings.mainPrompt,
      entries: [],
    );
    AppStore.instance.presets.add(preset);
    AppStore.instance.activePresetId = preset.id;
    AppStore.instance.savePresets();
    return preset;
  }

  @override
  void initState() {
    super.initState();
    AppStore.instance.addListener(_sync);
  }

  @override
  void dispose() {
    AppStore.instance.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (mounted) setState(() {});
  }

  Future<void> _add() async {
    final entry = PromptEntry(
      id: 'entry-${DateTime.now().microsecondsSinceEpoch}',
      name: '新条目 ${_preset.entries.length + 1}',
      content: '',
      order: (_preset.entries.length + 1) * 10,
    );
    _preset.entries.add(entry);
    await AppStore.instance.savePresets();
    if (!mounted) return;
    await openEntry(entry);
    if (mounted) setState(() {});
  }

  Future<void> _move(int index, int delta) async {
    final entries = [..._preset.entries]
      ..sort((a, b) => a.order.compareTo(b.order));
    final target = index + delta;
    if (target < 0 || target >= entries.length) return;
    final a = entries[index];
    final b = entries[target];
    final order = a.order;
    a.order = b.order;
    b.order = order;
    await AppStore.instance.savePresets();
    if (mounted) setState(() {});
  }

  Future<void> openEntry(PromptEntry entry) async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => _PromptEntryPage(preset: _preset, entry: entry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final entries = [..._preset.entries]
      ..sort((a, b) => a.order.compareTo(b.order));
    return DetailPage(
      eyebrow: 'PROMPT MANAGER',
      title: '提示词',
      subtitle: _preset.name,
      footer: GlassPrimaryButton(
        label: '添加提示词条目',
        icon: Icons.add_rounded,
        onTap: _add,
      ),
      children: [
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: GlassPill(
            label: '构建预览',
            icon: Icons.account_tree_outlined,
            height: 32,
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => const PromptPreviewPage()),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Glass(
          radius: 24,
          blur: 24,
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('主提示词', style: appText(14, FontWeight.w600, p.textPrimary)),
              const SizedBox(height: 6),
              Text(
                _preset.mainPrompt.trim().isEmpty
                    ? '未设置：构建 prompt 时跳过「主提示词 / 规则」段落；填写后才会发送。'
                    : _preset.mainPrompt,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: appText(12, FontWeight.w400, p.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: GlassPill(
                  label: '编辑主提示词',
                  height: 30,
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => _MainPromptPage(preset: _preset),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SettingsGroup(
          title: '附加提示词',
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              SettingRow(
                icon: Icons.subject_rounded,
                title: entries[i].name,
                subtitle: '${entries[i].role} · order ${entries[i].order}',
                value: entries[i].enabled ? '启用' : '关闭',
                iconColor: entries[i].enabled ? p.amber : p.textTertiary,
                onTap: () async {
                  await openEntry(entries[i]);
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
                      onTap: () => _move(i, -1),
                    ),
                    const SizedBox(width: 2),
                    GlassCircleButton(
                      icon: Icons.keyboard_arrow_down_rounded,
                      size: 28,
                      iconSize: 15,
                      blur: 0,
                      onTap: () => _move(i, 1),
                    ),
                  ],
                ),
              ),
              if (i != entries.length - 1) const Hairline(indent: 56),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '启用的 system 条目会追加到系统提示；user/assistant 条目会作为额外上下文插入历史之前。',
          style: appText(10.5, FontWeight.w400, p.textTertiary, height: 1.5),
        ),
      ],
    );
  }
}

class _MainPromptPage extends StatefulWidget {
  const _MainPromptPage({required this.preset});
  final PromptPreset preset;

  @override
  State<_MainPromptPage> createState() => _MainPromptPageState();
}

class _MainPromptPageState extends State<_MainPromptPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.preset.mainPrompt);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    widget.preset.mainPrompt = _controller.text.trim();
    await AppStore.instance.savePresets();
    if (!mounted) return;
    showTavernToast(context, '主提示词已保存');
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return SheetStage(
      title: '主提示词',
      subtitle: widget.preset.name,
      footer: GlassPrimaryButton(
        label: '保存',
        icon: Icons.check_rounded,
        onTap: _save,
      ),
      child: TextField(
        controller: _controller,
        minLines: 8,
        maxLines: 20,
        style: appText(14, FontWeight.w400, AppPalette.of(context).textPrimary, height: 1.6),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: '你正在扮演 {{char}}…',
        ),
      ),
    );
  }
}

class _PromptEntryPage extends StatefulWidget {
  const _PromptEntryPage({required this.preset, required this.entry});
  final PromptPreset preset;
  final PromptEntry entry;

  @override
  State<_PromptEntryPage> createState() => _PromptEntryPageState();
}

class _PromptEntryPageState extends State<_PromptEntryPage> {
  late final TextEditingController _name;
  late final TextEditingController _content;
  late final TextEditingController _order;
  late String _role;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.entry.name);
    _content = TextEditingController(text: widget.entry.content);
    _order = TextEditingController(text: '${widget.entry.order}');
    _role = widget.entry.role;
    _enabled = widget.entry.enabled;
  }

  @override
  void dispose() {
    _name.dispose();
    _content.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final entry = widget.entry;
    entry
      ..name = _name.text.trim().isEmpty ? '未命名条目' : _name.text.trim()
      ..content = _content.text.trim()
      ..role = _role
      ..enabled = _enabled
      ..order = int.tryParse(_order.text.trim()) ?? entry.order;
    if (widget.preset.entries.every((e) => e.id != entry.id)) {
      widget.preset.entries.add(entry);
    }
    await AppStore.instance.savePresets();
    if (!mounted) return;
    showTavernToast(context, '提示词已保存');
    Navigator.of(context).maybePop();
  }

  Future<void> _delete() async {
    widget.preset.entries.removeWhere((e) => e.id == widget.entry.id);
    await AppStore.instance.savePresets();
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SheetStage(
      title: '编辑提示词',
      subtitle: widget.preset.name,
      heightFactor: .9,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassPrimaryButton(
            label: '保存条目',
            icon: Icons.check_rounded,
            onTap: _save,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _delete,
            child: Text('删除条目', style: appText(12, FontWeight.w500, p.danger)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PromptField(label: '名称', controller: _name),
          _PromptField(label: '内容', controller: _content, maxLines: 8),
          _PromptField(label: '顺序（数字越小越前）', controller: _order),
          const SizedBox(height: 8),
          SettingsGroup(
            title: '行为',
            children: [
              SwitchLine(
                title: '启用',
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
              const Hairline(indent: 14),
              SegmentLine(
                title: '角色',
                options: const ['system', 'user', 'assistant'],
                index: _role == 'user' ? 1 : (_role == 'assistant' ? 2 : 0),
                onChanged: (i) => setState(
                  () => _role = ['system', 'user', 'assistant'][i],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PromptField extends StatelessWidget {
  const _PromptField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
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
              maxLines: maxLines,
              style: appText(14, FontWeight.w400, p.textPrimary, height: 1.45),
              cursorColor: p.amber,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
