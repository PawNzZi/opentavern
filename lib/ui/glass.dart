/// 液态玻璃可用性判断与降级组件。
library;

import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// 当前设备是否 iOS 26+（系统玻璃 `glassEffect` 从 iOS 26 开始提供）。
bool get supportsLiquidGlass {
  if (!Platform.isIOS) {
    return false;
  }
  final RegExpMatch? match = RegExp(r'(\d+)\.').firstMatch(Platform.operatingSystemVersion);
  final int major = match == null ? 0 : (int.tryParse(match.group(1) ?? '') ?? 0);
  return major >= 26;
}

/// iOS < 26 或非 iOS 时的毛玻璃替代实现（模糊 + 半透明白 + 亮描边）。
class FallbackGlass extends StatelessWidget {
  const FallbackGlass({
    super.key,
    required this.child,
    this.radius = 0,
    this.tint = const Color(0xCCFFFFFF),
    this.blur = 24,
  });

  final Widget child;
  final double radius;
  final Color tint;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final BorderRadius shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: ColoredBox(color: tint, child: child),
      ),
    );
  }
}
