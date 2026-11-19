import 'dart:ui';

import 'package:flutter/material.dart';

import 'theme.dart';

final ValueNotifier<bool> glassScrolling = ValueNotifier<bool>(false);

/// A frosted, rim-lit pane. The building block of the whole interface.
///
/// The material is deliberately restrained: one blur, one gradient, one
/// hairline of light. Content stays legible because the fill is tinted, not
/// transparent.
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

  Color _mix(Color glass, Color base) {
    if (tint == null) return glass;
    return Color.alphaBlend(base.withValues(alpha: tintStrength), glass);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: glassScrolling,
      builder: (context, scrolling, _) =>
          _buildPane(context, blur > 0 && !scrolling),
    );
  }

  Widget _buildPane(BuildContext context, bool allowBlur) {
    final p = AppPalette.of(context);
    final br = BorderRadius.circular(radius);
    final base = tint ?? Colors.white;

    Widget pane = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _mix(p.glassTop, base).withValues(
              alpha: (p.glassTop.a * fill).clamp(0.0, 1.0),
            ),
            _mix(p.glassBottom, base).withValues(
              alpha: (p.glassBottom.a * fill).clamp(0.0, 1.0),
            ),
          ],
        ),
        border: stroke ? Border.all(color: p.glassStroke, width: .8) : null,
      ),
      child: Stack(
        children: [
          if (padding != null)
            Padding(padding: padding!, child: child)
          else
            child,
          if (highlight)
            Positioned(
              top: 0,
              left: radius * .6,
              right: radius * .6,
              child: IgnorePointer(
                child: Container(
                  height: .9,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(
                          alpha: p.isDark ? .38 : .85,
                        ),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (allowBlur) {
      pane = ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: pane,
        ),
      );
    } else {
      pane = ClipRRect(borderRadius: br, child: pane);
    }

    if (shadow) {
      pane = Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: br,
          boxShadow: [
            BoxShadow(
              color: p.glassShadow.withValues(alpha: p.isDark ? .38 : .10),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: pane,
      );
    }

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
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
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
                color: selected ? p.chipActiveText : p.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: appText(
                13.5,
                FontWeight.w500,
                selected ? p.chipActiveText : p.textSecondary,
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
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(26, 0, 26, 10),
      child: Glass(
        radius: 34,
        blur: 34,
        shadow: true,
        tint: tint,
        tintStrength: tintStrength,
        fill: fill,
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          height: 58,
          child: Row(
            children: List.generate(tabs.length, (i) {
              final active = i == index;
              final tab = tabs[i];
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      color: active
                          ? p.amber.withValues(alpha: p.isDark ? .20 : .22)
                          : Colors.transparent,
                      border: active
                          ? Border.all(
                              color: p.amber.withValues(alpha: .38),
                              width: .8,
                            )
                          : null,
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
  });

  final String initial;
  final List<Color> colors;
  final double radius;
  final bool showInitial;

  @override
  Widget build(BuildContext context) {
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
              Positioned(
                right: -w * .22,
                top: -h * .10,
                child: _Blob(
                  size: s * .9,
                  color: Colors.white.withValues(alpha: .38),
                  blur: 34,
                ),
              ),
              Positioned(
                left: -w * .30,
                bottom: -h * .12,
                child: _Blob(
                  size: s * .85,
                  color: colors.last.withValues(alpha: .65),
                  blur: 40,
                ),
              ),
              Positioned(
                left: w * .22,
                top: h * .30,
                child: _Blob(
                  size: s * .36,
                  color: Colors.white.withValues(alpha: .20),
                  blur: 26,
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
              if (showInitial)
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

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color, required this.blur});

  final double size;
  final Color color;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
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
