import 'package:flutter/material.dart';

import '../core/store.dart';
import '../design/glass.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';
import '../design/toast.dart';

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  static const _presets = <String, (String, String)>{
    'Claude': ('https://api.anthropic.com', 'claude-sonnet-4-5'),
    'OpenAI': ('https://api.openai.com/v1', 'gpt-4o-mini'),
    'Gemini': (
      'https://generativelanguage.googleapis.com/v1beta',
      'gemini-2.5-flash',
    ),
    'DeepSeek': ('https://api.deepseek.com/v1', 'deepseek-chat'),
    'Ollama': ('http://127.0.0.1:11434', 'llama3.2'),
    '自定义': ('', ''),
  };

  late final TextEditingController _base;
  late final TextEditingController _key;
  late final TextEditingController _model;
  late String _provider;

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
    final settings = AppStore.instance.settings;
    AppStore.instance.settings = settings.copyWith(
      api: settings.api.copyWith(
        provider: _providerKey(_provider),
        baseUrl: _base.text.trim(),
        apiKey: _key.text.trim(),
        model: _model.text.trim(),
      ),
    );
    await AppStore.instance.saveSettings();
    if (!mounted) return;
    showTavernToast(context, '连接配置已保存');
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return DetailPage(
      eyebrow: 'CONNECTION',
      title: 'API 连接',
      subtitle: '密钥只保存在本机，不会上传。',
      footer: GlassPrimaryButton(
        label: '保存连接',
        icon: Icons.check_rounded,
        onTap: _save,
      ),
      children: [
        const SizedBox(height: 4),
        SettingsGroup(
          title: '服务商',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Wrap(
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
            ),
          ],
        ),
        SettingsGroup(
          title: '凭据',
          children: [
            _ConnectionField(
              label: 'API 地址',
              controller: _base,
              hint: 'https://api.openai.com/v1',
              icon: Icons.link_rounded,
            ),
            const Hairline(indent: 56),
            _ConnectionField(
              label: '密钥',
              controller: _key,
              hint: 'sk-...',
              icon: Icons.key_rounded,
              obscure: true,
            ),
            const Hairline(indent: 56),
            _ConnectionField(
              label: '模型名',
              controller: _model,
              hint: 'gpt-4o-mini',
              icon: Icons.auto_awesome_rounded,
            ),
          ],
        ),
        SettingsGroup(
          title: '说明',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Text(
                '支持 OpenAI 兼容、Claude、Gemini、DeepSeek 与本地 Ollama。'
                '修改后点击底部「保存连接」生效。',
                style: appText(
                  11.5,
                  FontWeight.w400,
                  AppPalette.of(context).textTertiary,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConnectionField extends StatelessWidget {
  const _ConnectionField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
      child: Row(
        children: [
          Icon(icon, size: 17, color: p.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              autocorrect: false,
              enableSuggestions: false,
              style: appText(13.5, FontWeight.w500, p.textPrimary),
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
