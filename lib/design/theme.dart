import 'dart:ui';

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// The visual language of the app: a warm, low-contrast "tavern at night"
/// palette that gives the liquid glass something beautiful to refract.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.isDark,
    required this.canvasTop,
    required this.canvasBottom,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.amber,
    required this.amberSoft,
    required this.rose,
    required this.sage,
    required this.violet,
    required this.danger,
    required this.glassTop,
    required this.glassBottom,
    required this.glassStroke,
    required this.glassShadow,
    required this.chipActiveFill,
    required this.chipActiveStroke,
    required this.chipActiveText,
    required this.userBubbleStart,
    required this.userBubbleEnd,
    required this.onUserBubble,
    required this.divider,
    required this.orbAmber,
    required this.orbRose,
    required this.orbSage,
    required this.orbViolet,
  });

  final bool isDark;
  final Color canvasTop;
  final Color canvasBottom;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color amber;
  final Color amberSoft;
  final Color rose;
  final Color sage;
  final Color violet;
  final Color danger;
  final Color glassTop;
  final Color glassBottom;
  final Color glassStroke;
  final Color glassShadow;
  final Color chipActiveFill;
  final Color chipActiveStroke;
  final Color chipActiveText;
  final Color userBubbleStart;
  final Color userBubbleEnd;
  final Color onUserBubble;
  final Color divider;
  final Color orbAmber;
  final Color orbRose;
  final Color orbSage;
  final Color orbViolet;

  static const dark = AppPalette(
    isDark: true,
    canvasTop: Color(0xFF0C0E15),
    canvasBottom: Color(0xFF05060A),
    textPrimary: Color(0xFFF6F2EB),
    textSecondary: Color(0x9EF6F2EB),
    textTertiary: Color(0x5CF6F2EB),
    amber: Color(0xFFF0B36A),
    amberSoft: Color(0x33F0B36A),
    rose: Color(0xFFEE9AA8),
    sage: Color(0xFF8FD0BE),
    violet: Color(0xFFA9A0E8),
    danger: Color(0xFFF27D72),
    glassTop: Color(0x26FFFFFF),
    glassBottom: Color(0x0DFFFFFF),
    glassStroke: Color(0x2EFFFFFF),
    glassShadow: Color(0x66000000),
    chipActiveFill: Color(0x33F0B36A),
    chipActiveStroke: Color(0x80F0B36A),
    chipActiveText: Color(0xFFFFD9A3),
    userBubbleStart: Color(0xFFF3B877),
    userBubbleEnd: Color(0xFFE98F6B),
    onUserBubble: Color(0xFF241405),
    divider: Color(0x14FFFFFF),
    orbAmber: Color(0xFFE89A4E),
    orbRose: Color(0xFFD96C83),
    orbSage: Color(0xFF3E9C8E),
    orbViolet: Color(0xFF6A5BC4),
  );

  static const light = AppPalette(
    isDark: false,
    canvasTop: Color(0xFFFBF6EF),
    canvasBottom: Color(0xFFEDE3D6),
    textPrimary: Color(0xFF1A1612),
    textSecondary: Color(0x9E1A1612),
    textTertiary: Color(0x5C1A1612),
    amber: Color(0xFFB96F26),
    amberSoft: Color(0x2EB96F26),
    rose: Color(0xFFC46172),
    sage: Color(0xFF3F8677),
    violet: Color(0xFF6D61B8),
    danger: Color(0xFFC64A40),
    glassTop: Color(0xB8FFFFFF),
    glassBottom: Color(0x70FFFFFF),
    glassStroke: Color(0xB3FFFFFF),
    glassShadow: Color(0x1F3A2A18),
    chipActiveFill: Color(0x33B96F26),
    chipActiveStroke: Color(0x80B96F26),
    chipActiveText: Color(0xFF6B3D0E),
    userBubbleStart: Color(0xFFF2B46F),
    userBubbleEnd: Color(0xFFE58F63),
    onUserBubble: Color(0xFF2A1707),
    divider: Color(0x141A1612),
    orbAmber: Color(0xFFF6C27E),
    orbRose: Color(0xFFEBA3AE),
    orbSage: Color(0xFF9AD3C4),
    orbViolet: Color(0xFFBDB4F0),
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? dark;

  @override
  AppPalette copyWith({
    bool? isDark,
    Color? canvasTop,
    Color? canvasBottom,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? amber,
    Color? amberSoft,
    Color? rose,
    Color? sage,
    Color? violet,
    Color? danger,
    Color? glassTop,
    Color? glassBottom,
    Color? glassStroke,
    Color? glassShadow,
    Color? chipActiveFill,
    Color? chipActiveStroke,
    Color? chipActiveText,
    Color? userBubbleStart,
    Color? userBubbleEnd,
    Color? onUserBubble,
    Color? divider,
    Color? orbAmber,
    Color? orbRose,
    Color? orbSage,
    Color? orbViolet,
  }) {
    return AppPalette(
      isDark: isDark ?? this.isDark,
      canvasTop: canvasTop ?? this.canvasTop,
      canvasBottom: canvasBottom ?? this.canvasBottom,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      amber: amber ?? this.amber,
      amberSoft: amberSoft ?? this.amberSoft,
      rose: rose ?? this.rose,
      sage: sage ?? this.sage,
      violet: violet ?? this.violet,
      danger: danger ?? this.danger,
      glassTop: glassTop ?? this.glassTop,
      glassBottom: glassBottom ?? this.glassBottom,
      glassStroke: glassStroke ?? this.glassStroke,
      glassShadow: glassShadow ?? this.glassShadow,
      chipActiveFill: chipActiveFill ?? this.chipActiveFill,
      chipActiveStroke: chipActiveStroke ?? this.chipActiveStroke,
      chipActiveText: chipActiveText ?? this.chipActiveText,
      userBubbleStart: userBubbleStart ?? this.userBubbleStart,
      userBubbleEnd: userBubbleEnd ?? this.userBubbleEnd,
      onUserBubble: onUserBubble ?? this.onUserBubble,
      divider: divider ?? this.divider,
      orbAmber: orbAmber ?? this.orbAmber,
      orbRose: orbRose ?? this.orbRose,
      orbSage: orbSage ?? this.orbSage,
      orbViolet: orbViolet ?? this.orbViolet,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return t < .5 ? this : other;
  }
}

/// Type scale. Inter for Latin, Noto Sans SC for Chinese (falls back to
/// PingFang on iOS, which is the system font we actually want there).
TextStyle appText(
  double size,
  FontWeight weight,
  Color color, {
  double? height,
  double? letterSpacing,
  FontStyle? style,
}) {
  return TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: const [
      'NotoSansSC',
      'PingFang SC',
      'SF Pro Text',
      'Microsoft YaHei',
      'sans-serif',
    ],
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation('wght', weight.value.toDouble())],
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    fontStyle: style,
    decoration: TextDecoration.none,
  );
}

/// Recolors the primary accent family (the `amber` slots, chips, sliders,
/// orbs and the user bubble) to one of the four accent options. `amber` is
/// the default and returns the base palette unchanged, so the stock look is
/// preserved exactly. The user bubble always stays a light pastel of the
/// accent so the dark `onUserBubble` text keeps its contrast in both themes.
AppPalette applyAccent(AppPalette base, String accent) {
  final Color main;
  final Color bubbleStart;
  final Color bubbleEnd;
  switch (accent) {
    case 'rose':
      main = base.isDark ? const Color(0xFFEE9AA8) : const Color(0xFFC46172);
      bubbleStart = const Color(0xFFF2AEB9);
      bubbleEnd = const Color(0xFFE5929F);
      break;
    case 'sage':
      main = base.isDark ? const Color(0xFF8FD0BE) : const Color(0xFF3F8677);
      bubbleStart = const Color(0xFFA5DCCB);
      bubbleEnd = const Color(0xFF86C8B4);
      break;
    case 'violet':
      main = base.isDark ? const Color(0xFFA9A0E8) : const Color(0xFF6D61B8);
      bubbleStart = const Color(0xFFBDB5F0);
      bubbleEnd = const Color(0xFFA89FE6);
      break;
    default:
      return base;
  }
  final chipText = base.isDark
      ? Color.lerp(main, Colors.white, .55)!
      : Color.lerp(main, Colors.black, .45)!;
  return base.copyWith(
    amber: main,
    amberSoft: main.withValues(alpha: .2),
    chipActiveFill: main.withValues(alpha: .2),
    chipActiveStroke: main.withValues(alpha: .5),
    chipActiveText: chipText,
    userBubbleStart: bubbleStart,
    userBubbleEnd: bubbleEnd,
    orbAmber: main,
  );
}

ThemeData buildTavernTheme({required bool dark, String accent = 'amber'}) {
  final p = applyAccent(dark ? AppPalette.dark : AppPalette.light, accent);
  final base = ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: p.canvasTop,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
  return base.copyWith(
    extensions: [p],
    textTheme: base.textTheme.apply(
      bodyColor: p.textPrimary,
      displayColor: p.textPrimary,
    ),
    iconTheme: IconThemeData(color: p.textPrimary, size: 20),
  );
}

/// Flat ambient background: a static warm gradient plus two cheap radial
/// washes. No BackdropFilter, no animated blur, no film grain.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({
    super.key,
    required this.child,
    this.intensity = 1,
    this.animate = false,
  });

  final Widget child;
  final double intensity;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [p.canvasTop, p.canvasBottom],
            ),
          ),
        ),
        Positioned(
          left: -140,
          top: -180,
          width: 460,
          height: 460,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    p.orbAmber.withValues(alpha: .16 * intensity),
                    p.orbAmber.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: -180,
          bottom: 80,
          width: 520,
          height: 520,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    p.orbViolet.withValues(alpha: .11 * intensity),
                    p.orbViolet.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.15,
              colors: [
                Colors.transparent,
                p.canvasBottom.withValues(alpha: p.isDark ? .35 : .16),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
