import 'package:flutter/material.dart';

import '../design/glass.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';

/// 聊天页的世界书状态栏。
///
/// 数据源是会话的 `stat_data` 嵌套变量树（来自世界书 [InitVar]，随回复里的
/// JSONPatch 更新）。不同角色卡的标签形态不同——有的是文字描述、有的是标签、
/// 有的是数值——这里按值类型自适应渲染：
///   数值 → 数值 + 进度条（范围取自「变量更新规则」）
///   布尔 → 是/否 徽章
///   短文本（枚举/标签）→ 彩色 chip
///   长文本（日期/地点等描述）→ 纯文本
/// 整块面板可折叠，默认收起为一条摘要，点开后按分组展开。
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

  String get _summary {
    final time = widget.data['时间'];
    if (time is Map) {
      final parts = [
        if (time['时段'] != null) '${time['时段']}',
        if (time['日期'] != null) '${time['日期']}',
      ];
      if (parts.isNotEmpty) return parts.join(' · ');
    }
    final groups = widget.data.keys.where((k) => widget.data[k] is Map).length;
    return '$groups 组状态变量';
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (widget.data.isEmpty) return const SizedBox.shrink();
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
                Icon(Icons.dashboard_customize_outlined,
                    size: 15, color: p.amber),
                const SizedBox(width: 7),
                Text(
                  '状态栏',
                  style: appText(12.5, FontWeight.w600, p.textPrimary),
                ),
                const SizedBox(width: 8),
                if (!_expanded)
                  Expanded(
                    child: Text(
                      _summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appText(10.5, FontWeight.w400, p.textTertiary),
                    ),
                  )
                else
                  const Spacer(),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: p.textSecondary,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            for (final entry in widget.data.entries) ...[
              if (entry.value is Map)
                _Group(
                  name: entry.key,
                  fields: Map<String, dynamic>.from(entry.value as Map),
                  ranges: widget.ranges,
                )
              else
                _Field(
                  label: entry.key,
                  value: entry.value,
                  path: entry.key,
                  ranges: widget.ranges,
                ),
              const SizedBox(height: 8),
            ],
          ],
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
                color: p.amber.withValues(alpha: .7),
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
        const SizedBox(height: 5),
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
        padding: const EdgeInsets.symmetric(vertical: 3),
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
        padding: const EdgeInsets.symmetric(vertical: 3),
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
              const SizedBox(height: 4),
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
      padding: const EdgeInsets.symmetric(vertical: 3),
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
    // 用文本哈希挑一个稳定的强调色，让不同标签有区分但不刺眼。
    final palette = [p.amber, p.sage, p.violet, p.rose];
    final color = palette[text.hashCode.abs() % palette.length];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: .35), width: .6),
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
