import 'package:flutter/material.dart';

import '../core/store.dart';
import '../design/glass.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';
import '../design/toast.dart';

/// Context window and formatting budget.
///
/// This is deliberately separate from [GenerationPage]: generation controls how
/// the model writes, while this page controls how much chat history, lore and
/// system text fit into one request.
class ContextPage extends StatefulWidget {
  const ContextPage({super.key});

  @override
  State<ContextPage> createState() => _ContextPageState();
}

class _ContextPageState extends State<ContextPage> {
  late double _maxContext;
  late double _tokenPadding;
  late double _loreMaxTokens;

  @override
  void initState() {
    super.initState();
    final settings = AppStore.instance.settings;
    _maxContext = settings.maxContext.toDouble();
    _tokenPadding = settings.tokenPadding.toDouble();
    _loreMaxTokens = settings.loreMaxTokens.toDouble();
  }

  Future<void> _save() async {
    final settings = AppStore.instance.settings;
    AppStore.instance.settings = settings.copyWith(
      maxContext: _maxContext.round(),
      tokenPadding: _tokenPadding.round(),
      loreMaxTokens: _loreMaxTokens.round(),
    );
    await AppStore.instance.saveSettings();
    if (!mounted) return;
    showTavernToast(context, '上下文设置已保存');
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DetailPage(
      eyebrow: 'CONTEXT',
      title: '上下文与格式',
      subtitle: '控制一次请求能装下多少内容，以及给回复预留多少空间。',
      footer: GlassPrimaryButton(
        label: '保存上下文设置',
        icon: Icons.check_rounded,
        onTap: _save,
      ),
      children: [
        const SizedBox(height: 14),
        SettingsGroup(
          title: '上下文窗口',
          children: [
            SliderLine(
              title: '最大上下文',
              value: _maxContext,
              min: 2048,
              max: 32768,
              divisions: 30,
              display: '${_maxContext.round()} tokens',
              onChanged: (v) => setState(() => _maxContext = v),
            ),
            const Hairline(indent: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Text(
                '角色设定、世界书、历史消息和 System Prompt 共享这个窗口。'
                '超过预算时优先保留最近对话，较旧的历史会被丢弃。',
                style: appText(11, FontWeight.w400, p.textTertiary, height: 1.55),
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: '生成预留',
          children: [
            SliderLine(
              title: '回复预留',
              value: _tokenPadding,
              min: 0,
              max: 512,
              divisions: 32,
              display: '${_tokenPadding.round()} tokens',
              onChanged: (v) => setState(() => _tokenPadding = v),
            ),
            const Hairline(indent: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Text(
                '给模型回复预留的 Token。该值会从上下文中扣除，'
                '避免上下文把回复空间挤占掉。',
                style: appText(11, FontWeight.w400, p.textTertiary, height: 1.55),
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: '世界书注入',
          children: [
            SliderLine(
              title: '世界书 Token 上限',
              value: _loreMaxTokens,
              min: 0,
              max: 8192,
              divisions: 64,
              display: _loreMaxTokens <= 0
                  ? '无限制'
                  : '${_loreMaxTokens.round()} tokens',
              onChanged: (v) => setState(() => _loreMaxTokens = v),
            ),
            const Hairline(indent: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Text(
                '这是全局设置，对所有世界书生效。0 表示无限制；'
                '设置上限后只截断世界书部分，不会改变聊天历史预算。',
                style: appText(11, FontWeight.w400, p.textTertiary, height: 1.55),
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: '当前估算',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '可用历史预算',
                          style: appText(13.5, FontWeight.w500, p.textPrimary),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '最大上下文减去回复预留和固定开销',
                          style: appText(10.5, FontWeight.w400, p.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(_maxContext - _tokenPadding).clamp(0, 999999).round()} tokens',
                    style: appText(12, FontWeight.w600, p.amber),
                  ),
                ],
              ),
            ),
          ],
        ),
        const HintCard(
          text: '这些是本地估算值，不会上传。修改后从下一条消息开始生效。',
          color: Color(0xFFD9B48A),
        ),
      ],
    );
  }
}
