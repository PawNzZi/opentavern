import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'glass.dart';
import 'theme.dart';

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

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: isNested
          ? body
          : AuroraBackground(intensity: intensity, child: body),
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

/// The visual body of a bottom sheet: grab handle, header, a scrollable body
/// and an optional pinned footer.
///
/// [SheetStage] draws its own backdrop and uses it directly; [showTavernSheet]
/// presents it over the current screen. Both keep the panel capped in height
/// and let the body scroll, so short content stays compact and long content
/// stays usable.
class SheetPanel extends StatelessWidget {
  const SheetPanel({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.child,
    this.footer,
    this.showClose = true,
    required this.onClose,
    this.bottomSafeArea = 0,
    this.onGrabberDragUpdate,
    this.onGrabberDragEnd,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget child;
  final Widget? footer;
  final bool showClose;
  final VoidCallback onClose;
  final double bottomSafeArea;
  final GestureDragUpdateCallback? onGrabberDragUpdate;
  final GestureDragEndCallback? onGrabberDragEnd;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    const radius = BorderRadius.vertical(top: Radius.circular(36));
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .38),
            blurRadius: 48,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Glass(
          radius: 0,
          blur: 40,
          fill: 1.6,
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: onGrabberDragUpdate,
                onVerticalDragEnd: onGrabberDragEnd,
                child: SizedBox(
                  height: 30,
                  child: Center(
                    child: Container(
                      width: 38,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: p.textTertiary.withValues(alpha: .7),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 16, 0),
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
                    if (showClose)
                      GlassCircleButton(
                        icon: Icons.close_rounded,
                        size: 38,
                        iconSize: 16,
                        blur: 0,
                        onTap: onClose,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    22,
                    0,
                    22,
                    20 + (footer == null ? bottomSafeArea : 0),
                  ),
                  physics: const BouncingScrollPhysics(),
                  child: child,
                ),
              ),
              if (footer != null)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    22,
                    12,
                    22,
                    12 + bottomSafeArea,
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
    );
  }
}

/// A bottom sheet pushed as its own route.
///
/// It draws a dimmed backdrop and anchors a rounded panel to the bottom of the
/// screen, capped at [heightFactor] of the available height. The body scrolls
/// on its own; only the top grab handle drags the panel, so lists and text
/// fields keep their gestures.
///
/// It stays a real route so a sheet can still be opened (and screenshotted) on
/// its own. For sheets opened on top of the current screen prefer
/// [showTavernSheet].
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
    duration: const Duration(milliseconds: 280),
  )..forward();

  double _drag = 0;
  bool _closing = false;

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_closing) return;
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) {
      if (_drag != 0) setState(() => _drag = 0);
      return;
    }
    _closing = true;
    await _entry.reverse();
    if (!mounted) return;
    final popped = await navigator.maybePop();
    if (!popped && mounted) {
      _closing = false;
      _entry.forward();
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _drag = (_drag + details.delta.dy).clamp(0.0, 360.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_drag > 80 || velocity > 500) {
      _dismiss();
    } else {
      setState(() => _drag = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final size = media.size;
    final available = math.max(200.0, size.height - keyboard - media.padding.top);
    final panelMax = available * widget.heightFactor.clamp(.3, .92).toDouble();

    return TavernScaffold(
      intensity: 1.1,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismiss,
              child: AnimatedBuilder(
                animation: _entry,
                builder: (context, _) => ColoredBox(
                  color: Colors.black.withValues(alpha: .46 * _entry.value),
                ),
              ),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: keyboard,
            child: AnimatedBuilder(
              animation: _entry,
              builder: (context, child) {
                final enter = (1 - _entry.value) * 60;
                return Transform.translate(
                  offset: Offset(0, _drag + enter),
                  child: Opacity(
                    opacity: _entry.value.clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: panelMax),
                child: SheetPanel(
                  title: widget.title,
                  subtitle: widget.subtitle,
                  leading: widget.leading,
                  footer: widget.footer,
                  showClose: widget.showClose,
                  bottomSafeArea: keyboard > 0 ? 0 : media.padding.bottom,
                  onClose: _dismiss,
                  onGrabberDragUpdate: _onDragUpdate,
                  onGrabberDragEnd: _onDragEnd,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows a compact bottom sheet on top of the current screen.
///
/// Use it for short content (attachment pickers, bound lorebooks, …). Long
/// editors should stay on a [DetailPage] instead.
Future<T?> showTavernSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  Widget? leading,
  required Widget child,
  Widget? footer,
  double heightFactor = .86,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: Colors.black.withValues(alpha: .46),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (dialogContext, _, _) => _SheetDialogLayout(
      heightFactor: heightFactor,
      builder: (bottomSafeArea) => SheetPanel(
        title: title,
        subtitle: subtitle,
        leading: leading,
        footer: footer,
        bottomSafeArea: bottomSafeArea,
        onClose: () => Navigator.of(dialogContext).pop(),
        onGrabberDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 280) {
            Navigator.of(dialogContext).pop();
          }
        },
        child: child,
      ),
    ),
    transitionBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, .08),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _SheetDialogLayout extends StatelessWidget {
  const _SheetDialogLayout({required this.heightFactor, required this.builder});

  final double heightFactor;
  final Widget Function(double bottomSafeArea) builder;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final available = math.max(
      200.0,
      media.size.height - keyboard - media.padding.top,
    );
    final maxHeight = available * heightFactor.clamp(.3, .92).toDouble();
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
            child: builder(keyboard > 0 ? 0 : media.padding.bottom),
          ),
        ),
      ),
    );
  }
}
