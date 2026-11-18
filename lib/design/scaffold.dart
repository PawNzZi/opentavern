import 'package:flutter/material.dart';

import 'glass.dart';
import 'theme.dart';

class TavernScaffold extends StatelessWidget {
  const TavernScaffold({
    super.key,
    required this.child,
    this.bottomNavigation,
    this.intensity = 1,
    this.resizeToAvoidBottomInset = false,
  });

  final Widget child;
  final Widget? bottomNavigation;
  final double intensity;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: AuroraBackground(
        intensity: intensity,
        child: Stack(
          children: [
            Positioned.fill(child: child),
            if (bottomNavigation != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 144,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          p.canvasTop.withValues(alpha: 0),
                          p.canvasTop.withValues(alpha: .92),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (bottomNavigation != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: bottomNavigation!,
              ),
          ],
        ),
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!,
            style: appText(
              10.5,
              FontWeight.w600,
              p.textTertiary,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                title,
                style: appText(
                  38,
                  FontWeight.w700,
                  p.textPrimary,
                  letterSpacing: -1.6,
                  height: 1.05,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: appText(
              14,
              FontWeight.w400,
              p.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.hint,
    this.trailing,
    this.onTap,
  });

  final String hint;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Glass(
      radius: 26,
      blur: 20,
      shadow: false,
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(Icons.search_rounded, size: 19, color: p.textTertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hint,
                style: appText(14.5, FontWeight.w400, p.textTertiary),
              ),
            ),
            if (trailing != null) trailing!,
            const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }
}

class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.iconColor,
    this.onTap,
    this.chevron = true,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final Color? iconColor;
  final VoidCallback? onTap;
  final bool chevron;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final tint = iconColor ?? p.amber;
    return Pressable(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
          children: [
            const SizedBox(width: 12),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: tint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: appText(15, FontWeight.w500, p.textPrimary),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appText(10, FontWeight.w400, p.textTertiary),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (value != null)
              Text(
                value!,
                style: appText(13, FontWeight.w400, p.textTertiary),
              ),
            if (chevron) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: p.textTertiary,
              ),
              const SizedBox(width: 10),
            ] else
              const SizedBox(width: 14),
          ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet used for connection, import and lore editing. Rendered as a
/// real screen in the prototype so it can be screenshotted on its own.
class SheetStage extends StatelessWidget {
  const SheetStage({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.footer,
    this.heightFactor = .84,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;
  final double heightFactor;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final h = MediaQuery.sizeOf(context).height;
    return TavernScaffold(
      intensity: 1.1,
      child: Stack(
        children: [
          // Dimmed context behind the sheet.
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: p.isDark ? .38 : .18),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 0,
            child: Container(
              height: h * heightFactor,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(36),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .35),
                    blurRadius: 50,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Glass(
                radius: 36,
                blur: 40,
                fill: 1.6,
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(36),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 38,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: p.textTertiary.withValues(alpha: .7),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
                        child: Row(
                          children: [
                            if (leading != null) ...[
                              leading!,
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: appText(
                                      22,
                                      FontWeight.w700,
                                      p.textPrimary,
                                      letterSpacing: -.6,
                                    ),
                                  ),
                                  if (subtitle != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle!,
                                      style: appText(
                                        12.5,
                                        FontWeight.w400,
                                        p.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                          child: child,
                        ),
                      ),
                      if (footer != null)
                        Container(
                          padding: EdgeInsets.fromLTRB(
                            22,
                            12,
                            22,
                            12 + MediaQuery.paddingOf(context).bottom,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: p.divider, width: .6),
                            ),
                          ),
                          child: footer,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
