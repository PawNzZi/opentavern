import 'dart:convert';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/store.dart';
import '../data/demo.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';
import '../design/toast.dart';

class CharacterEditorPage extends StatefulWidget {
  const CharacterEditorPage({super.key, this.character});

  final DemoCharacter? character;

  @override
  State<CharacterEditorPage> createState() => _CharacterEditorPageState();
}

class _CharacterEditorPageState extends State<CharacterEditorPage> {
  late final TextEditingController _name;
  late final TextEditingController _creator;
  late final TextEditingController _version;
  late final TextEditingController _description;
  late final TextEditingController _personality;
  late final TextEditingController _scenario;
  late final TextEditingController _greeting;
  late final TextEditingController _examples;
  late final TextEditingController _system;
  late final TextEditingController _postHistory;
  late final TextEditingController _tags;
  late String _lorebook;
  String? _avatarBase64;

  DemoCharacter get _base =>
      widget.character ??
      const DemoCharacter(
        name: '',
        initial: '?',
        title: '',
        tagline: '',
        creator: '本地',
        version: '1.0',
        description: '',
        greeting: '',
        tags: [],
        lorebook: '未绑定',
        preset: '',
        chats: 0,
        tokens: '0',
        colors: [
          Color(0xFF8C4A3F),
          Color(0xFFD98E5F),
          Color(0xFF3B1E2A),
        ],
      );

  @override
  void initState() {
    super.initState();
    final c = widget.character;
    _name = TextEditingController(text: c?.name ?? '');
    _creator = TextEditingController(text: c?.creator ?? '');
    _version = TextEditingController(text: c?.version ?? '1.0');
    _description = TextEditingController(text: c?.description ?? '');
    _personality = TextEditingController(text: c?.personality ?? '');
    _scenario = TextEditingController(text: c?.scenario ?? '');
    _greeting = TextEditingController(text: c?.greeting ?? '');
    _examples = TextEditingController(text: c?.exampleDialogue ?? '');
    _system = TextEditingController(text: c?.systemPrompt ?? '');
    _postHistory = TextEditingController(
      text: c?.postHistoryInstructions ?? '',
    );
    _tags = TextEditingController(text: c?.tags.join(', ') ?? '');
    _lorebook = c?.lorebook ?? '未绑定';
    _avatarBase64 = c?.avatarBase64;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _creator,
      _version,
      _description,
      _personality,
      _scenario,
      _greeting,
      _examples,
      _system,
      _postHistory,
      _tags,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await FilePickerPlatform.instance.pickFile();
    if (file == null) return;
    final bytes = await file.readAsBytes();
    String encoded;
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 512,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      frame.image.dispose();
      codec.dispose();
      encoded = data == null
          ? base64Encode(bytes)
          : base64Encode(data.buffer.asUint8List());
    } catch (_) {
      encoded = base64Encode(bytes);
    }
    if (!mounted) return;
    setState(() => _avatarBase64 = encoded);
  }

  Future<void> _pickLorebook() async {
    final names = <String>[
      '未绑定',
      ...AppStore.instance.lorebooks.map((b) => b.name),
    ];
    final picked = await showTavernSheet<String>(
      context,
      title: '绑定世界书',
      subtitle: '${names.length - 1} 本本地世界书',
      heightFactor: .72,
      child: Builder(
        builder: (sheetContext) {
          final p = AppPalette.of(sheetContext);
          return Glass(
            radius: 22,
            blur: 22,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < names.length; i++) ...[
                  SettingRow(
                    icon: names[i] == '未绑定'
                        ? Icons.link_off_rounded
                        : Icons.auto_stories_rounded,
                    title: names[i],
                    iconColor: names[i] == _lorebook
                        ? p.amber
                        : p.textTertiary,
                    chevron: false,
                    trailing: names[i] == _lorebook
                        ? Icon(Icons.check_rounded, size: 17, color: p.amber)
                        : null,
                    onTap: () => Navigator.of(sheetContext).pop(names[i]),
                  ),
                  if (i != names.length - 1) const Hairline(indent: 56),
                ],
              ],
            ),
          );
        },
      ),
    );
    if (picked != null && mounted) setState(() => _lorebook = picked);
  }

  Future<void> _save() async {
    final name = _name.text.trim().isEmpty ? '未命名' : _name.text.trim();
    final updated = _base.copyWith(
      name: name,
      title: _base.title,
      tagline: _description.text.trim().split('\n').first,
      creator: _creator.text.trim().isEmpty ? '本地' : _creator.text.trim(),
      version: _version.text.trim().isEmpty ? '1.0' : _version.text.trim(),
      description: _description.text.trim(),
      personality: _personality.text.trim(),
      scenario: _scenario.text.trim(),
      greeting: _greeting.text.trim(),
      exampleDialogue: _examples.text.trim(),
      systemPrompt: _system.text.trim(),
      postHistoryInstructions: _postHistory.text.trim(),
      tags: _tags.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      lorebook: _lorebook,
      avatarBase64: _avatarBase64,
    );
    if (widget.character == null) {
      await AppStore.instance.addCharacter(updated);
    } else {
      await AppStore.instance.replaceCharacter(
        updated,
        previousName: widget.character!.name,
      );
    }
    if (!mounted) return;
    showTavernToast(context, '角色已保存');
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final c = _base;
    return DetailPage(
      eyebrow: 'CHARACTER EDITOR',
      title: '编辑角色',
      subtitle: '所有字段都会保存到本地，并参与下一次 Prompt 组装。',
      footer: GlassPrimaryButton(
        label: '保存角色',
        icon: Icons.check_rounded,
        onTap: _save,
      ),
      children: [
        const SizedBox(height: 16),
        Glass(
          radius: 24,
          blur: 24,
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Portrait(
                  initial: c.initial,
                  colors: c.colors,
                  avatarBase64: c.avatarBase64,
                  radius: 18,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '角色立绘',
                      style: appText(14, FontWeight.w500, p.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '导入 PNG 时会保留原始头像；也可以从文件选择新头像。',
                      style: appText(9.5, FontWeight.w400, p.textTertiary),
                    ),
                    const SizedBox(height: 8),
                    GlassPill(
                      label: '更换头像',
                      height: 30,
                      onTap: _pickAvatar,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _EditField(label: '名字', controller: _name),
        _EditField(label: '作者', controller: _creator),
        _EditField(label: '版本', controller: _version),
        _EditField(label: '标签（逗号分隔）', controller: _tags),
        SettingRow(
          icon: Icons.auto_stories_outlined,
          title: '绑定世界书',
          value: _lorebook,
          iconColor: p.amber,
          onTap: _pickLorebook,
        ),
        const SectionLabel('人设'),
        _EditField(
          label: '描述（Description）',
          controller: _description,
          maxLines: 6,
        ),
        _EditField(
          label: '性格（Personality）',
          controller: _personality,
          maxLines: 4,
        ),
        _EditField(
          label: '场景（Scenario）',
          controller: _scenario,
          maxLines: 4,
        ),
        const SectionLabel('开场'),
        _EditField(
          label: '开场白（First message）',
          controller: _greeting,
          maxLines: 5,
        ),
        const SectionLabel('示例对话'),
        _EditField(
          label: 'Example messages',
          controller: _examples,
          maxLines: 8,
        ),
        const SectionLabel('高级'),
        _EditField(
          label: '主提示词覆盖',
          controller: _system,
          maxLines: 5,
        ),
        _EditField(
          label: 'Post-History Instructions',
          controller: _postHistory,
          maxLines: 4,
        ),
        const SizedBox(height: 8),
        Text(
          '角色专属提示词会覆盖全局预设；留空则跟随预设。',
          style: appText(10.5, FontWeight.w400, p.textTertiary, height: 1.45),
        ),
        const SizedBox(height: 18),
        const HintCard(
          text: '编辑角色卡不会自动改写历史聊天。若要让新设定立即生效，请开始一个新对话。',
        ),
      ],
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
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
      padding: const EdgeInsets.only(top: 12),
      child: Glass(
        radius: 18,
        blur: 18,
        shadow: false,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: appText(10.5, FontWeight.w500, p.textTertiary),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: controller,
              maxLines: maxLines,
              minLines: 1,
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
