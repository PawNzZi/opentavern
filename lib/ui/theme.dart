/// iOS 风格的设计令牌与主题。
library;

import 'package:flutter/material.dart';

class TavernColors {
  const TavernColors._();

  /// iOS 系统分组灰（页面底）。
  static const Color bg = Color(0xFFF2F2F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color separator = Color(0xFFE4E4E9);

  /// 系统蓝：控件与选中态。
  static const Color accent = Color(0xFF0A84FF);

  /// 台词引用色（与旧版酒馆保持一致）。
  static const Color quote = Color(0xFF00AF69);

  static const Color text = Color(0xFF1C1C1E);
  static const Color textSecondary = Color(0xFF545456);
  static const Color textMuted = Color(0xFF8A8A8E);
  static const Color textFaint = Color(0xFFB0B0B5);
  static const Color danger = Color(0xFFD92D20);
}

class TavernRadius {
  const TavernRadius._();

  static const double card = 14;
  static const double field = 10;
  static const double pill = 999;
}

class TavernText {
  const TavernText._();

  static const TextStyle largeTitle = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    color: TavernColors.text,
  );

  static const TextStyle title = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: TavernColors.text,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    height: 1.5,
    color: TavernColors.text,
  );

  static const TextStyle secondary = TextStyle(
    fontSize: 13,
    height: 1.45,
    color: TavernColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: TavernColors.textMuted,
  );

  static const TextStyle tiny = TextStyle(
    fontSize: 11,
    color: TavernColors.textFaint,
  );
}

ThemeData buildTavernTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: TavernColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: TavernColors.accent,
      brightness: Brightness.light,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
