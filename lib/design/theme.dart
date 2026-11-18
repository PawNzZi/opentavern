import 'dart:math' as math;
import 'dart:ui';

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
  AppPalette copyWith({bool? isDark}) => isDark == null
      ? this
      : (isDark ? AppPalette.dark : AppPalette.light);

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

ThemeData buildTavernTheme({required bool dark}) {
  final p = dark ? AppPalette.dark : AppPalette.light;
  final base = ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: p.canvasTop,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
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

/// The ambient backdrop: deep ink + slow colored light. Every glass surface
/// samples from this, which is what makes the material feel alive.
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
    final size = MediaQuery.sizeOf(context);
    final t = animate
        ? (DateTime.now().millisecondsSinceEpoch % 24000) / 24000
        : 0.0;
    final drift = math.sin(t * math.pi * 2) * 18;

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
        _Orb(
          left: -size.width * .38 + drift,
          top: -size.height * .12,
          size: size.width * 1.15,
          color: p.orbAmber.withValues(alpha: .55 * intensity),
          blur: 90,
        ),
        _Orb(
          left: size.width * .48 - drift,
          top: size.height * .02,
          size: size.width * .9,
          color: p.orbRose.withValues(alpha: .42 * intensity),
          blur: 100,
        ),
        _Orb(
          left: -size.width * .3,
          top: size.height * .52,
          size: size.width * 1.0,
          color: p.orbSage.withValues(alpha: .26 * intensity),
          blur: 110,
        ),
        _Orb(
          left: size.width * .55,
          top: size.height * .62,
          size: size.width * .8,
          color: p.orbViolet.withValues(alpha: .3 * intensity),
          blur: 110,
        ),
        // A quiet vignette keeps the glass edges readable.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.1,
              colors: [
                Colors.transparent,
                p.canvasBottom.withValues(alpha: p.isDark ? .55 : .25),
              ],
            ),
          ),
        ),
        const Positioned.fill(child: IgnorePointer(child: _Grain())),
        child,
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({
    required this.left,
    required this.top,
    required this.size,
    required this.color,
    required this.blur,
  });

  final double left;
  final double top;
  final double size;
  final Color color;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}

/// 1px film grain. Barely visible, but it stops large blurs from banding.
class _Grain extends StatelessWidget {
  const _Grain();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GrainPainter(), size: Size.infinite);
  }
}

class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final paint = Paint()..color = Colors.white.withValues(alpha: .022);
    for (var i = 0; i < 520; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        .6,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
