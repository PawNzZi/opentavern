import 'dart:async';

import 'package:flutter/material.dart';

import '../core/llm.dart';
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
  Timer? _fetchDebounce;
  List<String> _models = const [];
  bool _loadingModels = false;
  String? _modelError;

  @override
  void initState() {
    super.initState();
    final api = AppStore.instance.settings.api;
    _base = TextEditingController(text: api.baseUrl);
    _key = TextEditingController(text: api.apiKey);
    _model = TextEditingController(text: api.model);
    _provider = _labelFor(api.provider);
    _base.addListener(_onEndpointChanged);
    _key.addListener(_onEndpointChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchModels();
    });
  }

  @override
  void dispose() {
    _fetchDebounce?.cancel();
    _base.removeListener(_onEndpointChanged);
    _key.removeListener(_onEndpointChanged);
    _base.dispose();
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  void _onEndpointChanged() {
    _fetchDebounce?.cancel();
    _fetchDebounce = Timer(const Duration(milliseconds: 700), () {
      if (mounted) _fetchModels();
    });
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

  bool get _needsKey => _providerKey(_provider) != 'ollama';

  Future<void> _fetchModels() async {
    if (_loadingModels) return;
    if (_needsKey && _key.text.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _models = const [];
        _modelError = '填写密钥后自动获取可用模型';
      });
      return;
    }
    final api = AppStore.instance.settings.api.copyWith(
      provider: _providerKey(_provider),
      baseUrl: _base.text.trim(),
      apiKey: _key.text.trim(),
      model: _model.text.trim(),
    );
    setState(() {
      _loadingModels = true;
      _modelError = null;
    });
    try {
      final models = await LLMClient().fetchModels(api);
      if (!mounted) return;
      final unique = models.toSet().toList()..sort();
      String? autoSelected;
      if (unique.isNotEmpty &&
          (_model.text.trim().isEmpty || !unique.contains(_model.text.trim()))) {
        final preferred = _presets[_provider]?.$2;
        autoSelected = unique.contains(preferred) ? preferred : unique.first;
      }
      setState(() {
        _models = unique;
        _loadingModels = false;
        _modelError = unique.isEmpty ? '服务商没有返回可用模型' : null;
        if (autoSelected != null) _model.text = autoSelected;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingModels = false;
        _models = const [];
        _modelError = error is LLMException ? error.message : '$error';
      });
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
      _models = const [];
      _modelError = null;
    });
    _fetchDebounce?.cancel();
    _fetchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _fetchModels();
    });
  }

  Future<void> _save() async {
    if (_model.text.trim().isEmpty) {
      showTavernToast(context, '请先选择模型');
      return;
    }
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
      resizeToAvoidBottomInset: true,
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
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.start,
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
            _ModelPicker(
              models: _models,
              value: _model.text,
              loading: _loadingModels,
              error: _modelError,
              onSelect: (value) {
                setState(() => _model.text = value);
              },
              onRefresh: _fetchModels,
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
                '填写密钥后会自动获取模型列表；修改后点击底部「保存连接」生效。',
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

class _ModelPicker extends StatelessWidget {
  const _ModelPicker({
    required this.models,
    required this.value,
    required this.loading,
    required this.error,
    required this.onSelect,
    required this.onRefresh,
  });

  final List<String> models;
  final String value;
  final bool loading;
  final String? error;
  final ValueChanged<String> onSelect;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final options = {
      if (value.isNotEmpty && !models.contains(value)) value,
      ...models,
    }.toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 17, color: p.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '模型',
                  style: appText(11, FontWeight.w400, p.textTertiary),
                ),
                const SizedBox(height: 2),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: options.contains(value) ? value : null,
                    hint: Text(
                      loading ? '正在获取可用模型…' : '填写密钥后选择模型',
                      style: appText(12.5, FontWeight.w400, p.textTertiary),
                    ),
                    isExpanded: true,
                    isDense: true,
                    dropdownColor: p.isDark
                        ? const Color(0xFF171B24)
                        : const Color(0xFFFFFCF8),
                    borderRadius: BorderRadius.circular(14),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                    style: appText(13.5, FontWeight.w500, p.textPrimary),
                    items: [
                      for (final model in options)
                        DropdownMenuItem<String>(
                          value: model,
                          child: Text(
                            model,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: appText(13, FontWeight.w500, p.textPrimary),
                          ),
                        ),
                    ],
                    onChanged: options.isEmpty
                        ? null
                        : (selected) {
                            if (selected != null) onSelect(selected);
                          },
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      error!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: appText(10.5, FontWeight.w400, p.textTertiary),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(top: 18),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 1.8),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: IconButton(
                tooltip: '刷新模型列表',
                iconSize: 18,
                onPressed: onRefresh,
                icon: Icon(Icons.refresh_rounded, color: p.textSecondary),
              ),
            ),
        ],
      ),
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
