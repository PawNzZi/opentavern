import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/store.dart';
import '../data/demo.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/routes.dart';
import '../design/theme.dart';
import 'editors.dart';

class AutomationPage extends StatelessWidget {
  const AutomationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
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
        const SearchField(hint: '搜索宏，例如 random、getvar'),
        SettingsGroup(
          title: '宏浏览器',
          trailing: Text(
            '13 / 120',
            style: appText(11, FontWeight.w400, p.textTertiary),
          ),
          children: [
            for (var i = 0; i < demoMacros.length; i++) ...[
              _MacroRow(item: demoMacros[i]),
              if (i != demoMacros.length - 1) const Hairline(indent: 12),
            ],
          ],
        ),
        SettingsGroup(
          title: '变量',
          children: [
            SettingRow(
              icon: Icons.data_object_rounded,
              title: '局部变量',
              value: '12 个 · 当前聊天',
              iconColor: p.violet,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.public_rounded,
              title: '全局变量',
              value: '6 个 · 跨聊天',
              iconColor: p.amber,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.delete_outline_rounded,
              title: '清理未使用变量',
              value: '扫描',
              iconColor: p.rose,
              onTap: () {},
            ),
          ],
        ),
        SettingsGroup(
          title: '脚本',
          children: [
            SettingRow(
              icon: Icons.code_rounded,
              title: 'STscript 片段',
              value: '3 个',
              iconColor: p.sage,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.play_circle_outline_rounded,
              title: '快捷回复脚本',
              value: '5 个按钮',
              iconColor: p.amber,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.bug_report_outlined,
              title: '命令调试台',
              value: '最近 12 条',
              iconColor: p.violet,
              onTap: () {},
            ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 9, 12, 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '{{${item.name}${item.args.isEmpty ? '' : '::${item.args}'}}}',
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
          Icon(
            Icons.add_circle_outline_rounded,
            size: 18,
            color: p.textTertiary,
          ),
        ],
      ),
    );
  }
}
