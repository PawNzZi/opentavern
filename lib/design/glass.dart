import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

import 'theme.dart';

/// A flat, quiet surface used across the app.
///
/// The old "liquid glass" implementation used a full-screen BackdropFilter for
/// every card. On low-end phones that is one of the most expensive things a
/// Flutter UI can do while scrolling. The public API is kept so existing
/// screens do not need to change; blur/fill/highlight are accepted but the
/// render path is now a cheap opaque surface with a hairline border.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 26,
    this.blur = 26,
    this.padding,
    this.tint,
    this.fill = 1,
    this.tintStrength = .16,
    this.shadow = true,
    this.stroke = true,
    this.highlight = true,
    this.onTap,
    this.width,
    this.height,
  });

  final Widget child;
  final double radius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final Color? tint;
  final double fill;
  final double tintStrength;
  final bool shadow;
  final bool stroke;
  final bool highlight;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final br = BorderRadius.circular(radius);
    final dark = p.isDark;
    final base = tint ??
        (dark ? const Color(0xFF141821) : const Color(0xFFFFFCF8));
    final top = Color.alphaBlend(
      Colors.white.withValues(
        alpha: tint != null ? (dark ? .05 : .10) : (dark ? .035 : .30),
      ),
      base,
    );
    final bottom = Color.alphaBlend(
      Colors.white.withValues(alpha: dark ? .01 : .16),
      base,
    );

    Widget pane = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: br,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, bottom],
        ),
        border: stroke
            ? Border.all(
                color: p.isDark
                    ? Colors.white.withValues(alpha: .08)
                    : Colors.black.withValues(alpha: .08),
                width: .8,
              )
            : null,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: p.isDark ? .18 : .08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: br,
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );

    if (onTap != null) {
      pane = Pressable(onTap: onTap, child: pane);
    }
    return pane;
  }
}

/// A tiny springy press state. 120ms is fast enough to feel instant.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = .965,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: widget.child,
    );
  }
}

class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 44,
    this.iconSize,
    this.iconColor,
    this.tint,
    this.blur = 22,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double? iconSize;
  final Color? iconColor;
  final Color? tint;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Glass(
      radius: size / 2,
      blur: blur,
      tint: tint,
      onTap: onTap,
      shadow: false,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(
          icon,
          size: iconSize ?? size * .42,
          color: iconColor ?? p.textPrimary,
        ),
      ),
    );
  }
}

/// Primary action: a warm liquid gradient rather than a flat accent.
class GlassPrimaryButton extends StatelessWidget {
  const GlassPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.height = 54,
    this.expand = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final child = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.userBubbleStart, p.userBubbleEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: p.amber.withValues(alpha: .28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: p.onUserBubble),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: appText(16, FontWeight.w600, p.onUserBubble),
          ),
        ],
      ),
    );
    return Pressable(
      onTap: onTap,
      child: expand ? SizedBox(width: double.infinity, child: child) : child,
    );
  }
}

class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.height = 38,
    this.selected = false,
    this.tint,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double height;
  final bool selected;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Glass(
      radius: height / 2,
      blur: 18,
      shadow: false,
      tint: selected ? p.amber : tint,
      fill: selected ? 1.6 : 1,
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? p.onUserBubble : p.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: appText(
                13.5,
                FontWeight.w500,
                selected ? p.onUserBubble : p.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GlassTabBar extends StatelessWidget {
  const GlassTabBar({
    super.key,
    required this.index,
    required this.onChanged,
    required this.tabs,
    this.tint,
    this.tintStrength = .16,
    this.fill = 1,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final List<TabSpec> tabs;
  final Color? tint;
  final double tintStrength;
  final double fill;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    // iOS uses the platform-style tab bar; on iOS 26 this is the system
    // bottom bar instead of a hand-built blur pane.
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      if (NativeLiquidGlassUtils.supportsLiquidGlass) {
        return LiquidGlassTabBar(
          currentIndex: index,
          onTabSelected: onChanged,
          height: 72,
          selectedItemColor: p.amber,
          labelTextStyle: appText(10.5, FontWeight.w500, p.textTertiary),
          items: [
            for (final tab in tabs)
              LiquidGlassTabItem(
                label: tab.label,
                icon: NativeLiquidGlassIcon.iconData(tab.icon),
              ),
          ],
        );
      }
      return SafeArea(
        top: false,
        child: cupertino.CupertinoTabBar(
          currentIndex: index,
          onTap: onChanged,
          height: 58,
          backgroundColor:
              p.isDark ? const Color(0xF2151820) : const Color(0xF7FFFCF8),
          activeColor: p.amber,
          inactiveColor: p.textTertiary,
          border: Border(
            top: BorderSide(
              color: p.isDark
                  ? Colors.white.withValues(alpha: .08)
                  : Colors.black.withValues(alpha: .08),
              width: .5,
            ),
          ),
          items: [
            for (final tab in tabs)
              BottomNavigationBarItem(
                icon: Icon(tab.icon, size: 21),
                activeIcon: Icon(tab.icon, size: 21),
                label: tab.label,
              ),
          ],
        ),
      );
    }

    // Android/other platforms: flat bar, no blur and no animated pill.
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: p.isDark ? const Color(0xFF171B24) : const Color(0xFFFFFCF8),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: p.isDark
                ? Colors.white.withValues(alpha: .08)
                : Colors.black.withValues(alpha: .08),
            width: .8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: p.isDark ? .22 : .08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final active = i == index;
            final tab = tabs[i];
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: active
                        ? p.amber.withValues(alpha: p.isDark ? .18 : .16)
                        : Colors.transparent,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tab.icon,
                        size: 21,
                        color: active ? p.amber : p.textTertiary,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tab.label,
                        style: appText(
                          10.5,
                          active ? FontWeight.w600 : FontWeight.w500,
                          active ? p.amber : p.textTertiary,
                          letterSpacing: .2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class TabSpec {
  const TabSpec(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// Editorial gradient portrait. We avoid stock photos in the prototype so the
/// design reads as one system; production can drop a real image in.
class Portrait extends StatelessWidget {
  const Portrait({
    super.key,
    required this.initial,
    required this.colors,
    this.radius = 24,
    this.showInitial = true,
    this.avatarBase64,
  });

  final String initial;
  final List<Color> colors;
  final double radius;
  final bool showInitial;
  final String? avatarBase64;

  Uint8List? _avatarBytes() {
    final raw = avatarBase64;
    if (raw == null || raw.isEmpty) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _avatarBytes();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: LayoutBuilder(
        builder: (context, constr) {
          final w = constr.maxWidth.isFinite ? constr.maxWidth : 200.0;
          final h = constr.maxHeight.isFinite ? constr.maxHeight : w * 1.3;
          final s = w > h ? h : w;
          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                ),
              ),
              if (avatar != null)
                Positioned.fill(
                  child: Image.memory(
                    avatar,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: .02),
                      Colors.black.withValues(alpha: .06),
                      Colors.black.withValues(alpha: .52),
                    ],
                    stops: const [0, .55, 1],
                  ),
                ),
              ),
              if (showInitial && avatar == null)
                Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: s * .44,
                      height: 1,
                      fontWeight: FontWeight.w200,
                      color: Colors.white.withValues(alpha: .22),
                      letterSpacing: -4,
                    ),
                  ),
                ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .12),
                        width: .8,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(
        children: [
          Text(
            text,
            style: appText(
              11.5,
              FontWeight.w600,
              p.textTertiary,
              letterSpacing: 1.4,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class Hairline extends StatelessWidget {
  const Hairline({super.key, this.indent = 0});
  final double indent;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Container(height: .6, color: p.divider),
    );
  }
}
