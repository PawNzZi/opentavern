import 'package:flutter/material.dart';

import '../core/store.dart';
import '../design/glass.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key, this.sessionId});

  final String? sessionId;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  String? _selected;
  int? _days = 7;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final store = AppStore.instance;
    final now = DateTime.now();
    final cutoff = _days == null
        ? 0
        : now.subtract(Duration(days: _days!)).millisecondsSinceEpoch;
    final allSessions = store.sessions
        .where((s) => widget.sessionId != null || s.updatedAt >= cutoff)
        .where((s) => widget.sessionId == null || s.id == widget.sessionId)
        .toList();
    final sessions = _selected == null
        ? allSessions
        : allSessions.where((s) => s.characterName == _selected).toList();
    final messages = sessions.expand((s) => s.messages).toList();
    final chars = messages.fold<int>(0, (sum, m) => sum + m.text.length);

    // Aggregated usage from real assistant replies. Only messages that carry
    // metadata (model / tokens / duration / provider) contribute to these.
    final assistantMessages =
        messages.where((m) => !m.isUser && !m.isSystem).toList();
    final usageMessages = assistantMessages
        .where((m) =>
            m.promptTokens != null ||
            m.completionTokens != null ||
            m.durationMs != null ||
            (m.model?.trim().isNotEmpty ?? false) ||
            (m.apiProvider?.trim().isNotEmpty ?? false))
        .toList();
    final totalPromptTokens = usageMessages.fold<int>(
      0,
      (sum, m) => sum + (m.promptTokens ?? 0),
    );
    final totalCompletionTokens = usageMessages.fold<int>(
      0,
      (sum, m) => sum + (m.completionTokens ?? 0),
    );
    final durations =
        usageMessages.map((m) => m.durationMs).whereType<int>().toList();
    final averageDurationMs = durations.isEmpty
        ? null
        : (durations.reduce((a, b) => a + b) / durations.length).round();
    final models = <String>{};
    final providers = <String>{};
    for (final m in usageMessages) {
      final model = m.model?.trim();
      if (model != null && model.isNotEmpty) models.add(model);
      final provider = m.apiProvider?.trim();
      if (provider != null && provider.isNotEmpty) providers.add(provider);
    }

    final week = List<int>.filled(7, 0);
    for (final m in messages) {
      final d = DateTime.fromMillisecondsSinceEpoch(m.createdAt);
      final diff = now.difference(DateTime(d.year, d.month, d.day)).inDays;
      if (diff >= 0 && diff < 7) week[6 - diff]++;
    }
    final maxWeek = week.fold<int>(1, (a, b) => b > a ? b : a);

    final perCharacter = <String, int>{};
    for (final session in allSessions) {
      perCharacter[session.characterName] =
          (perCharacter[session.characterName] ?? 0) + session.messages.length;
    }
    final names = perCharacter.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final ranking = _selected == null
        ? names.take(5).toList()
        : names.where((e) => e.key == _selected).toList();

    const days = ['一', '二', '三', '四', '五', '六', '日'];
    return DetailPage(
      eyebrow: 'INSIGHTS',
      title: '统计',
      subtitle: _selected == null
          ? '你写了多少，角色回了多少。'
          : '只看 $_selected。',
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            GlassPill(
              label: '7 天',
              height: 30,
              selected: _days == 7,
              onTap: () => setState(() => _days = 7),
            ),
            const SizedBox(width: 7),
            GlassPill(
              label: '30 天',
              height: 30,
              selected: _days == 30,
              onTap: () => setState(() => _days = 30),
            ),
            const SizedBox(width: 7),
            GlassPill(
              label: '全部',
              height: 30,
              selected: _days == null,
              onTap: () => setState(() => _days = null),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Glass(
          radius: 24,
          blur: 24,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: MiniStat(value: '${sessions.length}', label: '段对话'),
              ),
              Expanded(
                child: MiniStat(value: '${messages.length}', label: '条消息'),
              ),
              Expanded(
                child: MiniStat(
                  value: chars > 1000
                      ? '${(chars / 1000).toStringAsFixed(1)}k'
                      : '$chars',
                  label: '字',
                ),
              ),
            ],
          ),
        ),
        const SectionLabel('模型用量'),
        Glass(
          radius: 24,
          blur: 24,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: usageMessages.isEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '还没有模型用量数据',
                      style: appText(13, FontWeight.w500, p.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '新的回复会自动记录 tokens、耗时、模型与 API 提供商；'
                      '旧消息没有这些信息，不会计入。',
                      style: appText(
                        10.5,
                        FontWeight.w400,
                        p.textTertiary,
                        height: 1.5,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: MiniStat(
                            value: _formatTokenCount(totalPromptTokens),
                            label: '输入 tokens',
                          ),
                        ),
                        Expanded(
                          child: MiniStat(
                            value: _formatTokenCount(totalCompletionTokens),
                            label: '输出 tokens',
                          ),
                        ),
                        Expanded(
                          child: MiniStat(
                            value: _formatDurationMs(averageDurationMs),
                            label: '平均耗时',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Hairline(),
                    const SizedBox(height: 10),
                    _UsageInfoRow(
                      label: '消息数',
                      value:
                          '${usageMessages.length} 条（共 ${assistantMessages.length} 条回复）',
                    ),
                    if (models.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _UsageInfoRow(label: '模型', value: models.join(' · ')),
                    ],
                    if (providers.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _UsageInfoRow(
                        label: 'API 提供商',
                        value: providers.join(' · '),
                      ),
                    ],
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
                              height: 72 * (week[i] / maxWeek),
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
                    '本周 ${week.fold<int>(0, (a, b) => a + b)} 条',
                    style: appText(10.5, FontWeight.w500, p.textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    '${sessions.where((s) => s.pinned).length} 个置顶会话',
                    style: appText(10.5, FontWeight.w500, p.textTertiary),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SectionLabel('角色'),
        if (names.isNotEmpty) ...[
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              GlassPill(
                label: '全部',
                height: 30,
                selected: _selected == null,
                onTap: () => setState(() => _selected = null),
              ),
              for (final entry in names.take(8))
                GlassPill(
                  label: entry.key,
                  height: 30,
                  selected: _selected == entry.key,
                  onTap: () => setState(() => _selected = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Glass(
          radius: 24,
          blur: 24,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Column(
            children: [
              if (ranking.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    '还没有聊天数据',
                    style: appText(12.5, FontWeight.w400, p.textTertiary),
                  ),
                ),
              for (var i = 0; i < ranking.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: Portrait(
                          initial: ranking[i].key.isEmpty
                              ? '?'
                              : ranking[i].key.characters.first,
                          colors: const [
                            Color(0xFF8C4A3F),
                            Color(0xFFD98E5F),
                            Color(0xFF3B1E2A),
                          ],
                          radius: 11,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ranking[i].key,
                              style: appText(
                                13.5,
                                FontWeight.w500,
                                p.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: ranking[i].value /
                                    (ranking.first.value == 0
                                        ? 1
                                        : ranking.first.value),
                                minHeight: 4,
                                backgroundColor:
                                    p.textTertiary.withValues(alpha: .12),
                                valueColor: AlwaysStoppedAnimation(p.amber),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${ranking[i].value}',
                        style: appText(11.5, FontWeight.w600, p.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (i != ranking.length - 1) const Hairline(indent: 44),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '统计来自本地会话；删除会话后数字会同步减少。',
          style: appText(10.5, FontWeight.w400, p.textTertiary, height: 1.5),
        ),
      ],
    );
  }
}

String _formatTokenCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
  return '$value';
}

String _formatDurationMs(int? value) {
  if (value == null) return '—';
  if (value < 1000) return '${value}ms';
  return '${(value / 1000).toStringAsFixed(1)}s';
}

class _UsageInfoRow extends StatelessWidget {
  const _UsageInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: appText(10.5, FontWeight.w400, p.textTertiary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: appText(10.5, FontWeight.w500, p.textSecondary),
          ),
        ),
      ],
    );
  }
}
