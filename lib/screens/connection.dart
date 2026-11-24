import 'dart:async';

import 'package:flutter/material.dart';

import '../core/llm.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
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
    'OpenRouter': ('https://openrouter.ai/api/v1', 'openrouter/auto'),
    '随想': ('https://www.sui-xiang.net', ''),
    '自定义': ('', ''),
  };

  late final TextEditingController _base;
  late final TextEditingController _key;
  late final TextEditingController _model;
  late String _provider;
  late Map<String, ProviderProfile> _profiles;
  Timer? _fetchDebounce;
  List<String> _models = const [];
  bool _loadingModels = false;
  String? _modelError;

  @override
  void initState() {
    super.initState();
    final api = AppStore.instance.settings.api;
    _profiles = Map<String, ProviderProfile>.from(api.profiles);
    _provider = _labelFor(api.provider);
    // 当前服务商优先用自己的独立档案；没有档案时回退到活动配置。
    final profile = _profiles[_providerKey(_provider)];
    _base = TextEditingController(
      text: profile != null && profile.baseUrl.isNotEmpty
          ? profile.baseUrl
          : api.baseUrl,
    );
    _key = TextEditingController(
      text: profile != null ? profile.apiKey : api.apiKey,
    );
    _model = TextEditingController(
      text: profile != null && profile.model.isNotEmpty
          ? profile.model
          : api.model,
    );
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
      case 'deepseek':
        return 'DeepSeek';
      case 'openrouter':
        return 'OpenRouter';
      case 'suixiang':
        return '随想';
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
      case 'DeepSeek':
        return 'deepseek';
      case 'OpenRouter':
        return 'openrouter';
      case '随想':
        return 'suixiang';
      case 'OpenAI':
        return 'openai';
      default:
        return 'custom';
    }
  }

  bool get _needsKey => _providerKey(_provider) != 'custom';

  /// 把当前输入框的内容存回当前服务商的独立档案（切换 / 保存前调用）。
  void _stashCurrent() {
    _profiles[_providerKey(_provider)] = ProviderProfile(
      baseUrl: _base.text.trim(),
      apiKey: _key.text.trim(),
      model: _model.text.trim(),
    );
  }

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
    if (label == _provider) return;
    // 先保存当前服务商的输入，再载入目标服务商自己的档案 —— 密钥绝不串用。
    _stashCurrent();
    final incoming = _profiles[_providerKey(label)];
    final preset = _presets[label];
    setState(() {
      _provider = label;
      if (incoming != null && !incoming.isEmpty) {
        _base.text = incoming.baseUrl;
        _key.text = incoming.apiKey;
        _model.text = incoming.model;
      } else {
        _base.text = preset?.$1 ?? '';
        _model.text = preset?.$2 ?? '';
        _key.text = '';
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
    _stashCurrent();
    final settings = AppStore.instance.settings;
    AppStore.instance.settings = settings.copyWith(
      api: settings.api.copyWith(
        provider: _providerKey(_provider),
        baseUrl: _base.text.trim(),
        apiKey: _key.text.trim(),
        model: _model.text.trim(),
        profiles: Map<String, ProviderProfile>.from(_profiles),
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
              child: Align(
                alignment: Alignment.centerLeft,
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
                '支持 OpenAI 兼容、Claude、Gemini、DeepSeek、OpenRouter 与随想中转。'
                '每个服务商的地址、密钥与模型独立保存，切换服务商不会串用密钥。'
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

  Future<void> _open(BuildContext context) async {
    final selected = await showTavernSheet<String>(
      context,
      title: '选择模型',
      subtitle: models.isEmpty
          ? (error ?? '没有可用模型')
          : '${models.length} 个可用模型',
      heightFactor: .62,
      child: _ModelSheet(
        models: models,
        current: value,
        error: error,
      ),
    );
    if (selected != null) onSelect(selected);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 17,
              color: p.textTertiary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _open(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '模型',
                    style: appText(11, FontWeight.w400, p.textTertiary),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          value.trim().isEmpty ? '选择模型' : value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appText(
                            13.5,
                            FontWeight.w500,
                            value.trim().isEmpty
                                ? p.textTertiary
                                : p.textPrimary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 19,
                        color: p.textSecondary,
                      ),
                    ],
                  ),
                  if (loading)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '正在获取可用模型…',
                        style: appText(10.5, FontWeight.w400, p.textTertiary),
                      ),
                    )
                  else if (error != null)
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
          ),
          const SizedBox(width: 6),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(top: 23),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 1.8),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 11),
              child: IconButton(
                tooltip: '刷新模型列表',
                iconSize: 18,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: onRefresh,
                icon: Icon(Icons.refresh_rounded, color: p.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModelSheet extends StatelessWidget {
  const _ModelSheet({
    required this.models,
    required this.current,
    required this.error,
  });

  final List<String> models;
  final String current;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (models.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(6, 16, 6, 20),
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded, size: 24, color: p.textTertiary),
            const SizedBox(height: 8),
            Text(
              error ?? '没有获取到可用模型',
              textAlign: TextAlign.center,
              style: appText(12.5, FontWeight.w400, p.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              '关闭后点右侧刷新按钮重试',
              style: appText(10.5, FontWeight.w400, p.textTertiary),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final model in models)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(model),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: p.divider, width: .6),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      model,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: appText(
                        13.5,
                        model == current ? FontWeight.w600 : FontWeight.w400,
                        model == current ? p.amber : p.textPrimary,
                      ),
                    ),
                  ),
                  if (model == current)
                    Icon(Icons.check_rounded, size: 18, color: p.amber),
                ],
              ),
            ),
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
