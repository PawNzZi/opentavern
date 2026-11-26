import 'package:flutter/material.dart';

import '../core/models.dart';
import '../design/scaffold.dart';
import '../design/theme.dart';

/// 角色级「AI 供应商」选择面板内容。
///
/// 外层 [showTavernSheet] 已经用 SingleChildScrollView 包裹，所以这里必须用
/// 高度自适应的 Column（不能用 ListView，否则无界高度会塌成空白）。
class ProviderPickerBody extends StatelessWidget {
  const ProviderPickerBody({
    super.key,
    required this.providers,
    required this.configured,
    required this.current,
    required this.globalProvider,
    required this.onSelect,
  });

  final List<String> providers;
  final bool Function(String) configured;
  final String current;
  final String globalProvider;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget row({
      required IconData icon,
      required String title,
      required String subtitle,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: p.divider, width: .6),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? p.amber : p.textTertiary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: appText(
                        14,
                        selected ? FontWeight.w600 : FontWeight.w500,
                        selected ? p.amber : p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: appText(10.5, FontWeight.w400, p.textTertiary),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, size: 18, color: p.amber),
            ],
          ),
        ),
      );
    }

    final globalLabel = kProviderLabels[globalProvider] ?? globalProvider;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row(
          icon: Icons.public_rounded,
          title: '跟随全局',
          subtitle: '当前全局：$globalLabel',
          selected: current.isEmpty,
          onTap: () => onSelect(''),
        ),
        for (final id in providers)
          row(
            icon: Icons.smart_toy_outlined,
            title: kProviderLabels[id] ?? id,
            subtitle: configured(id) ? '已配置' : '未配置密钥',
            selected: current == id,
            onTap: () => onSelect(id),
          ),
      ],
    );
  }
}

/// 弹出角色级服务商选择器，返回选中的服务商 id（'' 表示跟随全局），取消返回 null。
Future<String?> showProviderPicker(
  BuildContext context, {
  required List<String> providers,
  required bool Function(String) configured,
  required String current,
  required String globalProvider,
}) {
  return showTavernSheet<String>(
    context,
    title: 'AI 供应商',
    subtitle: '仅对此角色生效 · 默认跟随全局',
    heightFactor: .62,
    child: Builder(
      builder: (sheetContext) => ProviderPickerBody(
        providers: providers,
        configured: configured,
        current: current,
        globalProvider: globalProvider,
        onSelect: (id) => Navigator.of(sheetContext).pop(id),
      ),
    ),
  );
}
