import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import '../core/store.dart';
import '../data/demo.dart';
import '../design/glass.dart';
import '../design/routes.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';
import '../design/toast.dart';
import 'prompts.dart';

class PresetsPage extends StatefulWidget {
  const PresetsPage({super.key});

  @override
  State<PresetsPage> createState() => _PresetsPageState();
}

class _PresetsPageState extends State<PresetsPage> {
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

  Future<void> _create() async {
    final source = AppStore.instance.activePreset;
    final preset = PromptPreset(
      id: 'preset-${DateTime.now().microsecondsSinceEpoch}',
      name: '新预设 ${AppStore.instance.presets.length + 1}',
      mainPrompt: source?.mainPrompt ?? '',
      entries: [
        for (final entry in source?.entries ?? const <PromptEntry>[])
          PromptEntry(
            id: 'entry-${DateTime.now().microsecondsSinceEpoch}-${entry.order}',
            name: entry.name,
            content: entry.content,
            role: entry.role,
            enabled: entry.enabled,
            order: entry.order,
          ),
      ],
    );
    await AppStore.instance.addPreset(preset);
    if (!mounted) return;
    setState(() {});
    await openGlassPage(context, _PresetEditPage(preset: preset));
    if (mounted) setState(() {});
  }

  Future<void> _select(PromptPreset preset) async {
    await AppStore.instance.setActivePreset(preset.id);
    if (!mounted) return;
    showTavernToast(context, '已应用 ${preset.name}');
    setState(() {});
  }

  Future<void> _edit(PromptPreset preset) async {
    await openGlassPage(context, _PresetEditPage(preset: preset));
    if (mounted) setState(() {});
  }

  Future<void> _delete(PromptPreset preset) async {
    final deleted = await confirmAndDeletePreset(context, preset);
    if (!mounted || !deleted) return;
    showTavernToast(context, '已删除预设 ${preset.name}');
    setState(() {});
  }

  Future<void> _export(PromptPreset preset) async {
    final data = const JsonEncoder.withIndent('  ').convert(preset.toJson());
    final safe = preset.name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    final uri = await FilePickerPlatform.instance.saveFile(
      fileName: '${safe.isEmpty ? 'preset' : safe}.json',
      bytes: Uint8List.fromList(utf8.encode(data)),
      mimeType: 'application/json',
      dialogTitle: '导出预设 JSON',
    );
    if (!mounted) return;
    showTavernToast(context, uri == null ? '已取消导出' : '预设已导出');
  }

  Future<void> _import() async {
    final files = await FilePickerPlatform.instance.pickFiles(
      dialogTitle: '导入预设 JSON（可多选）',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (files.isEmpty) return;
    var imported = 0;
    final failures = <String>[];
    final reservedNames = <String>{};
    for (final file in files) {
      try {
        final bytes = await file.readAsBytes();
        final raw = utf8.decode(bytes, allowMalformed: true);
        final fallbackName = file.name.replaceAll(RegExp(r'\.json$', caseSensitive: false), '');
        final parsed = presetsFromJson(jsonDecode(raw), fallbackName: fallbackName);
        if (parsed.isEmpty) {
          failures.add('${file.name}（不是有效的预设 JSON）');
          continue;
        }
        for (final preset in parsed) {
          preset.name = uniquePresetName(preset.name, reservedNames);
          reservedNames.add(preset.name);
          await AppStore.instance.addPreset(preset);
          imported++;
        }
      } catch (_) {
        failures.add('${file.name}（解析失败）');
      }
    }
    if (!mounted) return;
    setState(() {});
    showTavernToast(
      context,
      failures.isEmpty
          ? '已导入 $imported 个预设'
          : '导入 $imported 个，失败 ${failures.length} 个',
    );
    if (failures.isNotEmpty) {
      await AppStore.instance.logImportFailures(failures, source: '预设导入');
      if (!mounted) return;
      await showImportFailures(context, failures);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final presets = AppStore.instance.presets;
    final active = AppStore.instance.activePreset;
    return DetailPage(
      eyebrow: 'PRESETS',
      title: '预设',
      subtitle: '主提示词、附加条目与采样参数，一起版本化。',
      footer: GlassPrimaryButton(
        label: '新建预设',
        icon: Icons.add_rounded,
        onTap: _create,
      ),
      children: [
        const SizedBox(height: 18),
        if (active != null)
          Glass(
            radius: 24,
            blur: 26,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [
                        p.amber.withValues(alpha: .8),
                        p.rose.withValues(alpha: .6),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.layers_rounded,
                    size: 21,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        active.name,
                        style: appText(16, FontWeight.w600, p.textPrimary),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '温度 ${active.temperature.toStringAsFixed(2)} · 最大 ${active.maxTokens} tokens · ${active.entries.length} 条附加提示词',
                        style: appText(10.5, FontWeight.w400, p.textTertiary),
                      ),
                    ],
                  ),
                ),
                const TagBadge('当前'),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            GlassPill(
              label: '导入预设',
              icon: Icons.file_download_outlined,
              height: 32,
              onTap: _import,
            ),
            const SizedBox(width: 8),
            GlassPill(
              label: '编辑当前',
              icon: Icons.tune_rounded,
              height: 32,
              onTap: active == null ? null : () => _edit(active),
            ),
            const Spacer(),
            Text(
              '${presets.length} 个',
              style: appText(11, FontWeight.w400, p.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SettingsGroup(
          title: '我的预设',
          children: [
            for (var i = 0; i < presets.length; i++) ...[
              SettingRow(
                icon: Icons.layers_outlined,
                title: presets[i].name,
                subtitle:
                    '温度 ${presets[i].temperature.toStringAsFixed(2)} · 最大 ${presets[i].maxTokens} tokens · ${presets[i].entries.length} 条附加提示词',
                value: presets[i].id == AppStore.instance.activePresetId
                    ? '当前'
                    : null,
                iconColor: presets[i].id == AppStore.instance.activePresetId
                    ? p.amber
                    : p.textTertiary,
                chevron: false,
                onTap: () => _select(presets[i]),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GlassCircleButton(
                      icon: Icons.edit_outlined,
                      size: 28,
                      iconSize: 14,
                      blur: 0,
                      onTap: () => _edit(presets[i]),
                    ),
                    const SizedBox(width: 4),
                    GlassCircleButton(
                      icon: Icons.ios_share_rounded,
                      size: 28,
                      iconSize: 14,
                      blur: 0,
                      onTap: () => _export(presets[i]),
                    ),
                    const SizedBox(width: 4),
                    GlassCircleButton(
                      icon: Icons.delete_outline_rounded,
                      size: 28,
                      iconSize: 14,
                      blur: 0,
                      iconColor: p.danger,
                      onTap: () => _delete(presets[i]),
                    ),
                  ],
                ),
              ),
              if (i != presets.length - 1) const Hairline(indent: 56),
            ],
            if (presets.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                child: Text(
                  '还没有预设，点下方「新建预设」或导入 JSON。',
                  style: appText(12, FontWeight.w400, p.textTertiary),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '预设只影响 Prompt 组装与采样参数，不会改写角色卡本身。'
          '角色可以在角色编辑器里单独绑定某个预设。',
          style: appText(10.5, FontWeight.w400, p.textTertiary, height: 1.5),
        ),
      ],
    );
  }
}

/// 预设详情编辑页：名称、温度、maxTokens，以及进入提示词管理器。
class _PresetEditPage extends StatefulWidget {
  const _PresetEditPage({required this.preset});

  final PromptPreset preset;

  @override
  State<_PresetEditPage> createState() => _PresetEditPageState();
}

class _PresetEditPageState extends State<_PresetEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _tokens;
  late double _temperature;

  PromptPreset get _preset => widget.preset;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: _preset.name);
    _tokens = TextEditingController(text: '${_preset.maxTokens}');
    _temperature = _preset.temperature.clamp(0.0, 2.0).toDouble();
  }

  @override
  void dispose() {
    _name.dispose();
    _tokens.dispose();
    super.dispose();
  }

  Future<void> _openManager() async {
    await openGlassPage(context, PromptManagerPage(preset: _preset));
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final name = _name.text.trim().isEmpty ? _preset.name : _name.text.trim();
    final tokens = int.tryParse(_tokens.text.trim());
    if (tokens == null || tokens <= 0) {
      showTavernToast(context, '最大 Tokens 需要是正整数');
      return;
    }
    final duplicate = AppStore.instance.presets.any(
      (p) => p.id != _preset.id && p.name == name,
    );
    if (duplicate) {
      showTavernToast(context, '已有同名预设，请换一个名称');
      return;
    }
    final oldName = _preset.name;
    _preset
      ..name = name
      ..temperature = _temperature
      ..maxTokens = tokens.clamp(1, 131072);
    await AppStore.instance.savePresets();
    if (oldName != name && oldName.trim().isNotEmpty) {
      await renamePresetBindings(oldName, name);
    }
    if (!mounted) return;
    showTavernToast(context, '预设已保存');
    Navigator.of(context).maybePop();
  }

  Future<void> _delete() async {
    final deleted = await confirmAndDeletePreset(context, _preset);
    if (!mounted || !deleted) return;
    showTavernToast(context, '已删除预设 ${_preset.name}');
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DetailPage(
      eyebrow: 'PRESET',
      title: '编辑预设',
      subtitle: _preset.name,
      trailing: GlassCircleButton(
        icon: Icons.delete_outline_rounded,
        size: 38,
        iconSize: 17,
        blur: 0,
        iconColor: p.danger,
        onTap: _delete,
      ),
      footer: GlassPrimaryButton(
        label: '保存预设',
        icon: Icons.check_rounded,
        onTap: _save,
      ),
      children: [
        const SizedBox(height: 8),
        _PresetTextField(
          label: '预设名称',
          controller: _name,
          hint: '例如：长夜 · 叙事',
        ),
        const SizedBox(height: 16),
        SettingsGroup(
          title: '采样参数',
          children: [
            SliderLine(
              title: '温度',
              value: _temperature,
              display: _temperature.toStringAsFixed(2),
              min: 0,
              max: 2,
              divisions: 40,
              onChanged: (value) => setState(() => _temperature = value),
            ),
            const Hairline(indent: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '最大 Tokens',
                        style: appText(13.5, FontWeight.w500, p.textPrimary),
                      ),
                      const Spacer(),
                      Text(
                        'maxTokens',
                        style: appText(10.5, FontWeight.w400, p.textTertiary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _tokens,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    style: appText(14, FontWeight.w400, p.textPrimary),
                    cursorColor: p.amber,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: '512',
                      hintStyle: appText(13, FontWeight.w400, p.textTertiary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final value in const [256, 512, 1024, 2048])
                        GlassPill(
                          label: '$value',
                          height: 26,
                          selected: _tokens.text.trim() == '$value',
                          onTap: () =>
                              setState(() => _tokens.text = '$value'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsGroup(
          title: '内容',
          children: [
            SettingRow(
              icon: Icons.subject_rounded,
              title: '提示词条目与主提示词',
              subtitle: '在提示词管理器中编辑条目、顺序与主提示词',
              value: '${_preset.entries.length} 条',
              onTap: _openManager,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '温度与 maxTokens 会在使用该预设发起请求时生效；'
          '角色绑定预设后优先使用绑定预设，否则使用全局当前预设。',
          style: appText(10.5, FontWeight.w400, p.textTertiary, height: 1.5),
        ),
      ],
    );
  }
}

class _PresetTextField extends StatelessWidget {
  const _PresetTextField({
    required this.label,
    required this.controller,
    this.hint,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Glass(
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
            style: appText(14, FontWeight.w400, p.textPrimary, height: 1.45),
            cursorColor: p.amber,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: appText(13, FontWeight.w400, p.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

/// 角色卡上保存的是预设名字，所以重命名预设时同步更新角色绑定。
Future<void> renamePresetBindings(String oldName, String newName) async {
  final bound = AppStore.instance.characters
      .where((c) => c.preset == oldName)
      .toList();
  for (final character in bound) {
    await AppStore.instance.replaceCharacter(
      character.copyWith(preset: newName),
      previousName: character.name,
    );
  }
}

List<DemoCharacter> _charactersBoundTo(PromptPreset preset) {
  return AppStore.instance.characters
      .where(
        (c) =>
            c.preset.trim().isNotEmpty &&
            (c.preset == preset.name || c.preset == preset.id),
      )
      .toList();
}

Future<void> _clearPresetBindings(PromptPreset preset) async {
  final bound = _charactersBoundTo(preset);
  for (final character in bound) {
    await AppStore.instance.replaceCharacter(
      character.copyWith(preset: ''),
      previousName: character.name,
    );
  }
}

/// 删除确认统一入口：至少保留一个预设，并说明当前/角色绑定的回退行为。
Future<bool> confirmAndDeletePreset(
  BuildContext context,
  PromptPreset preset,
) async {
  if (AppStore.instance.presets.length <= 1) {
    showTavernToast(context, '至少保留一个预设');
    return false;
  }
  final isActive = preset.id == AppStore.instance.activePresetId;
  final boundCount = _charactersBoundTo(preset).length;
  final buffer = StringBuffer('确定删除预设「${preset.name}」？');
  if (isActive) buffer.write('\n这是当前预设，删除后会自动切换到其他预设。');
  if (boundCount > 0) {
    buffer.write('\n有 $boundCount 个角色绑定此预设，删除后将恢复为跟随全局预设。');
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('删除预设'),
      content: Text(buffer.toString()),
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
  if (ok != true) return false;
  await _clearPresetBindings(preset);
  await AppStore.instance.deletePreset(preset.id);
  return true;
}

// ---------------------------------------------------------------------------
// 预设 JSON 导入解析
//
// 同时兼容本应用的 PromptPreset.toJson（entries / mainPrompt / maxTokens）
// 与 SillyTavern 风格对象（temp / max_tokens / main_prompt / prompts），
// 也接受数组或 {"presets": [...]} 集合。
// ---------------------------------------------------------------------------

const Set<String> _presetKeys = {
  'entries',
  'prompts',
  'mainPrompt',
  'main_prompt',
  'temperature',
  'temp',
  'maxTokens',
  'max_tokens',
  'max_length',
  'openai_max_tokens',
  'max_new_tokens',
  'amount_gen',
};

/// SillyTavern 提示词管理器里的内置/标记条目，导入时跳过以免与本地段落重复。
const Set<String> _builtInPromptIds = {
  'main',
  'worldInfoBefore',
  'worldInfoAfter',
  'charDescription',
  'charPersonality',
  'scenario',
  'dialogueExamples',
  'chatHistory',
  'jailbreak',
  'authorsNote',
  'summary',
  'nsfw',
  'enhanceDefinitions',
  'vectorsMemory',
  'personaDescription',
};

int _presetIdSeq = 0;

String _newPresetId() {
  _presetIdSeq++;
  return 'preset-${DateTime.now().microsecondsSinceEpoch}-$_presetIdSeq';
}

String _newEntryId() {
  _presetIdSeq++;
  return 'entry-${DateTime.now().microsecondsSinceEpoch}-$_presetIdSeq';
}

String _firstString(List<Object?> values) {
  for (final value in values) {
    if (value is String) return value;
  }
  return '';
}

num? _firstNum(List<Object?> values) {
  for (final value in values) {
    if (value is num) return value;
    if (value is String) {
      final parsed = num.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return null;
}

String _normalizeRole(Object? value) {
  if (value is num) {
    return switch (value.toInt()) {
      1 => 'user',
      2 => 'assistant',
      _ => 'system',
    };
  }
  final role = value?.toString().trim().toLowerCase() ?? '';
  if (role == 'system' || role == 'user' || role == 'assistant') return role;
  if (role == 'human') return 'user';
  if (role == 'ai' || role == 'bot') return 'assistant';
  return 'system';
}

List<PromptPreset> presetsFromJson(Object? decoded, {String fallbackName = ''}) {
  final out = <PromptPreset>[];
  void visit(Object? node, String fallback) {
    if (node is List) {
      for (var i = 0; i < node.length; i++) {
        visit(node[i], node.length > 1 ? '$fallback ${i + 1}' : fallback);
      }
      return;
    }
    if (node is! Map) return;
    final json = Map<String, dynamic>.from(node);
    final nested = json['presets'];
    if (nested is List) {
      visit(nested, fallback);
      return;
    }
    if (nested is Map) {
      for (final item in nested.entries) {
        final value = item.value;
        if (value is! Map) continue;
        final copy = Map<String, dynamic>.from(value);
        copy.putIfAbsent('name', () => item.key.toString());
        visit(copy, fallback);
      }
      return;
    }
    if (!json.keys.any(_presetKeys.contains)) return;
    out.add(_presetFromMap(json, fallback));
  }

  visit(decoded, fallbackName.trim());
  return out;
}

PromptPreset _presetFromMap(Map<String, dynamic> json, String fallbackName) {
  var name = _firstString([
    json['name'],
    json['preset_name'],
    json['presetName'],
    json['title'],
  ]).trim();
  if (name.isEmpty) name = fallbackName.trim();

  var mainPrompt =
      _firstString([json['mainPrompt'], json['main_prompt']]).trim();
  final entries = <PromptEntry>[];

  final rawEntries = json['entries'];
  if (rawEntries is List) {
    var index = 0;
    for (final item in rawEntries.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      index++;
      final entryName = _firstString([map['name'], map['title']]).trim();
      entries.add(
        PromptEntry(
          id: _newEntryId(),
          name: entryName.isEmpty ? '导入条目 $index' : entryName,
          content: _firstString([map['content'], map['prompt']]),
          role: _normalizeRole(map['role']),
          enabled: map['enabled'] != false,
          order: (map['order'] as num?)?.toInt() ?? index * 10,
        ),
      );
    }
  } else {
    final prompts = json['prompts'];
    if (prompts is List) {
      var index = 0;
      for (final item in prompts.whereType<Map>()) {
        final map = Map<String, dynamic>.from(item);
        if (map['marker'] == true) continue;
        final content =
            _firstString([map['content'], map['prompt'], map['value']]).trim();
        if (content.isEmpty) continue;
        final identifier =
            _firstString([map['identifier'], map['id']]).trim();
        if (identifier == 'main') {
          if (mainPrompt.isEmpty) mainPrompt = content;
          continue;
        }
        if (_builtInPromptIds.contains(identifier)) continue;
        index++;
        final entryName = _firstString([map['name'], map['title']]).trim();
        entries.add(
          PromptEntry(
            id: _newEntryId(),
            name: entryName.isEmpty
                ? (identifier.isEmpty ? '导入条目 $index' : identifier)
                : entryName,
            content: content,
            role: _normalizeRole(map['role']),
            enabled: map['enabled'] != false,
            order: index * 10,
          ),
        );
      }
    }
  }

  final temperature =
      (_firstNum([json['temperature'], json['temp']]) ?? .85)
          .toDouble()
          .clamp(0.0, 2.0)
          .toDouble();
  final maxTokens =
      (_firstNum([
                json['maxTokens'],
                json['max_tokens'],
                json['max_new_tokens'],
                json['openai_max_tokens'],
                json['amount_gen'],
                json['max_length'],
              ]) ??
              512)
          .toInt()
          .clamp(1, 131072)
          .toInt();

  return PromptPreset(
    id: _newPresetId(),
    name: name.isEmpty ? '导入预设' : name,
    mainPrompt: mainPrompt,
    entries: entries,
    temperature: temperature,
    maxTokens: maxTokens,
  );
}

/// 绑定使用预设名，所以导入时保证名字不重复。
String uniquePresetName(String raw, Set<String> reserved) {
  final base = raw.trim().isEmpty ? '导入预设' : raw.trim();
  var name = base;
  var index = 2;
  while (reserved.contains(name) ||
      AppStore.instance.presets.any((p) => p.name == name)) {
    name = '$base ($index)';
    index++;
  }
  return name;
}
