/// 页面跳转与通用小组件。
library;

import 'package:flutter/material.dart';

import 'theme.dart';

Future<T?> pushPage<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    MaterialPageRoute<T>(builder: (BuildContext _) => page),
  );
}

/// 分组卡片容器。
class CardBox extends StatelessWidget {
  const CardBox({super.key, required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: TavernColors.surface,
        borderRadius: BorderRadius.circular(TavernRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// iOS 风格导航栏：返回 + 居中标题 + 右侧动作。
class NavBar extends StatelessWidget {
  const NavBar({
    super.key,
    required this.title,
    this.actions = const <Widget>[],
    this.showBack = true,
  });

  final String title;
  final List<Widget> actions;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.only(top: top),
      decoration: const BoxDecoration(
        color: TavernColors.bg,
        border: Border(bottom: BorderSide(color: TavernColors.separator, width: 0.5)),
      ),
      child: SizedBox(
        height: 44,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 56,
              child: showBack
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.chevron_left, size: 26),
                        color: TavernColors.text,
                        splashRadius: 20,
                      ),
                    )
                  : null,
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TavernText.title,
              ),
            ),
            SizedBox(
              width: 56,
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 列表行。
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(label, style: TavernText.caption),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right, size: 16, color: TavernColors.textFaint),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '—' : value,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: onTap == null ? TavernColors.textSecondary : TavernColors.accent,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return body;
    return InkWell(onTap: onTap, child: body);
  }
}

/// 段落标题。
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(text, style: TavernText.caption),
    );
  }
}
