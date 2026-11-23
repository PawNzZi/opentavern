import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import '../core/store.dart';
import '../data/demo.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/routes.dart';
import '../design/theme.dart';
import '../design/toast.dart';
import 'editors.dart';

class AutomationPage extends StatefulWidget {
  const AutomationPage({super.key});

  @override
  State<AutomationPage> createState() => _AutomationPageState();
}

class _AutomationPageState extends State<AutomationPage> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final q = _query.text.trim().toLowerCase();
    final macros = demoMacros.where((m) {
      if (q.isEmpty) return true;
      return m.name.toLowerCase().contains(q) ||
          m.description.toLowerCase().contains(q) ||
          m.args.toLowerCase().contains(q);
    }).toList();
    final localVars = <String>{};
    for (final session in AppStore.instance.sessions) {
      localVars.addAll(session.variables.keys);
    }
    return DetailPage(
      eyebrow: 'AUTOMATION',
      title: '正则与宏',
      subtitle: '确定性的文本改写，和不写代码的 Prompt 编程。',
      children: [
        AnimatedBuilder(
          animation: AppStore.instance,
          builder: (context, _) => SettingsGroup(
            title: '正则脚本',
            trailing: Text(
              '${AppStore.instance.regexScripts.length} 个 · ${AppStore.instance.regexScripts.where((r) => r.enabled).length} 启用',
              style: appText(11, FontWeight.w400, p.textTertiary),
            ),
            footnote: '按作用域与顺序执行；可以只改显示，或只改发给模型的内容。',
            children: [
              for (var i = 0; i < AppStore.instance.regexScripts.length; i++) ...[
                _RegexRow(
                  item: AppStore.instance.regexScripts[i],
                  onTap: () => openGlassPage(
                    context,
                    RegexEditorSheet(script: AppStore.instance.regexScripts[i]),
                  ),
                  onToggle: (v) async {
                    AppStore.instance.regexScripts[i].enabled = v;
                    await AppStore.instance.saveRegexes();
                  },
                ),
                if (i != AppStore.instance.regexScripts.length - 1)
                  const Hairline(indent: 12),
              ],
              const Hairline(indent: 12),
              SettingRow(
                icon: Icons.add_rounded,
                title: '新建正则',
                value: '从空白 / 模板',
                iconColor: p.amber,
                onTap: () => openGlassPage(
                  context,
                  const RegexEditorSheet(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SearchField(
          hint: '搜索宏，例如 random、getvar',
          controller: _query,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        const HintCard(
          text: '点按宏或右侧 + 可复制语法。另外两个「输入 shorthand」不在宏列表里：'
              '用 “” 包裹发言、（） 包裹环境/动作，发送时自动转成 [用户发言] / [用户环境/动作]；'
              '聊天输入框上方有 “”发言 / （）环境 快捷按钮，点击即在光标处插入并把光标置于中间。',
          icon: Icons.format_quote_rounded,
          color: Color(0xFFF0B36A),
        ),
        SettingsGroup(
          title: '宏浏览器',
          trailing: Text(
            '${macros.length} 个',
            style: appText(11, FontWeight.w400, p.textTertiary),
          ),
          children: [
            for (var i = 0; i < macros.length; i++) ...[
              _MacroRow(item: macros[i]),
              if (i != macros.length - 1) const Hairline(indent: 12),
            ],
          ],
        ),
        const SizedBox(height: 18),
        const HintCard(
          text: '正则可能带来性能问题。每次执行都有超时与长度限制；复杂的文本处理建议写成 STscript 或扩展。',
          color: Color(0xFFEE9AA8),
        ),
      ],
    );
  }
}

class _RegexRow extends StatelessWidget {
  const _RegexRow({required this.item, this.onTap, this.onToggle});

  final RegexScript item;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 9, 12, 9),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: p.violet.withValues(alpha: .15),
              ),
              child: Icon(Icons.find_replace_rounded, size: 17, color: p.violet),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appText(13.5, FontWeight.w500, p.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 6),
                      TagBadge(item.scope, color: p.violet),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.find}  →  ${item.replace}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      height: 1.4,
                      color: p.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.placement == 'display'
                        ? '仅显示'
                        : item.placement == 'prompt'
                            ? '仅 Prompt'
                            : '显示与 Prompt',
                    style: appText(9, FontWeight.w500, p.amber.withValues(alpha: .8)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TavernSwitch(value: item.enabled, onChanged: onToggle),
          ],
        ),
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({required this.item});

  final DemoMacro item;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final syntax =
        '{{${item.name}${item.args.isEmpty ? '' : '::${item.args}'}}}';
    void copy() {
      Clipboard.setData(ClipboardData(text: syntax));
      showTavernToast(context, '已复制 $syntax');
    }

    return Pressable(
      onTap: copy,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 9, 12, 9),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    syntax,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      color: p.amber,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.description,
                    style: appText(9.5, FontWeight.w400, p.textTertiary),
                  ),
                ],
              ),
            ),
            Pressable(
              onTap: copy,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.add_circle_outline_rounded,
                  size: 18,
                  color: p.amber,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
