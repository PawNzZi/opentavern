import 'package:flutter/material.dart';

import 'glass.dart';
import 'theme.dart';

/// A small glass toast that does not look like a Material snackbar.
void showTavernToast(BuildContext context, String text) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _ToastView(text: text),
  );
  overlay.insert(entry);
  Future<void>.delayed(const Duration(milliseconds: 1700), () {
    if (entry.mounted) entry.remove();
  });
}

class _ToastView extends StatefulWidget {
  const _ToastView({required this.text});

  final String text;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Positioned(
      left: 24,
      right: 24,
      bottom: 128,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _c,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, .15),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
            ),
            child: Center(
              child: Glass(
                radius: 18,
                blur: 26,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                child: Text(
                  widget.text,
                  style: appText(12.5, FontWeight.w500, p.textPrimary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showImportFailures(
  BuildContext context,
  List<String> failures,
) async {
  if (failures.isEmpty) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('导入失败'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final name in failures)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: SelectableText(name),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}
