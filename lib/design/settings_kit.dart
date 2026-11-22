import 'package:flutter/material.dart';

import 'glass.dart';
import 'scaffold.dart';
import 'theme.dart';

/// A secondary settings / detail page: back button, large title and a stack of
/// glass groups. One shape for every deep configuration screen keeps the app
/// predictable.
class DetailPage extends StatelessWidget {
  const DetailPage({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    required this.children,
    this.trailing,
    this.footer,
    this.padding = const EdgeInsets.fromLTRB(20, 6, 20, 40),
    this.resizeToAvoidBottomInset = false,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? trailing;
  final Widget? footer;
  final EdgeInsets padding;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return TavernScaffold(
      intensity: 1.02,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Row(
                children: [
                  GlassCircleButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    size: 40,
                    iconSize: 15,
                    onTap: () => Navigator.maybePop(context),
                  ),
                  const Spacer(),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: padding.copyWith(top: 0),
                physics: const BouncingScrollPhysics(),
                children: [
                  const SizedBox(height: 14),
                  PageHeader(
                    eyebrow: eyebrow,
                    title: title,
                    subtitle: subtitle,
                  ),
                  ...children,
                  const SizedBox(height: 28),
                ],
              ),
            ),
            if (footer != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  20,
                  10,
                  20,
                  10 + MediaQuery.paddingOf(context).bottom,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: p.divider, width: .6),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      p.canvasTop.withValues(alpha: .2),
                      p.canvasTop.withValues(alpha: .9),
                    ],
                  ),
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.title,
    required this.children,
    this.footnote,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final String? footnote;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(title, trailing: trailing),
        Glass(
          radius: 24,
          blur: 24,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) const Hairline(indent: 56),
              ],
            ],
          ),
        ),
        if (footnote != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
            child: Text(
              footnote!,
              style: appText(
                10.5,
                FontWeight.w400,
                p.textTertiary,
                height: 1.45,
              ),
            ),
          ),
      ],
    );
  }
}

class TavernSwitch extends StatelessWidget {
  const TavernSwitch({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: value
              ? p.amber.withValues(alpha: .85)
              : p.textTertiary.withValues(alpha: .22),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class SwitchLine extends StatelessWidget {
  const SwitchLine({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: appText(14, FontWeight.w500, p.textPrimary),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: appText(
                      10.5,
                      FontWeight.w400,
                      p.textTertiary,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          TavernSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class SliderLine extends StatelessWidget {
  const SliderLine({
    super.key,
    required this.title,
    required this.value,
    required this.display,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.onChanged,
  });

  final String title;
  final double value;
  final String display;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 9, 8, 4),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                title,
                style: appText(13.5, FontWeight.w500, p.textPrimary),
              ),
              const Spacer(),
              Text(
                display,
                style: appText(12, FontWeight.w600, p.amber),
              ),
              const SizedBox(width: 10),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: p.amber,
              inactiveTrackColor: p.textTertiary.withValues(alpha: .22),
              thumbColor: p.amber,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged ?? (_) {},
            ),
          ),
        ],
      ),
    );
  }
}

class SegmentLine extends StatelessWidget {
  const SegmentLine({
    super.key,
    required this.title,
    required this.options,
    required this.index,
    this.onChanged,
  });

  final String title;
  final List<String> options;
  final int index;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Text(
            title,
            style: appText(13.5, FontWeight.w500, p.textPrimary),
          ),
          const Spacer(),
          Glass(
            radius: 12,
            blur: 14,
            shadow: false,
            padding: const EdgeInsets.all(3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < options.length; i++)
                  GestureDetector(
                    onTap: onChanged == null ? null : () => onChanged!(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        color: i == index
                            ? p.amber.withValues(alpha: .2)
                            : Colors.transparent,
                      ),
                      child: Text(
                        options[i],
                        style: appText(
                          11,
                          i == index ? FontWeight.w600 : FontWeight.w400,
                          i == index ? p.amber : p.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ActionGrid extends StatelessWidget {
  const ActionGrid({super.key, required this.items, this.columns = 4});

  final List<ActionSpec> items;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Glass(
      radius: 24,
      blur: 24,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: Pressable(
                onTap: item.onTap,
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        color: (item.color ?? p.amber).withValues(alpha: .16),
                      ),
                      child: Icon(
                        item.icon,
                        size: 19,
                        color: item.color ?? p.amber,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      item.label,
                      style: appText(
                        10.5,
                        FontWeight.w500,
                        p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ActionSpec {
  const ActionSpec({
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;
}

class MiniStat extends StatelessWidget {
  const MiniStat({
    super.key,
    required this.value,
    required this.label,
    this.accent,
  });

  final String value;
  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: appText(
            22,
            FontWeight.w700,
            accent ?? p.textPrimary,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: appText(10, FontWeight.w400, p.textTertiary),
        ),
      ],
    );
  }
}

class HintCard extends StatelessWidget {
  const HintCard({
    super.key,
    required this.text,
    this.icon = Icons.lightbulb_outline_rounded,
    this.color,
  });

  final String text;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final tint = color ?? p.amber;
    return Glass(
      radius: 20,
      blur: 20,
      shadow: false,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: tint),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: appText(
                11.5,
                FontWeight.w400,
                p.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FieldBlock extends StatelessWidget {
  const FieldBlock({
    super.key,
    required this.label,
    required this.value,
    this.multiline = false,
    this.trailing,
    this.onTap,
  });

  final String label;
  final String value;
  final bool multiline;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(
              label,
              style: appText(10.5, FontWeight.w500, p.textTertiary),
            ),
          ),
          Glass(
            radius: 15,
            blur: 18,
            shadow: false,
            onTap: onTap,
            padding: const EdgeInsets.fromLTRB(13, 11, 12, 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    value,
                    maxLines: multiline ? 6 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: appText(
                      13.5,
                      FontWeight.w400,
                      p.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TagBadge extends StatelessWidget {
  const TagBadge(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final tint = color ?? p.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: appText(8.5, FontWeight.w600, tint),
      ),
    );
  }
}

class StepperRow extends StatelessWidget {
  const StepperRow({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.onMinus,
    this.onPlus,
  });

  final String title;
  final String value;
  final String? subtitle;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 9, 12, 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: appText(13.5, FontWeight.w500, p.textPrimary),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: appText(10, FontWeight.w400, p.textTertiary),
                  ),
                ],
              ],
            ),
          ),
          Glass(
            radius: 12,
            blur: 14,
            shadow: false,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                Pressable(
                  onTap: onMinus,
                  child: SizedBox(
                    width: 30,
                    height: 32,
                    child: Icon(
                      Icons.remove_rounded,
                      size: 14,
                      color: p.textSecondary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 46,
                  child: Text(
                    value,
                    textAlign: TextAlign.center,
                    style: appText(12, FontWeight.w600, p.textPrimary),
                  ),
                ),
                Pressable(
                  onTap: onPlus,
                  child: SizedBox(
                    width: 30,
                    height: 32,
                    child: Icon(
                      Icons.add_rounded,
                      size: 14,
                      color: p.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProgressLine extends StatelessWidget {
  const ProgressLine({
    super.key,
    required this.value,
    this.color,
    this.height = 6,
  });

  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final tint = color ?? p.amber;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          Container(
            height: height,
            color: p.textTertiary.withValues(alpha: .18),
          ),
          FractionallySizedBox(
            widthFactor: value.clamp(0, 1),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [tint.withValues(alpha: .65), tint],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
