import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';

import '../core/store.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/theme.dart';
import '../design/toast.dart';

class ConnectSheetScreen extends StatefulWidget {
  const ConnectSheetScreen({super.key});

  @override
  State<ConnectSheetScreen> createState() => _ConnectSheetScreenState();
}

class _ConnectSheetScreenState extends State<ConnectSheetScreen> {
  late final TextEditingController _base;
  late final TextEditingController _key;
  late final TextEditingController _model;
  late String _provider;

  static const _presets = <String, (String, String)>{
    'Claude': ('https://api.anthropic.com', 'claude-sonnet-4-5'),
    'OpenAI': ('https://api.openai.com/v1', 'gpt-4o-mini'),
    'Gemini': (
      'https://generativelanguage.googleapis.com/v1beta',
      'gemini-2.5-flash'
    ),
    'DeepSeek': ('https://api.deepseek.com/v1', 'deepseek-chat'),
    'Ollama': ('http://127.0.0.1:11434', 'llama3.2'),
    '自定义': ('', ''),
  };

  @override
  void initState() {
    super.initState();
    final api = AppStore.instance.settings.api;
    _base = TextEditingController(text: api.baseUrl);
    _key = TextEditingController(text: api.apiKey);
    _model = TextEditingController(text: api.model);
    _provider = _labelFor(api.provider);
  }

  @override
  void dispose() {
    _base.dispose();
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  String _labelFor(String provider) {
    switch (provider) {
      case 'anthropic':
        return 'Claude';
      case 'gemini':
        return 'Gemini';
      case 'ollama':
        return 'Ollama';
      case 'deepseek':
        return 'DeepSeek';
      case 'openai':
        return 'OpenAI';
      default:
        return '自定义';
    }
  }

  String _providerKey(String label) {
    switch (label) {
      case 'Claude':
        return 'anthropic';
      case 'Gemini':
        return 'gemini';
      case 'Ollama':
        return 'ollama';
      case 'DeepSeek':
        return 'deepseek';
      case 'OpenAI':
        return 'openai';
      default:
        return 'custom';
    }
  }

  void _selectProvider(String label) {
    setState(() {
      _provider = label;
      final preset = _presets[label];
      if (preset != null && preset.$1.isNotEmpty) {
        _base.text = preset.$1;
        _model.text = preset.$2;
      }
    });
  }

  Future<void> _save() async {
    final api = AppStore.instance.settings.api.copyWith(
      provider: _providerKey(_provider),
      baseUrl: _base.text.trim(),
      apiKey: _key.text.trim(),
      model: _model.text.trim(),
    );
    AppStore.instance.settings =
        AppStore.instance.settings.copyWith(api: api);
    await AppStore.instance.saveSettings();
    if (!mounted) return;
    showTavernToast(context, '连接配置已保存');
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SheetStage(
      title: '模型连接',
      subtitle: '支持 OpenAI 兼容、Claude、Gemini 与本地 Ollama',
      heightFactor: .92,
      footer: GlassPrimaryButton(
        label: '保存连接',
        icon: Icons.check_rounded,
        onTap: _save,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel('服务'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in _presets.keys)
                GlassPill(
                  label: label,
                  selected: _provider == label,
                  onTap: () => _selectProvider(label),
                ),
            ],
          ),
          const _FieldLabel('凭据'),
          _ApiField(
            label: 'API 地址',
            controller: _base,
            icon: Icons.link_rounded,
            hint: 'https://api.openai.com/v1',
          ),
          const SizedBox(height: 10),
          _ApiField(
            label: '密钥',
            controller: _key,
            icon: Icons.key_rounded,
            hint: 'sk-...',
            obscure: true,
          ),
          const _FieldLabel('模型'),
          _ApiField(
            label: '模型名',
            controller: _model,
            icon: Icons.auto_awesome_rounded,
            hint: 'gpt-4o-mini',
          ),
          const SizedBox(height: 18),
          const _ToggleRow(
            title: '流式输出',
            subtitle: '逐字显示回复，可随时停止',
            value: true,
          ),
          const SizedBox(height: 2),
          const _ToggleRow(
            title: '自动重连',
            subtitle: '网络恢复后继续未完成的请求',
            value: true,
          ),
          const SizedBox(height: 8),
          Text(
            '密钥只保存在本机的应用数据目录，不会上传。',
            style: appText(10, FontWeight.w400, p.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _ApiField extends StatelessWidget {
  const _ApiField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.hint,
    this.obscure = false,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Glass(
      radius: 16,
      blur: 18,
      shadow: false,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: p.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              autocorrect: false,
              enableSuggestions: false,
              style: appText(13, FontWeight.w500, p.textPrimary),
              cursorColor: p.amber,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                labelText: label,
                labelStyle: appText(11, FontWeight.w400, p.textTertiary),
                hintText: hint,
                hintStyle: appText(12, FontWeight.w400, p.textTertiary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ImportSheetScreen extends StatelessWidget {
  const ImportSheetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SheetStage(
      title: '导入角色',
      subtitle: '支持 SillyTavern 角色卡、世界书与聊天记录',
      heightFactor: .72,
      footer: GlassPrimaryButton(
        label: '选择角色卡文件',
        icon: Icons.folder_open_rounded,
        onTap: () async {
          final file = await FilePickerPlatform.instance.pickFile();
          if (file == null) return;
          final bytes = await file.readAsBytes();
          final card = await AppStore.instance.importCard(bytes, file.name);
          if (!context.mounted) return;
          if (card == null) {
            showTavernToast(context, '不是有效的 SillyTavern 角色卡');
            return;
          }
          showTavernToast(context, '已导入 ${card.name}');
          Navigator.of(context).maybePop();
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 190,
            child: CustomPaint(
              painter: _DashedRRectPainter(
                color: p.textTertiary.withValues(alpha: .55),
                radius: 22,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: p.amber.withValues(alpha: .14),
                        border: Border.all(
                          color: p.amber.withValues(alpha: .25),
                          width: .8,
                        ),
                      ),
                      child: Icon(
                        Icons.upload_file_rounded,
                        size: 24,
                        color: p.amber,
                      ),
                    ),
                    const SizedBox(height: 13),
                    Text(
                      '拖入文件，或从下方选择',
                      style: appText(14, FontWeight.w500, p.textPrimary),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'PNG · JSON · CHARX · 最大 100 MB',
                      style: appText(11, FontWeight.w400, p.textTertiary),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(
                child: _ImportOption(
                  icon: Icons.folder_rounded,
                  label: '文件',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _ImportOption(
                  icon: Icons.photo_library_rounded,
                  label: '相册',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _ImportOption(
                  icon: Icons.link_rounded,
                  label: '链接',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '最近导入',
            style: appText(11.5, FontWeight.w600, p.textTertiary, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Glass(
            radius: 18,
            blur: 18,
            shadow: false,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8C4A3F), Color(0xFF3B1E2A)],
                    ),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seraphina.png',
                        style: appText(13, FontWeight.w500, p.textPrimary),
                      ),
                      Text(
                        '2 天前 · 24 条世界书',
                        style: appText(10, FontWeight.w400, p.textTertiary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.check_circle_rounded, size: 16, color: p.sage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LoreEntrySheetScreen extends StatelessWidget {
  const LoreEntrySheetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SheetStage(
      title: '编辑条目',
      subtitle: 'Eldoria 王国设定',
      heightFactor: .95,
      footer: GlassPrimaryButton(
        label: '保存条目',
        onTap: () {
          showTavernToast(context, '条目已保存');
          Navigator.of(context).maybePop();
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetField(
            label: '标题',
            value: '王都的雨',
            icon: Icons.title_rounded,
          ),
          const _FieldLabel('关键词'),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: const [
              GlassPill(label: '王都', height: 32),
              GlassPill(label: '雨', height: 32),
              GlassPill(label: '预言', height: 32),
              GlassPill(
                label: '添加',
                icon: Icons.add_rounded,
                height: 32,
              ),
            ],
          ),
          const _FieldLabel('内容'),
          Glass(
            radius: 16,
            blur: 18,
            shadow: false,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Text(
              '王都的雨通常持续三天。占星师认为雨水会冲刷星轨，因此雨季不做预言；'
              '平民则相信，雨夜里说的话会被城墙记住。',
              style: appText(
                13,
                FontWeight.w400,
                p.textPrimary,
                height: 1.55,
              ),
            ),
          ),
          const _FieldLabel('插入位置'),
          Glass(
            radius: 16,
            blur: 18,
            shadow: false,
            padding: const EdgeInsets.all(4),
            child: Row(
              children: const [
                _Segment(label: '角色前', selected: true),
                _Segment(label: '角色后'),
                _Segment(label: '深度'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  '注入深度',
                  style: appText(13, FontWeight.w500, p.textPrimary),
                ),
              ),
              const _Stepper(value: '4'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  '触发概率',
                  style: appText(13, FontWeight.w500, p.textPrimary),
                ),
              ),
              Text(
                '100%',
                style: appText(12.5, FontWeight.w600, p.amber),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: p.amber,
              inactiveTrackColor: p.textTertiary.withValues(alpha: .25),
              thumbColor: p.amber,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(value: 1, onChanged: (_) {}),
          ),
          const _ToggleRow(
            title: '常驻条目',
            subtitle: '不依赖关键词，始终进入上下文',
            value: false,
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 15, 2, 7),
      child: Text(
        text,
        style: appText(
          11,
          FontWeight.w600,
          p.textTertiary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.label,
    required this.value,
    required this.icon,
    this.trailing,
  });

  final String label;
  final String value;
  final IconData icon;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            style: appText(10.5, FontWeight.w500, p.textTertiary),
          ),
        ),
        Glass(
          radius: 15,
          blur: 18,
          shadow: false,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                Icon(icon, size: 15, color: p.textTertiary),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appText(13.5, FontWeight.w400, p.textPrimary),
                  ),
                ),
                if (trailing != null)
                  Icon(trailing, size: 15, color: p.textTertiary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final String title;
  final String subtitle;
  final bool value;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: appText(13.5, FontWeight.w500, p.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: appText(10.5, FontWeight.w400, p.textTertiary),
                ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 26,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: value
                  ? p.amber.withValues(alpha: .85)
                  : p.textTertiary.withValues(alpha: .22),
            ),
            child: Align(
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, this.selected = false});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Expanded(
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? p.amber.withValues(alpha: .18) : Colors.transparent,
          border: selected
              ? Border.all(color: p.amber.withValues(alpha: .3), width: .8)
              : null,
        ),
        child: Text(
          label,
          style: appText(
            12.5,
            selected ? FontWeight.w600 : FontWeight.w400,
            selected ? p.amber : p.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Glass(
      radius: 12,
      blur: 14,
      shadow: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            height: 34,
            child: Icon(
              Icons.remove_rounded,
              size: 15,
              color: p.textSecondary,
            ),
          ),
          SizedBox(
            width: 22,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: appText(13, FontWeight.w600, p.textPrimary),
            ),
          ),
          SizedBox(
            width: 30,
            height: 34,
            child: Icon(Icons.add_rounded, size: 15, color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ImportOption extends StatelessWidget {
  const _ImportOption({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Glass(
      radius: 18,
      blur: 18,
      shadow: false,
      padding: const EdgeInsets.symmetric(vertical: 13),
      onTap: () {},
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 21, color: p.textPrimary),
            const SizedBox(height: 7),
            Text(
              label,
              style: appText(11.5, FontWeight.w500, p.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + 6, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 13;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}
