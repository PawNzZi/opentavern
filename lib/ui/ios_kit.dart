/// iOS 界面套件：玻璃导航栏、分组卡片、系统开关、分段标题。
///
/// 参照 hdsh-flutter 里迭代过的 iOS 规范：
///   - 页面底 = 系统分组灰 #F2F2F7
///   - 卡片 = 白底 12 圆角 + 0.5 hairline 分隔线（缩进 16）
///   - 导航栏 = 状态栏 + 44，iOS 26 用原生玻璃
///   - 控件 = 系统蓝 #0A84FF，开关用 CupertinoSwitch
library;

import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_native/liquid_glass_native.dart';

import 'theme.dart';

bool get _isIOS => Platform.isIOS;

/// 原生玻璃是否可用（iOS 26+）。
bool get supportsNativeGlass {
  if (!_isIOS) return false;
  final RegExpMatch? match =
      RegExp(r'(\d+)\.').firstMatch(Platform.operatingSystemVersion);
  final int major = match == null ? 0 : (int.tryParse(match.group(1) ?? '') ?? 0);
  return major >= 26;
}

/// iOS 风格导航栏：状态栏 + 44，玻璃底 + 底部 hairline。
class IosNavBar extends StatelessWidget {
  const IosNavBar({
    super.key,
    required this.title,
    this.actions = const <Widget>[],
    this.showBack = true,
    this.onBack,
  });

  final String title;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top;
    final Widget row = SizedBox(
      height: 44,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 52,
            child: showBack
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.chevron_left, size: 28),
                      color: TavernColors.accent,
                      splashRadius: 22,
                      padding: const EdgeInsets.only(left: 4),
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
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: TavernColors.text,
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(mainAxisSize: MainAxisSize.min, children: actions),
            ),
          ),
        ],
      ),
    );

    final Widget content = Padding(
      padding: EdgeInsets.only(top: top),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0x14000000), width: 0.5),
          ),
        ),
        child: row,
      ),
    );

    if (supportsNativeGlass) {
      return LiquidGlassContainer(
        borderRadius: 0,
        tint: const Color(0x99FFFFFF),
        child: content,
      );
    }
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: ColoredBox(color: const Color(0xB8FFFFFF), child: content),
      ),
    );
  }
}

/// 分组卡片：圆角 12、白底、可选内嵌分隔线。
class IosGroup extends StatelessWidget {
  const IosGroup({super.key, required this.children, this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 12)});

  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(const Divider(
          height: 0.5,
          thickness: 0.5,
          indent: 16,
          endIndent: 16,
          color: TavernColors.separator,
        ));
      }
      rows.add(children[i]);
    }
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: TavernColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}

/// 标准列表行（iOS 设置风格）。
class IosCell extends StatelessWidget {
  const IosCell({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final Widget body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    color: destructive ? TavernColors.danger : TavernColors.text,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: TavernText.caption),
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 8),
            trailing!,
          ] else if (onTap != null)
            const Icon(Icons.chevron_right, size: 18, color: TavernColors.textFaint),
        ],
      ),
    );
    if (onTap == null) return body;
    return InkWell(onTap: onTap, child: body);
  }
}

/// 分段标题（分组卡片上方的小灰字）。
class IosSectionHeader extends StatelessWidget {
  const IosSectionHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 7),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: TavernColors.textMuted,
        ),
      ),
    );
  }
}

/// iOS 系统开关。
class IosSwitch extends StatelessWidget {
  const IosSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (_isIOS) {
      return CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: TavernColors.accent,
      );
    }
    return Switch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: TavernColors.accent,
      activeThumbColor: Colors.white,
      trackOutlineColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    );
  }
}
