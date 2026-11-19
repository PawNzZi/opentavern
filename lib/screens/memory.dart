import 'package:flutter/material.dart';

import '../core/store.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';
import '../design/toast.dart';

class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key});

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  late final TextEditingController _prompt;
  late bool _enabled;
  late int _interval;

  @override
  void initState() {
    super.initState();
    final settings = AppStore.instance.settings;
    _enabled = settings.memoryEnabled;
    _interval = settings.summaryInterval;
    _prompt = TextEditingController(text: settings.summaryPrompt);
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    AppStore.instance.settings = AppStore.instance.settings.copyWith(
      memoryEnabled: _enabled,
      summaryInterval: _interval,
      summaryPrompt: _prompt.text.trim(),
    );
    await AppStore.instance.saveSettings();
    if (!mounted) return;
    showTavernToast(context, '记忆设置已保存');
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DetailPage(
      eyebrow: 'MEMORY & KNOWLEDGE',
      title: '记忆与总结',
      subtitle: '按间隔把早期剧情压缩成摘要，持续注入 Prompt。',
      footer: GlassPrimaryButton(
        label: '保存记忆设置',
        icon: Icons.check_rounded,
        onTap: _save,
      ),
      children: [
        const SizedBox(height: 18),
        Glass(
          radius: 24,
          blur: 26,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: p.violet.withValues(alpha: .16),
                ),
                child: Icon(Icons.auto_awesome_rounded, size: 20, color: p.violet),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '自动摘要',
                      style: appText(15, FontWeight.w600, p.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _enabled
                          ? '每 $_interval 条消息生成一次摘要'
                          : '已关闭，聊天不会自动总结',
                      style: appText(10.5, FontWeight.w400, p.textTertiary),
                    ),
                  ],
                ),
              ),
              TavernSwitch(
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SettingsGroup(
          title: '触发',
          children: [
            SwitchLine(
              title: '启用自动摘要',
              subtitle: '生成完成后在后台调用模型',
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            const Hairline(indent: 14),
            StepperRow(
              title: '总结间隔',
              subtitle: '每 N 条新消息触发一次',
              value: '$_interval 条',
              onMinus: _interval > 4
                  ? () => setState(() => _interval = (_interval - 5).clamp(4, 100))
                  : null,
              onPlus: _interval < 100
                  ? () => setState(() => _interval = (_interval + 5).clamp(4, 100))
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Glass(
            radius: 18,
            blur: 18,
            shadow: false,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '摘要 Prompt',
                  style: appText(10.5, FontWeight.w500, p.textTertiary),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _prompt,
                  maxLines: 6,
                  style: appText(14, FontWeight.w400, p.textPrimary, height: 1.5),
                  cursorColor: p.amber,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: '请总结以下对话的剧情、关系与未解决线索…',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '摘要保存在每个聊天会话里；在聊天信息中可手动触发一次总结。',
          style: appText(10.5, FontWeight.w400, p.textTertiary, height: 1.5),
        ),
      ],
    );
  }
}
