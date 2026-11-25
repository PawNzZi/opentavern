import 'package:flutter/material.dart';

import '../design/glass.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';

/// 聊天页的世界书状态栏（兼容多种角色卡格式）。
///
/// 数据源是会话的 `stat_data` 变量树：MVU 卡由 [InitVar] 初始化、随 JSONPatch
/// 累积；整段输出型卡（`<state>`/`<状态栏>`/代码块/管道表）每轮解析最新完整状态。
///
/// 设计为一条可折叠的「仪表」面板：
///  * 收起时是一行速览——标题 + 最多 3 个关键数值徽章，一眼可读；
///  * 展开后按分组列出全部字段，数值→渐变进度条、枚举→彩色标签、布尔→徽章、
///    长文本→纯文本，自适应不同卡的标签形态；
///  * 展开区限高可滚动，避免挤压对话。
class StatusBarPanel extends StatefulWidget {
  const StatusBarPanel({
    super.key,
    required this.data,
    this.ranges = const {},
  });

  final Map<String, dynamic> data;
  final Map<String, num> ranges;

  @override
  State<StatusBarPanel> createState() => _StatusBarPanelState();
}

class _StatusBarPanelState extends State<StatusBarPanel> {
  bool _expanded = false;

  /// 收集最多 3 个数值字段用于收起时的速览徽章。
  List<(String, num)> get _quickStats {
    final out = <(String, num)>[];
    void walk(Map<String, dynamic> node) {
      for (final e in node.entries) {
        if (out.length >= 3) return;
        final v = e.value;
        if (v is num) {
          out.add((e.key, v));
        } else if (v is Map) {
          walk(Map<String, dynamic>.from(v));
        }
      }
    }

    walk(widget.data);
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (widget.data.isEmpty) return const SizedBox.shrink();
    final raw = widget.data['__raw__'] is String
        ? widget.data['__raw__'] as String
        : null;
    return Glass(
      radius: 18,
      blur: 20,
      shadow: false,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Icon(Icons.monitor_heart_outlined, size: 15, color: p.amber),
                const SizedBox(width: 7),
                Text(
                  '状态栏',
                  style: appText(12.5, FontWeight.w600, p.textPrimary),
                ),
                const SizedBox(width: 8),
                if (!_expanded) ...[
                  if (raw == null)
                    for (final (label, value) in _quickStats) ...[
                      _QuickStat(label: label, value: value),
                      const SizedBox(width: 6),
                    ],
                  const Spacer(),
                ] else
                  const Spacer(),
                AnimatedRotation(
                  turns: _expanded ? .5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: p.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: raw != null
                            ? Text(
                                raw,
                                style: appText(
                                  11.5,
                                  FontWeight.w400,
                                  p.textSecondary,
                                  height: 1.6,
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final entry in widget.data.entries)
                                    if (entry.key != '__raw__') ...[
                                      if (entry.value is Map)
                                        _Group(
                                          name: entry.key,
                                          fields: Map<String, dynamic>.from(
                                              entry.value as Map),
                                          ranges: widget.ranges,
                                        )
                                      else
                                        _Field(
                                          label: entry.key,
                                          value: entry.value,
                                          path: entry.key,
                                          ranges: widget.ranges,
                                        ),
                                      const SizedBox(height: 9),
                                    ],
                                ],
                              ),
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  const _QuickStat({required this.label, required this.value});

  final String label;
  final num value;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: p.amber.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: appText(9.5, FontWeight.w400, p.textTertiary),
          ),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: appText(11, FontWeight.w700, p.amber),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.name,
    required this.fields,
    required this.ranges,
  });

  final String name;
  final Map<String, dynamic> fields;
  final Map<String, num> ranges;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 11,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [p.amber, p.amber.withValues(alpha: .3)],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: appText(11.5, FontWeight.w600, p.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final f in fields.entries)
          _Field(
            label: f.key,
            value: f.value,
            path: '$name/${f.key}',
            ranges: ranges,
          ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.path,
    required this.ranges,
  });

  final String label;
  final dynamic value;
  final String path;
  final Map<String, num> ranges;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final labelWidget = Text(
      label,
      style: appText(11, FontWeight.w400, p.textTertiary),
    );

    if (value is bool) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.5),
        child: Row(
          children: [
            Expanded(child: labelWidget),
            _BoolBadge(value: value as bool),
          ],
        ),
      );
    }

    if (value is num) {
      final max = ranges[path] ?? (value >= 0 && value <= 100 ? 100 : null);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: labelWidget),
                Text(
                  '$value',
                  style: appText(12, FontWeight.w700, p.amber),
                ),
                if (max != null)
                  Text(
                    ' / $max',
                    style: appText(9.5, FontWeight.w400, p.textTertiary),
                  ),
              ],
            ),
            if (max != null && max > 0) ...[
              const SizedBox(height: 5),
              ProgressLine(
                value: (value / max).clamp(0, 1),
                height: 4,
              ),
            ],
          ],
        ),
      );
    }

    final s = '$value';
    final isTag = s.length <= 8 && !s.contains('\n') && s.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: labelWidget),
          const SizedBox(width: 8),
          if (isTag)
            _Tag(text: s)
          else
            Flexible(
              child: Text(
                s,
                textAlign: TextAlign.right,
                style: appText(11.5, FontWeight.w500, p.textPrimary),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final palette = [p.amber, p.sage, p.violet, p.rose];
    final color = palette[text.hashCode.abs() % palette.length];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: .32), width: .6),
      ),
      child: Text(
        text,
        style: appText(10.5, FontWeight.w600, color),
      ),
    );
  }
}

class _BoolBadge extends StatelessWidget {
  const _BoolBadge({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final color = value ? p.sage : p.textTertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        value ? '是' : '否',
        style: appText(10.5, FontWeight.w600, color),
      ),
    );
  }
}
