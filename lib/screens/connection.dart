import 'package:flutter/material.dart';

import '../data/demo.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';

class ConnectionPage extends StatelessWidget {
  const ConnectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DetailPage(
      eyebrow: 'CONNECTIONS',
      title: '模型连接',
      subtitle: '密钥只保存在本机钥匙串，请求由主进程转发。',
      footer: const GlassPrimaryButton(
        label: '测试并保存',
        icon: Icons.bolt_rounded,
      ),
      children: [
        const SizedBox(height: 18),
        Glass(
          radius: 24,
          blur: 26,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: [
                          p.amber.withValues(alpha: .85),
                          p.rose.withValues(alpha: .7),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Claude Sonnet 4.5',
                              style: appText(15, FontWeight.w600, p.textPrimary),
                            ),
                            const SizedBox(width: 7),
                            const TagBadge('已连接', color: Color(0xFF8FD0BE)),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Claude 长文 · 820 ms · 200k 上下文',
                          style: appText(10.5, FontWeight.w400, p.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  const GlassPill(label: '测试', height: 30),
                ],
              ),
              const SizedBox(height: 14),
              const ProgressLine(value: .36, height: 4),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '本月用量',
                    style: appText(10, FontWeight.w400, p.textTertiary),
                  ),
                  const Spacer(),
                  Text(
                    '128k / 350k tokens',
                    style: appText(10, FontWeight.w500, p.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
        SettingsGroup(
          title: '服务商',
          children: [
            SettingRow(
              icon: Icons.smart_toy_rounded,
              title: 'Claude',
              value: '已配置',
              iconColor: p.amber,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.hexagon_outlined,
              title: 'OpenAI',
              value: '已配置',
              iconColor: p.sage,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.flare_rounded,
              title: 'Gemini',
              value: '未配置',
              iconColor: p.violet,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.terminal_rounded,
              title: 'DeepSeek / Ollama / 自定义',
              value: '3 个',
              iconColor: p.rose,
              onTap: () {},
            ),
          ],
        ),
        SettingsGroup(
          title: '连接配置',
          footnote: '一个配置 = 服务商 + 模型 + 预设 + 采样参数。切换角色时可以一键切换。',
          children: [
            for (var i = 0; i < demoConnections.length; i++) ...[
              _ConnectionRow(item: demoConnections[i]),
              if (i != demoConnections.length - 1)
                const Hairline(indent: 56),
            ],
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.add_rounded,
              title: '新建连接配置',
              value: '从当前复制',
              iconColor: p.amber,
              onTap: () {},
            ),
          ],
        ),
        SettingsGroup(
          title: '模型',
          children: [
            for (var i = 0; i < demoModels.length; i++) ...[
              _ModelRow(model: demoModels[i]),
              if (i != demoModels.length - 1) const Hairline(indent: 56),
            ],
          ],
        ),
        SettingsGroup(
          title: '高级',
          children: [
            SettingRow(
              icon: Icons.link_rounded,
              title: 'API 地址',
              value: 'api.anthropic.com',
              iconColor: p.amber,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.route_rounded,
              title: '出站代理',
              value: '跟随系统',
              iconColor: p.sage,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.data_object_rounded,
              title: '自定义请求',
              value: '头 2 · 参数 3',
              iconColor: p.violet,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.key_rounded,
              title: '密钥存储',
              value: '本机钥匙串',
              iconColor: p.rose,
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 18),
        const HintCard(
          icon: Icons.lock_outline_rounded,
          text: '所有请求由主进程发出，渲染进程只拿到密钥的引用 ID。导出预设时永远不会包含密钥。',
        ),
      ],
    );
  }
}

class _ConnectionRow extends StatelessWidget {
  const _ConnectionRow({required this.item});

  final DemoConnection item;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: (item.active ? p.amber : p.textTertiary).withValues(
                alpha: .14,
              ),
            ),
            child: Icon(
              item.active
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 17,
              color: item.active ? p.amber : p.textTertiary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.name,
                      style: appText(14, FontWeight.w500, p.textPrimary),
                    ),
                    if (item.active) ...[
                      const SizedBox(width: 6),
                      const TagBadge('当前'),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.provider} · ${item.model} · ${item.latency}',
                  style: appText(10.5, FontWeight.w400, p.textTertiary),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 17,
            color: p.textTertiary,
          ),
        ],
      ),
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({required this.model});

  final DemoModel model;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: p.violet.withValues(alpha: .14),
            ),
            child: Icon(
              Icons.memory_rounded,
              size: 15,
              color: p.violet,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      model.name,
                      style: appText(13.5, FontWeight.w500, p.textPrimary),
                    ),
                    if (model.recommended) ...[
                      const SizedBox(width: 6),
                      const TagBadge('推荐', color: Color(0xFF8FD0BE)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${model.context} 上下文 · ${model.price} / 1M',
                  style: appText(10, FontWeight.w400, p.textTertiary),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: model.recommended ? p.amber : p.textTertiary,
          ),
        ],
      ),
    );
  }
}
