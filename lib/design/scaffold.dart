import 'dart:async';

import 'package:flutter/material.dart';

import 'glass.dart';
import 'theme.dart';

Timer? _glassScrollTimer;

void _pulseGlassScroll() {
  glassScrolling.value = true;
  _glassScrollTimer?.cancel();
  _glassScrollTimer = Timer(const Duration(milliseconds: 180), () {
    glassScrolling.value = false;
  });
}

class TavernRootScope extends InheritedWidget {
  const TavernRootScope({super.key, required this.enabled, required super.child});

  final bool enabled;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TavernRootScope>()?.enabled ??
      false;

  @override
  bool updateShouldNotify(TavernRootScope oldWidget) => enabled != oldWidget.enabled;
}

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
    final isNested = TavernRootScope.of(context);
    final content = bottomNavigation != null
        ? TavernRootScope(enabled: true, child: child)
        : child;
    final body = Stack(
      children: [
        Positioned.fill(child: content),
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
    );

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _pulseGlassScroll();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        body: isNested
            ? body
            : AuroraBackground(intensity: intensity, child: body),
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
    this.controller,
    this.onChanged,
    this.autofocus = false,
  });

  final String hint;
  final Widget? trailing;
  final VoidCallback? onTap;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final editable = controller != null;
    return Glass(
      radius: 26,
      blur: 20,
      shadow: false,
      onTap: editable ? null : onTap,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(Icons.search_rounded, size: 19, color: p.textTertiary),
            const SizedBox(width: 10),
            Expanded(
              child: editable
                  ? TextField(
                      controller: controller,
                      autofocus: autofocus,
                      onChanged: onChanged,
                      cursorColor: p.amber,
                      textInputAction: TextInputAction.search,
                      style: appText(14.5, FontWeight.w400, p.textPrimary),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: hint,
                        hintStyle: appText(
                          14.5,
                          FontWeight.w400,
                          p.textTertiary,
                        ),
                      ),
                    )
                  : Text(
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
/// Bottom sheet used by editors, chat info and import flows. It is a real
/// screen so it can be previewed standalone, but it behaves like a sheet:
/// tap the dimmed backdrop or swipe the header down to dismiss.
class SheetStage extends StatefulWidget {
  const SheetStage({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.footer,
    this.heightFactor = .84,
    this.leading,
    this.showClose = true,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;
  final double heightFactor;
  final Widget? leading;
  final bool showClose;

  @override
  State<SheetStage> createState() => _SheetStageState();
}

class _SheetStageState extends State<SheetStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();

  double _drag = 0;

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      setState(() => _drag = 0);
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _drag = (_drag + details.delta.dy).clamp(0.0, 360.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_drag > 90 || velocity > 500) {
      _dismiss();
    } else {
      setState(() => _drag = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final h = MediaQuery.sizeOf(context).height;
    final radius = BorderRadius.circular(36);

    return TavernScaffold(
      intensity: 1.1,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismiss,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: p.isDark ? .38 : .18),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _entry,
            builder: (context, child) {
              final enter = (1 - _entry.value) * 48;
              return Positioned(
                left: 8,
                right: 8,
                bottom: 0,
                child: Transform.translate(
                  offset: Offset(0, _drag + enter),
                  child: Opacity(
                    opacity: _entry.value.clamp(0.0, 1.0),
                    child: child,
                  ),
                ),
              );
            },
            child: Container(
              height: h * widget.heightFactor,
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
                  borderRadius: radius,
                  child: Column(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
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
                              padding: const EdgeInsets.fromLTRB(22, 18, 16, 0),
                              child: Row(
                                children: [
                                  if (widget.leading != null) ...[
                                    widget.leading!,
                                    const SizedBox(width: 12),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.title,
                                          style: appText(
                                            22,
                                            FontWeight.w700,
                                            p.textPrimary,
                                            letterSpacing: -.6,
                                          ),
                                        ),
                                        if (widget.subtitle != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            widget.subtitle!,
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
                                  if (widget.showClose)
                                    GlassCircleButton(
                                      icon: Icons.close_rounded,
                                      size: 38,
                                      iconSize: 16,
                                      blur: 0,
                                      onTap: _dismiss,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            22,
                            0,
                            22,
                            widget.footer != null ? 96 : 20,
                          ),
                          child: widget.child,
                        ),
                      ),
                      if (widget.footer != null)
                        Container(
                          padding: EdgeInsets.fromLTRB(
                            22,
                            12,
                            22,
                            12 + MediaQuery.paddingOf(context).bottom,
                          ),
                          decoration: BoxDecoration(
                            color: p.canvasTop.withValues(alpha: .97),
                            border: Border(
                              top: BorderSide(color: p.divider, width: .6),
                            ),
                          ),
                          child: widget.footer,
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
