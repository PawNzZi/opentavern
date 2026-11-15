/// 设置子页面：AI 供应商 / 生成参数 / 提示词 / 剧情记忆 / 身份。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ai/provider_client.dart';
import '../../core/settings/app_settings.dart';
import '../nav.dart';
import '../toast.dart';
import '../theme.dart';

const Map<String, String> _providerLabels = <String, String>{
  'none': '使用默认（未配置）',
  'deepseek': 'DeepSeek',
  'openrouter': 'OpenRouter',
  'custom': '自定义',
};

class ProviderPage extends StatefulWidget {
  const ProviderPage({super.key});

  @override
  State<ProviderPage> createState() => _ProviderPageState();
}

class _ProviderPageState extends State<ProviderPage> {
  final AppSettings _settings = AppSettings.instance;
  final ProviderClient _client = ProviderClient();
  late final TextEditingController _baseUrl;
  late final TextEditingController _apiKey;
  late final TextEditingController _model;
  String _kind = 'none';
  List<ProviderModel> _models = <ProviderModel>[];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _kind = _settings.providerKind;
    _baseUrl = TextEditingController(text: _settings.providerBaseUrl);
    _apiKey = TextEditingController(text: _settings.providerApiKey);
    _model = TextEditingController(text: _settings.providerModel);
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    _model.dispose();
    super.dispose();
  }

  void _pickKind(String kind) {
    setState(() {
      _kind = kind;
      _models = <ProviderModel>[];
      if (kind != 'custom' && ProviderClient.defaultBaseUrls.containsKey(kind)) {
        _baseUrl.text = ProviderClient.defaultBaseUrls[kind]!;
      }
    });
  }

  Future<void> _fetchModels() async {
    final String baseUrl = _baseUrl.text.trim();
    final String apiKey = _apiKey.text.trim();
    if (baseUrl.isEmpty || apiKey.isEmpty) {
      showToast(context, '请先填写 Base URL 与 API Key');
      return;
    }
    setState(() => _loading = true);
    try {
      final List<ProviderModel> models = await _client.listModels(
        AiProviderConfig(kind: _kind, baseUrl: baseUrl, apiKey: apiKey, model: ''),
      );
      if (!mounted) return;
      setState(() => _models = models);
      if (models.isEmpty) {
        showToast(context, '供应商没有返回模型');
        return;
      }
      await _selectModel();
    } catch (error) {
      if (mounted) showToast(context, '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectModel() async {
    if (_models.isEmpty) {
      showToast(context, '先点「拉取模型」');
      return;
    }
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (final ProviderModel model in _models)
              ListTile(
                title: Text(model.name, style: TavernText.body),
                subtitle: model.name == model.id ? null : Text(model.id, style: TavernText.tiny),
                trailing: _model.text.trim() == model.id
                    ? const Icon(Icons.check, size: 18, color: TavernColors.accent)
                    : null,
                onTap: () => Navigator.of(ctx).pop(model.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _model.text = picked);
    }
  }

  Future<void> _save() async {
    await _settings.setProvider(
      kind: _kind,
      baseUrl: _baseUrl.text,
      apiKey: _apiKey.text,
      model: _model.text,
    );
    if (!mounted) return;
    showToast(context, '供应商已保存');
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TavernColors.bg,
      body: Column(
        children: <Widget>[
          NavBar(
            title: 'AI 供应商',
            actions: <Widget>[
              TextButton(onPressed: () => unawaited(_save()), child: const Text('保存')),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                const Text(
                  '单机版直接调用你选择的 OpenAI 兼容供应商。没配置时无法对话。',
                  style: TavernText.caption,
                ),
                const SizedBox(height: 12),
                CardBox(
                  child: Column(
                    children: <Widget>[
                      for (final String kind in <String>['none', 'deepseek', 'openrouter', 'custom'])
                        ListTile(
                          title: Text(_providerLabels[kind]!, style: TavernText.body),
                          trailing: _kind == kind
                              ? const Icon(Icons.check, size: 18, color: TavernColors.accent)
                              : null,
                          onTap: () => _pickKind(kind),
                        ),
                    ],
                  ),
                ),
                if (_kind != 'none') ...<Widget>[
                  const SectionTitle('连接信息'),
                  CardBox(
                    child: Column(
                      children: <Widget>[
                        _field('Base URL', _baseUrl, readOnly: _kind != 'custom'),
                        _field('API Key', _apiKey, obscure: true),
                      ],
                    ),
                  ),
                  const SectionTitle('模型'),
                  CardBox(
                    child: Column(
                      children: <Widget>[
                        _field('模型 ID', _model),
                        ListTile(
                          title: Text(_loading ? '拉取中…' : '拉取可用模型'),
                          trailing: _loading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text('${_models.length} 个', style: TavernText.tiny),
                          onTap: _loading ? null : () => unawaited(_fetchModels()),
                        ),
                        if (_models.isNotEmpty)
                          ListTile(
                            title: const Text('从列表选择'),
                            onTap: () => unawaited(_selectModel()),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool obscure = false,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: TavernText.caption),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            obscureText: obscure,
            readOnly: readOnly,
            autocorrect: false,
            enableSuggestions: false,
            style: TavernText.body,
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: '—',
            ),
          ),
        ],
      ),
    );
  }
}

class GenerationPage extends StatefulWidget {
  const GenerationPage({super.key});

  @override
  State<GenerationPage> createState() => _GenerationPageState();
}

class _GenerationPageState extends State<GenerationPage> {
  final AppSettings _settings = AppSettings.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TavernColors.bg,
      body: Column(
        children: <Widget>[
          const NavBar(title: '生成参数'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                CardBox(
                  child: Column(
                    children: <Widget>[
                      _slider(
                        '历史条数',
                        '${_settings.historyLimit} 条',
                        _settings.historyLimit.toDouble(),
                        4,
                        100,
                        (double value) => _settings.setHistoryLimit(value.round()),
                      ),
                      _slider(
                        '最大输出',
                        '${_settings.maxTokens} tokens',
                        _settings.maxTokens.toDouble(),
                        256,
                        8192,
                        (double value) => _settings.setMaxTokens(value.round()),
                      ),
                      _slider(
                        '温度',
                        _settings.temperature.toStringAsFixed(2),
                        _settings.temperature,
                        0,
                        2,
                        (double value) => _settings.setTemperature(value),
                      ),
                      _slider(
                        '世界书预算',
                        '${_settings.worldMaxTokens} tokens',
                        _settings.worldMaxTokens.toDouble(),
                        500,
                        32000,
                        (double value) => _settings.setWorldMaxTokens(value.round()),
                      ),
                      _slider(
                        '扫描深度',
                        '${_settings.scanDepth} 条',
                        _settings.scanDepth.toDouble(),
                        1,
                        50,
                        (double value) => _settings.setScanDepth(value.round()),
                      ),
                      _slider(
                        '递归深度',
                        '${_settings.recursionDepth} 层',
                        _settings.recursionDepth.toDouble(),
                        1,
                        5,
                        (double value) => _settings.setRecursionDepth(value.round()),
                      ),
                      SwitchListTile(
                        title: const Text('历史里带角色名', style: TavernText.body),
                        value: _settings.includeNames,
                        onChanged: (bool value) => setState(() => _settings.setIncludeNames(value)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _slider(
    String label,
    String value,
    double current,
    double min,
    double max,
    Future<void> Function(double) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(label, style: TavernText.body)),
              Text(value, style: TavernText.caption),
            ],
          ),
          Slider(
            value: current.clamp(min, max),
            min: min,
            max: max,
            divisions: (max - min).round().clamp(1, 100),
            onChanged: (double next) {
              setState(() {});
              unawaited(onChanged(next));
            },
          ),
        ],
      ),
    );
  }
}

class PromptSettingsPage extends StatefulWidget {
  const PromptSettingsPage({super.key});

  @override
  State<PromptSettingsPage> createState() => _PromptSettingsPageState();
}

class _PromptSettingsPageState extends State<PromptSettingsPage> {
  final AppSettings _settings = AppSettings.instance;
  late final List<String> _order = _settings.promptOrder;

  static const Map<String, String> _labels = <String, String>{
    'main': '主提示词 / 规则',
    'worldBefore': '世界书（角色前）',
    'personaDescription': '用户设定',
    'characterDescription': '角色描述',
    'characterPersonality': '性格',
    'scenario': '场景',
    'systemPrompt': '角色专属提示词',
    'worldAfter': '世界书（角色后）',
    'examplesBefore': '世界书（示例前）',
    'examples': '示例对话',
    'examplesAfter': '世界书（示例后）',
    'authorTop': '作者注上',
    'authorBottom': '作者注下',
    'memory': '剧情记忆',
    'postHistory': '历史后指令',
  };

  void _move(int index, int delta) {
    final int next = index + delta;
    if (next < 0 || next >= _order.length) return;
    setState(() {
      final String item = _order.removeAt(index);
      _order.insert(next, item);
    });
    unawaited(_settings.setPromptOrder(_order));
  }

  Future<void> _editMainPrompt() async {
    final TextEditingController controller =
        TextEditingController(text: _settings.mainPrompt);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('主提示词 / 规则', style: TavernText.title),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            minLines: 10,
            maxLines: 16,
            style: const TextStyle(fontSize: 13, height: 1.5),
            decoration: const InputDecoration(
              hintText: '留空 = 使用内置默认',
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              controller.text = AppSettings.defaultMainPrompt;
            },
            child: const Text('恢复默认'),
          ),
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('保存')),
        ],
      ),
    );
    if (ok != true) return;
    await _settings.setMainPrompt(controller.text);
    if (!mounted) return;
    showToast(context, '主提示词已保存');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TavernColors.bg,
      body: Column(
        children: <Widget>[
          const NavBar(title: '提示词'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                CardBox(
                  child: ListTile(
                    title: const Text('主提示词 / 规则', style: TavernText.body),
                    subtitle: Text(
                      _settings.mainPrompt.trim().isEmpty ? '使用内置默认' : '已自定义',
                      style: TavernText.caption,
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18, color: TavernColors.textFaint),
                    onTap: () => unawaited(_editMainPrompt()),
                  ),
                ),
                const SectionTitle('段落顺序（越靠上越先进入系统提示词）'),
                for (int i = 0; i < _order.length; i++)
                  CardBox(
                    child: ListTile(
                      title: Text(_labels[_order[i]] ?? _order[i], style: TavernText.body),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            onPressed: i == 0 ? null : () => _move(i, -1),
                            icon: const Icon(Icons.arrow_upward, size: 18),
                          ),
                          IconButton(
                            onPressed: i == _order.length - 1 ? null : () => _move(i, 1),
                            icon: const Icon(Icons.arrow_downward, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MemorySettingsPage extends StatefulWidget {
  const MemorySettingsPage({super.key});

  @override
  State<MemorySettingsPage> createState() => _MemorySettingsPageState();
}

class _MemorySettingsPageState extends State<MemorySettingsPage> {
  final AppSettings _settings = AppSettings.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TavernColors.bg,
      body: Column(
        children: <Widget>[
          const NavBar(title: '剧情记忆'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                CardBox(
                  child: Column(
                    children: <Widget>[
                      SwitchListTile(
                        title: const Text('自动压缩', style: TavernText.body),
                        subtitle: const Text('消息超过历史条数两倍时自动整理', style: TavernText.caption),
                        value: _settings.memoryAuto,
                        onChanged: (bool value) {
                          setState(() => _settings.setMemoryAuto(value));
                        },
                      ),
                      ListTile(
                        title: const Text('摘要输出上限', style: TavernText.body),
                        subtitle: Text('${_settings.memorySummaryMaxTokens} tokens', style: TavernText.caption),
                        trailing: const Icon(Icons.chevron_right, size: 18, color: TavernColors.textFaint),
                        onTap: () => _editNumber(
                          '摘要输出上限',
                          _settings.memorySummaryMaxTokens,
                          512,
                          32768,
                          _settings.setMemorySummaryMaxTokens,
                        ),
                      ),
                      ListTile(
                        title: const Text('每次折叠条数', style: TavernText.body),
                        subtitle: Text('${_settings.memoryChunkMessages} 条', style: TavernText.caption),
                        trailing: const Icon(Icons.chevron_right, size: 18, color: TavernColors.textFaint),
                        onTap: () => _editNumber(
                          '每次折叠条数',
                          _settings.memoryChunkMessages,
                          4,
                          200,
                          _settings.setMemoryChunkMessages,
                        ),
                      ),
                      ListTile(
                        title: const Text('单块字符上限', style: TavernText.body),
                        subtitle: Text('${_settings.memoryChunkChars} 字符', style: TavernText.caption),
                        trailing: const Icon(Icons.chevron_right, size: 18, color: TavernColors.textFaint),
                        onTap: () => _editNumber(
                          '单块字符上限',
                          _settings.memoryChunkChars,
                          1000,
                          200000,
                          _settings.setMemoryChunkChars,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '压缩只影响发给模型的内容，原始消息一条都不会删。'
                  '删除或编辑已被摘要覆盖的消息时，记忆会自动作废并重新整理。',
                  style: TavernText.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editNumber(
    String title,
    int current,
    int min,
    int max,
    Future<void> Function(int) onSaved,
  ) async {
    final TextEditingController controller = TextEditingController(text: '$current');
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title, style: TavernText.title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '$min – $max'),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('保存')),
        ],
      ),
    );
    if (ok != true) return;
    final int? parsed = int.tryParse(controller.text.trim());
    if (parsed == null) return;
    await onSaved(parsed.clamp(min, max));
    if (mounted) setState(() {});
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AppSettings _settings = AppSettings.instance;
  late final TextEditingController _name;
  late final TextEditingController _persona;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: _settings.userName);
    _persona = TextEditingController(text: _settings.persona);
  }

  @override
  void dispose() {
    _name.dispose();
    _persona.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await _settings.setUserName(_name.text);
    await _settings.setPersona(_persona.text);
    if (!mounted) return;
    showToast(context, '已保存');
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TavernColors.bg,
      body: Column(
        children: <Widget>[
          NavBar(
            title: '身份与称呼',
            actions: <Widget>[
              TextButton(onPressed: () => unawaited(_save()), child: const Text('保存')),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                const SectionTitle('称呼'),
                CardBox(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _name,
                      style: TavernText.body,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '角色会这样称呼你',
                      ),
                    ),
                  ),
                ),
                const SectionTitle('用户设定（Persona）'),
                CardBox(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _persona,
                      minLines: 5,
                      maxLines: 12,
                      style: TavernText.body,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '你的身份、外貌、性格等，会作为【用户设定】注入',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
