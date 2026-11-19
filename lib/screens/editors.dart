import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/store.dart';
import '../data/demo.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';
import '../design/toast.dart';

class PersonaEditorSheet extends StatefulWidget {
  const PersonaEditorSheet({super.key, this.persona});
  final DemoPersona? persona;

  @override
  State<PersonaEditorSheet> createState() => _PersonaEditorSheetState();
}

class _PersonaEditorSheetState extends State<PersonaEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    final settings = AppStore.instance.settings;
    _name = TextEditingController(text: widget.persona?.name ?? settings.personaName);
    _description = TextEditingController(
      text: widget.persona?.description ?? settings.personaDescription,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim().isEmpty ? '旅人' : _name.text.trim();
    final settings = AppStore.instance.settings.copyWith(
      userName: name,
      personaName: name,
      personaDescription: _description.text.trim(),
    );
    AppStore.instance.settings = settings;
    await AppStore.instance.saveSettings();
    if (!mounted) return;
    showTavernToast(context, '人格已保存');
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SheetStage(
      title: '编辑人格',
      subtitle: '决定 {{user}} 是谁',
      heightFactor: .86,
      footer: GlassPrimaryButton(
        label: '保存人格',
        icon: Icons.check_rounded,
        onTap: _save,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Portrait(
                  initial: _name.text.isEmpty ? '旅' : _name.text.characters.first,
                  colors: const [Color(0xFF8C4A3F), Color(0xFFD98E5F), Color(0xFF3B1E2A)],
                  radius: 19,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '这个身份会出现在 Prompt 的 {{user}} 中。',
                style: appText(11, FontWeight.w400, p.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _LiveField(label: '名字', controller: _name, hint: '旅人'),
          _LiveField(
            label: '描述',
            controller: _description,
            hint: '一个在各地旅行的记录者，习惯先观察再开口。',
            maxLines: 5,
          ),
          const SizedBox(height: 10),
          Text(
            '人格保存在本机设置中，所有聊天共用。',
            style: appText(10.5, FontWeight.w400, p.textTertiary),
          ),
        ],
      ),
    );
  }
}

class RegexEditorSheet extends StatefulWidget {
  const RegexEditorSheet({super.key, this.script});
  final RegexScript? script;

  @override
  State<RegexEditorSheet> createState() => _RegexEditorSheetState();
}

class _RegexEditorSheetState extends State<RegexEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _find;
  late final TextEditingController _replace;
  late String _placement;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final s = widget.script;
    _name = TextEditingController(text: s?.name ?? '');
    _find = TextEditingController(text: s?.find ?? '');
    _replace = TextEditingController(text: s?.replace ?? '');
    _placement = s?.placement ?? 'both';
    _enabled = s?.enabled ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _find.dispose();
    _replace.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_find.text.trim().isEmpty) {
      showTavernToast(context, '请填写匹配表达式');
      return;
    }
    final script = widget.script ??
        RegexScript(
          id: 'regex-${DateTime.now().microsecondsSinceEpoch}',
          name: '新正则',
          find: '',
          replace: '',
        );
    script
      ..name = _name.text.trim().isEmpty ? '未命名正则' : _name.text.trim()
      ..find = _find.text.trim()
      ..replace = _replace.text
      ..placement = _placement
      ..enabled = _enabled;
    if (widget.script == null) AppStore.instance.regexScripts.add(script);
    await AppStore.instance.saveRegexes();
    if (!mounted) return;
    showTavernToast(context, '正则已保存');
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SheetStage(
      title: '编辑正则',
      subtitle: '确定性的文本替换',
      heightFactor: .88,
      footer: GlassPrimaryButton(
        label: '保存正则',
        icon: Icons.check_rounded,
        onTap: _save,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LiveField(label: '名称', controller: _name, hint: '去除多余空行'),
          _LiveField(
            label: '匹配表达式',
            controller: _find,
            hint: r'/\n{3,}/g',
          ),
          _LiveField(
            label: '替换为',
            controller: _replace,
            hint: r'\n\n',
          ),
          const SizedBox(height: 10),
          SettingsGroup(
            title: '作用域',
            children: [
              SwitchLine(
                title: '启用',
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
              const Hairline(indent: 14),
              SegmentLine(
                title: '应用到',
                options: const ['仅显示', '仅 Prompt', '两者'],
                index: _placement == 'display'
                    ? 0
                    : _placement == 'prompt'
                        ? 1
                        : 2,
                onChanged: (i) => setState(
                  () => _placement = ['display', 'prompt', 'both'][i],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '表达式支持 /pattern/flags 形式；无效正则会自动跳过。',
            style: appText(10.5, FontWeight.w400, p.textTertiary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class QuickReplyEditorSheet extends StatefulWidget {
  const QuickReplyEditorSheet({super.key, this.quickSet});
  final QuickReplySet? quickSet;

  @override
  State<QuickReplyEditorSheet> createState() => _QuickReplyEditorSheetState();
}

class _QuickReplyEditorSheetState extends State<QuickReplyEditorSheet> {
  late final TextEditingController _name;
  late final List<TextEditingController> _labels;
  late final List<TextEditingController> _messages;

  QuickReplySet get _set =>
      widget.quickSet ?? AppStore.instance.activeQuickSet!;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: _set.name);
    _labels = [for (final r in _set.replies) TextEditingController(text: r.label)];
    _messages = [for (final r in _set.replies) TextEditingController(text: r.message)];
  }

  @override
  void dispose() {
    _name.dispose();
    for (final c in _labels) c.dispose();
    for (final c in _messages) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    _set.name = _name.text.trim().isEmpty ? '快捷回复' : _name.text.trim();
    final next = <QuickReply>[];
    for (var i = 0; i < _labels.length; i++) {
      final label = _labels[i].text.trim();
      if (label.isEmpty) continue;
      next.add(
        QuickReply(
          id: i < _set.replies.length
              ? _set.replies[i].id
              : 'q${DateTime.now().microsecondsSinceEpoch}-$i',
          label: label,
          message: _messages[i].text.trim().isEmpty
              ? label
              : _messages[i].text.trim(),
          enabled: true,
        ),
      );
    }
    _set.replies
      ..clear()
      ..addAll(next);
    await AppStore.instance.saveQuickReplies();
    if (!mounted) return;
    showTavernToast(context, '快捷回复已保存');
    Navigator.of(context).maybePop();
  }

  void _add() {
    setState(() {
      _labels.add(TextEditingController());
      _messages.add(TextEditingController());
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SheetStage(
      title: '编辑快捷回复',
      subtitle: '按钮会显示在聊天输入框上方',
      heightFactor: .94,
      footer: GlassPrimaryButton(
        label: '保存集合',
        icon: Icons.check_rounded,
        onTap: _save,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LiveField(label: '集合名称', controller: _name, hint: '日常对话'),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('按钮', style: appText(10.5, FontWeight.w500, p.textTertiary)),
              const Spacer(),
              GlassPill(
                label: '添加',
                icon: Icons.add_rounded,
                height: 30,
                onTap: _add,
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < _labels.length; i++) ...[
            Glass(
              radius: 18,
              blur: 18,
              shadow: false,
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _labels[i],
                          style: appText(13.5, FontWeight.w500, p.textPrimary),
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: '按钮标签',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: p.textTertiary,
                        ),
                        onPressed: () {
                          setState(() {
                            _labels.removeAt(i).dispose();
                            _messages.removeAt(i).dispose();
                          });
                        },
                      ),
                    ],
                  ),
                  TextField(
                    controller: _messages[i],
                    style: appText(11, FontWeight.w400, p.textTertiary),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '发送的内容，留空则使用标签',
                      border: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 6),
          const HintCard(
            text: '快捷回复只保存在本机；输入框上方会显示当前集合的按钮。',
          ),
        ],
      ),
    );
  }
}

class PromptEditorSheet extends StatelessWidget {
  const PromptEditorSheet({super.key, this.prompt});

  final DemoPrompt? prompt;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final item = prompt ?? demoPrompts.first;
    return SheetStage(
      title: '编辑提示词',
      subtitle: item.identifier,
      heightFactor: .95,
      footer: GlassPrimaryButton(
        label: '保存条目',
        icon: Icons.check_rounded,
        onTap: () {
          showTavernToast(context, '提示词已保存');
          Navigator.of(context).maybePop();
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EditorField(label: '名称', value: item.name),
          Row(
            children: [
              const _Label('标识符'),
              const Spacer(),
              TagBadge(item.identifier, color: p.violet),
            ],
          ),
          const _Label('角色'),
          Glass(
            radius: 16,
            blur: 18,
            shadow: false,
            padding: const EdgeInsets.all(4),
            child: Row(
              children: const [
                _EditorSegment(label: '系统', selected: true),
                _EditorSegment(label: '用户'),
                _EditorSegment(label: '角色'),
              ],
            ),
          ),
          _EditorField(
            label: '内容',
            value:
                'Write {{char}}\'s next reply in a fictional chat between {{char}} and {{user}}.',
            maxLines: 6,
          ),
          const _Label('注入方式'),
          Glass(
            radius: 16,
            blur: 18,
            shadow: false,
            padding: const EdgeInsets.all(4),
            child: Row(
              children: const [
                _EditorSegment(label: '相对顺序', selected: true),
                _EditorSegment(label: '绝对深度'),
              ],
            ),
          ),
          const StepperRow(
            title: '注入深度',
            subtitle: '仅绝对深度生效',
            value: '4',
          ),
          const StepperRow(
            title: '同深度顺序',
            value: '100',
          ),
          const _Label('仅在以下生成类型启用'),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: const [
              GlassPill(label: '普通', height: 30, selected: true),
              GlassPill(label: '继续', height: 30),
              GlassPill(label: '重写', height: 30),
              GlassPill(label: '滑动', height: 30),
              GlassPill(label: '扮演', height: 30),
            ],
          ),
          SettingsGroup(
            title: '选项',
            children: const [
              SwitchLine(
                title: '启用',
                value: true,
              ),
              Hairline(indent: 14),
              SwitchLine(
                title: '禁止角色覆盖',
                subtitle: '角色卡的 system_prompt 不能改这条',
                value: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AuthorNoteSheet extends StatefulWidget {
  const AuthorNoteSheet({super.key});

  @override
  State<AuthorNoteSheet> createState() => _AuthorNoteSheetState();
}

class _AuthorNoteSheetState extends State<AuthorNoteSheet> {
  late final TextEditingController _content;

  @override
  void initState() {
    super.initState();
    _content = TextEditingController(text: AppStore.instance.settings.authorNote);
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    AppStore.instance.settings = AppStore.instance.settings.copyWith(
      authorNote: _content.text.trim(),
    );
    await AppStore.instance.saveSettings();
    if (!mounted) return;
    showTavernToast(context, '作者笔记已更新');
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SheetStage(
      title: '作者笔记',
      subtitle: '会作为系统提示注入当前对话',
      heightFactor: .76,
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
        label: '保存笔记',
        icon: Icons.check_rounded,
        onTap: _save,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LiveField(
            label: '内容',
            controller: _content,
            hint: '保持叙事节奏，多描写环境与身体语言，避免替用户做决定。',
            maxLines: 7,
          ),
          const SizedBox(height: 10),
          Text(
            '留空表示不使用作者笔记。',
            style: appText(10.5, FontWeight.w400, p.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _EditorField extends StatelessWidget {
  const _EditorField({
    required this.label,
    required this.value,
    this.maxLines = 1,
    this.mono = false,
  });

  final String label;
  final String value;
  final int maxLines;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        Glass(
          radius: 15,
          blur: 18,
          shadow: false,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: TextFormField(
            initialValue: value,
            maxLines: maxLines,
            style: mono
                ? TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    height: 1.5,
                    color: p.textPrimary,
                  )
                : appText(13.5, FontWeight.w400, p.textPrimary, height: 1.5),
            cursorColor: p.amber,
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 7),
      child: Text(
        text,
        style: appText(
          10.5,
          FontWeight.w600,
          p.textTertiary,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _EditorSegment extends StatelessWidget {
  const _EditorSegment({required this.label, this.selected = false});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Expanded(
      child: Container(
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          color: selected ? p.amber.withValues(alpha: .18) : Colors.transparent,
          border: selected
              ? Border.all(color: p.amber.withValues(alpha: .3), width: .8)
              : null,
        ),
        child: Text(
          label,
          style: appText(
            11.5,
            selected ? FontWeight.w600 : FontWeight.w400,
            selected ? p.amber : p.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _LiveField extends StatelessWidget {
  const _LiveField({
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
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
