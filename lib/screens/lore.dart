import 'package:flutter/material.dart';

import '../data/demo.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/theme.dart';

class LoreScreen extends StatelessWidget {
  const LoreScreen({super.key, this.standalone = true});

  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return TavernScaffold(
      intensity: 1.05,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 40),
          physics: const BouncingScrollPhysics(),
          children: [
            Row(
              children: [
                GlassCircleButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  size: 40,
                  iconSize: 15,
                  onTap: () => Navigator.maybePop(context),
                ),
                const Spacer(),
                GlassCircleButton(
                  icon: Icons.add_rounded,
                  size: 40,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 18),
            const PageHeader(
              eyebrow: 'LORE',
              title: '世界书',
              subtitle: '关键词触发的设定集，让角色记得整个世界。',
            ),
            const SizedBox(height: 20),
            const SearchField(hint: '搜索世界书或条目'),
            const SizedBox(height: 8),
            const SectionLabel('全部世界书'),
            for (final book in demoLorebooks) ...[
              _LoreCard(book: book),
              const SizedBox(height: 11),
            ],
            const SizedBox(height: 8),
            Glass(
              radius: 20,
              blur: 20,
              shadow: false,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 16,
                    color: p.amber,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '对话时，世界书会扫描最近的消息，命中关键词的条目会自动进入提示词。'
                      '你也可以把条目设为「常驻」，让它始终在场。',
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
            ),
          ],
        ),
      ),
    );
  }
}

class _LoreCard extends StatelessWidget {
  const _LoreCard({required this.book});

  final DemoLorebook book;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Glass(
      radius: 24,
      blur: 24,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      onTap: () {},
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  book.color.withValues(alpha: .85),
                  book.color.withValues(alpha: .38),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: .18),
                width: .8,
              ),
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              size: 21,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        book.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appText(15, FontWeight.w600, p.textPrimary),
                      ),
                    ),
                    if (book.isGlobal) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: p.amber.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '全局',
                          style: appText(8.5, FontWeight.w600, p.amber),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${book.entries} 条 · ${book.linked ?? "未绑定"} · ${book.updated}',
                  style: appText(11, FontWeight.w400, p.textTertiary),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: p.textTertiary,
          ),
        ],
      ),
    );
  }
}
