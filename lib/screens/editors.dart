import 'package:flutter/material.dart';

import '../data/demo.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';
import '../design/toast.dart';

class PersonaEditorSheet extends StatelessWidget {
  const PersonaEditorSheet({super.key, this.persona});

  final DemoPersona? persona;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final item = persona ?? demoPersonas.first;
    return SheetStage(
      title: '编辑人格',
      subtitle: '决定 {{user}} 是谁',
      heightFactor: .9,
      footer: GlassPrimaryButton(
        label: '保存人格',
        icon: Icons.check_rounded,
        onTap: () {
          showTavernToast(context, '人格已保存');
          Navigator.of(context).maybePop();
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 66,
                height: 66,
                child: Portrait(
                  initial: item.initial,
                  colors: item.colors,
                  radius: 20,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '头像与名字',
                      style: appText(14, FontWeight.w500, p.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '头像会出现在聊天与人格列表',
                      style: appText(10, FontWeight.w400, p.textTertiary),
                    ),
                    const SizedBox(height: 7),
                    const GlassPill(label: '更换头像', height: 30),
                  ],
                ),
              ),
            ],
          ),
          const _EditorField(label: '名字', value: '旅人'),
          const _EditorField(
            label: '描述',
            value: '一个在各地旅行的记录者，习惯先观察再开口。',
            maxLines: 4,
          ),
          SettingsGroup(
            title: '行为',
            children: const [
              SwitchLine(
                title: '设为默认人格',
                subtitle: '新聊天默认使用',
                value: true,
              ),
              Hairline(indent: 14),
              SegmentLine(
                title: '描述注入',
                options: ['提示词内', '作者笔记上', '深度'],
                index: 0,
              ),
              Hairline(indent: 14),
              StepperRow(
                title: '注入深度',
                value: '4',
              ),
              Hairline(indent: 14),
              SettingRow(
                icon: Icons.auto_stories_rounded,
                title: '人格世界书',
                value: '未绑定',
                iconColor: Color(0xFF8FD0BE),
                onTap: null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const HintCard(
            text: '人格描述会作为 {{persona}} 进入提示词；锁定到某个聊天后，该聊天不会跟随默认人格切换。',
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

class AuthorNoteSheet extends StatelessWidget {
  const AuthorNoteSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SheetStage(
      title: '作者笔记',
      subtitle: '只对当前聊天生效',
      heightFactor: .78,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: p.rose.withValues(alpha: .16),
        ),
        child: Icon(
          Icons.sticky_note_2_outlined,
          size: 18,
          color: p.rose,
        ),
      ),
      footer: GlassPrimaryButton(
        label: '保存笔记',
        icon: Icons.check_rounded,
        onTap: () {
          showTavernToast(context, '作者笔记已更新');
          Navigator.of(context).maybePop();
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EditorField(
            label: '内容',
            value: '保持叙事节奏，多描写环境与身体语言，避免替用户做决定。',
            maxLines: 5,
          ),
          const StepperRow(
            title: '插入间隔',
            subtitle: '每 N 条消息注入一次',
            value: '3 条',
          ),
          const _Label('位置'),
          Glass(
            radius: 16,
            blur: 18,
            shadow: false,
            padding: const EdgeInsets.all(4),
            child: Row(
              children: const [
                _EditorSegment(label: '笔记上'),
                _EditorSegment(label: '笔记下'),
                _EditorSegment(label: '深度', selected: true),
              ],
            ),
          ),
          const StepperRow(
            title: '深度',
            value: '4',
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
          const SizedBox(height: 10),
          const HintCard(
            text: '作者笔记适合放「风格指令」，不要放世界观设定；设定请写进世界书。',
            color: Color(0xFFEE9AA8),
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
