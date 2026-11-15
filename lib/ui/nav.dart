/// 页面跳转与通用小组件。
library;

import 'package:flutter/material.dart';

import 'ios_kit.dart';
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
        borderRadius: BorderRadius.circular(12),
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
    return IosNavBar(title: title, actions: actions, showBack: showBack);
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
    final Widget body = Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: TavernColors.separator, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
