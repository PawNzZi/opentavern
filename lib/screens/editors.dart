import 'package:flutter/material.dart';

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

class RegexEditorSheet extends StatelessWidget {
  const RegexEditorSheet({super.key, this.script});

  final DemoRegex? script;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final item = script ?? demoRegexes.first;
    return SheetStage(
      title: '编辑正则',
      subtitle: '确定性的文本改写',
      heightFactor: .95,
      footer: GlassPrimaryButton(
        label: '保存正则',
        icon: Icons.check_rounded,
        onTap: () {
          showTavernToast(context, '正则已保存');
          Navigator.of(context).maybePop();
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EditorField(label: '名称', value: item.name),
          _EditorField(
            label: '查找（支持 /pattern/flags）',
            value: item.find,
            mono: true,
          ),
          _EditorField(
            label: '替换为',
            value: item.replace,
            mono: true,
          ),
          const _Label('作用位置'),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: const [
              GlassPill(label: '用户输入', height: 32, selected: true),
              GlassPill(label: 'AI 输出', height: 32, selected: true),
              GlassPill(label: '斜杠命令', height: 32),
              GlassPill(label: '世界书', height: 32),
              GlassPill(label: '推理', height: 32),
              GlassPill(label: '仅显示', height: 32),
            ],
          ),
          const _Label('作用域'),
          Glass(
            radius: 16,
            blur: 18,
            shadow: false,
            padding: const EdgeInsets.all(4),
            child: Row(
              children: const [
                _EditorSegment(label: '全局', selected: true),
                _EditorSegment(label: '角色'),
                _EditorSegment(label: '预设'),
              ],
            ),
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
                title: '仅影响显示',
                subtitle: '不改写发给模型的内容',
                value: false,
              ),
              Hairline(indent: 14),
              SwitchLine(
                title: '仅影响 Prompt',
                subtitle: '聊天里仍显示原文',
                value: false,
              ),
              Hairline(indent: 14),
              SwitchLine(
                title: '编辑后重新执行',
                value: true,
              ),
            ],
          ),
          const _Label('测试'),
          Glass(
            radius: 16,
            blur: 18,
            shadow: false,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '输入示例',
                  style: appText(9.5, FontWeight.w500, p.textTertiary),
                ),
                const SizedBox(height: 4),
                Text(
                  '王都的雨下了三天。\n\n\n\n占星师没有出门。',
                  style: appText(
                    12,
                    FontWeight.w400,
                    p.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Hairline(),
                const SizedBox(height: 8),
                Text(
                  '输出',
                  style: appText(9.5, FontWeight.w500, p.textTertiary),
                ),
                const SizedBox(height: 4),
                Text(
                  '王都的雨下了三天。\n\n占星师没有出门。',
                  style: appText(
                    12,
                    FontWeight.w400,
                    p.textPrimary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              GlassPill(
                label: '运行测试',
                icon: Icons.play_arrow_rounded,
                height: 34,
                selected: true,
              ),
              SizedBox(width: 8),
              GlassPill(label: '从模板新建', height: 34),
            ],
          ),
        ],
      ),
    );
  }
}

class QuickReplyEditorSheet extends StatelessWidget {
  const QuickReplyEditorSheet({super.key, this.quickSet});

  final DemoQuickSet? quickSet;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final item = quickSet ?? demoQuickSets.first;
    return SheetStage(
      title: '编辑快捷回复',
      subtitle: '${item.buttons.length} 个按钮',
      heightFactor: .9,
      footer: GlassPrimaryButton(
        label: '保存集合',
        icon: Icons.check_rounded,
        onTap: () {
          showTavernToast(context, '快捷回复已保存');
          Navigator.of(context).maybePop();
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EditorField(label: '集合名称', value: item.name),
          _EditorField(
            label: '说明',
            value: item.description,
          ),
          const _Label('按钮'),
          Glass(
            radius: 22,
            blur: 22,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < item.buttons.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 9, 10, 9),
                    child: Row(
                      children: [
                        Icon(
                          Icons.drag_indicator_rounded,
                          size: 16,
                          color: p.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9),
                            color: p.amber.withValues(alpha: .14),
                          ),
                          child: Icon(
                            Icons.bolt_rounded,
                            size: 15,
                            color: p.amber,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.buttons[i],
                                style: appText(
                                  13,
                                  FontWeight.w500,
                                  p.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '/send ${item.buttons[i]}',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 9.5,
                                  color: p.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.edit_outlined,
                          size: 15,
                          color: p.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  if (i != item.buttons.length - 1) const Hairline(indent: 52),
                ],
                const Hairline(indent: 52),
                SettingRow(
                  icon: Icons.add_rounded,
                  title: '添加按钮',
                  value: '标签 + 命令',
                  iconColor: p.amber,
                  onTap: null,
                ),
              ],
            ),
          ),
          SettingsGroup(
            title: '显示与行为',
            children: const [
              SwitchLine(
                title: '显示在输入框上方',
                value: true,
              ),
              Hairline(indent: 14),
              SwitchLine(
                title: '显示在上下文菜单',
                value: false,
              ),
              Hairline(indent: 14),
              SwitchLine(
                title: '打开聊天时自动执行',
                value: false,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const HintCard(
            text: '按钮内容支持斜杠命令、STscript 与 {{宏}}。按住拖动可以排序。',
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
