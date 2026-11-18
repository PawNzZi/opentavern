import 'package:flutter/material.dart';

import '../data/demo.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    const week = [.42, .58, .36, .74, .92, .66, .8];
    const days = ['一', '二', '三', '四', '五', '六', '日'];
    return DetailPage(
      eyebrow: 'INSIGHTS',
      title: '统计',
      subtitle: '你写了多少，角色回了多少。',
      children: [
        const SizedBox(height: 18),
        Glass(
          radius: 24,
          blur: 24,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            children: const [
              Expanded(child: MiniStat(value: '90', label: '段对话')),
              Expanded(child: MiniStat(value: '1,102', label: '条消息')),
              Expanded(child: MiniStat(value: '295k', label: '字')),
            ],
          ),
        ),
        const SectionLabel('最近 7 天'),
        Glass(
          radius: 24,
          blur: 24,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            children: [
              SizedBox(
                height: 96,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < week.length; i++) ...[
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: 72 * week[i],
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(7),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    p.amber,
                                    p.amber.withValues(alpha: .35),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              days[i],
                              style: appText(
                                9,
                                FontWeight.w400,
                                p.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i != week.length - 1) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const Hairline(),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '本周 1,102 条',
                    style: appText(10.5, FontWeight.w500, p.textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    '较上周 +18%',
                    style: appText(10.5, FontWeight.w600, p.sage),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SectionLabel('角色'),
        Glass(
          radius: 24,
          blur: 24,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Column(
            children: [
              for (final stat in demoStats) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: Portrait(
                          initial: stat.name.characters.first,
                          colors: stat.colors,
                          radius: 11,
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
                                  stat.name,
                                  style: appText(
                                    13,
                                    FontWeight.w500,
                                    p.textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${stat.messages} 条 · ${stat.words} 字',
                                  style: appText(
                                    9.5,
                                    FontWeight.w400,
                                    p.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ProgressLine(
                              value: stat.ratio,
                              height: 4,
                              color: stat.colors.last,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (stat != demoStats.last) const Hairline(),
              ],
            ],
          ),
        ),
        SettingsGroup(
          title: '模型用量 · 本月',
          children: [
            _ModelUsage(
              name: 'Claude Sonnet 4.5',
              value: .52,
              tokens: '128k',
              color: p.amber,
            ),
            const Hairline(indent: 14),
            _ModelUsage(
              name: 'DeepSeek V4',
              value: .28,
              tokens: '69k',
              color: p.violet,
            ),
            const Hairline(indent: 14),
            _ModelUsage(
              name: '本地 Ollama',
              value: .20,
              tokens: '49k',
              color: p.sage,
            ),
          ],
        ),
        SettingsGroup(
          title: '导出',
          children: const [
            SettingRow(
              icon: Icons.table_chart_outlined,
              title: '导出 CSV',
              value: '按角色 / 按天',
              iconColor: Color(0xFFF0B36A),
              onTap: null,
            ),
            Hairline(indent: 56),
            SettingRow(
              icon: Icons.restart_alt_rounded,
              title: '重建统计',
              subtitle: '从聊天文件重新计算',
              value: '大约 2 秒',
              iconColor: Color(0xFFEE9AA8),
              onTap: null,
            ),
          ],
        ),
        const SizedBox(height: 18),
        const HintCard(
          text: '统计只在本机计算，不上传。重建统计不会修改聊天内容，只会重算消息数、字数与耗时。',
          color: Color(0xFF8FD0BE),
        ),
      ],
    );
  }
}

class _ModelUsage extends StatelessWidget {
  const _ModelUsage({
    required this.name,
    required this.value,
    required this.tokens,
    required this.color,
  });

  final String name;
  final double value;
  final String tokens;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                name,
                style: appText(12.5, FontWeight.w500, p.textPrimary),
              ),
              const Spacer(),
              Text(
                tokens,
                style: appText(10, FontWeight.w400, p.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ProgressLine(value: value, height: 4, color: color),
        ],
      ),
    );
  }
}
