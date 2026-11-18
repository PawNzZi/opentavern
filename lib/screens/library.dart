import 'package:flutter/material.dart';

import '../data/demo.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/theme.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({
    super.key,
    required this.onOpenCharacter,
    required this.onOpenChat,
    required this.onImport,
  });

  final ValueChanged<DemoCharacter> onOpenCharacter;
  final ValueChanged<DemoCharacter> onOpenChat;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 148),
        physics: const BouncingScrollPhysics(),
        children: [
          PageHeader(
            eyebrow: 'WEDNESDAY · 18 NOV',
            title: '酒馆',
            subtitle: '挑一个角色，继续今晚的故事。',
            trailing: GlassCircleButton(
              icon: Icons.add_rounded,
              size: 46,
              onTap: onImport,
            ),
          ),
          const SizedBox(height: 20),
          const SearchField(hint: '搜索角色或标签'),
          const SizedBox(height: 14),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: const [
                GlassPill(label: '全部', selected: true),
                SizedBox(width: 8),
                GlassPill(label: '最近'),
                SizedBox(width: 8),
                GlassPill(label: '收藏'),
                SizedBox(width: 8),
                GlassPill(label: '奇幻'),
                SizedBox(width: 8),
                GlassPill(label: '科幻'),
                SizedBox(width: 8),
                GlassPill(label: '治愈'),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _ContinueCard(
            character: demoCharacters.first,
            onTap: () => onOpenChat(demoCharacters.first),
          ),
          SectionLabel(
            '角色',
            trailing: Text(
              '6 位 · 管理',
              style: appText(12.5, FontWeight.w500, p.textTertiary),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: demoCharacters.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: .72,
            ),
            itemBuilder: (context, i) {
              final c = demoCharacters[i];
              return _CharacterTile(
                character: c,
                onTap: () => onOpenCharacter(c),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.character, required this.onTap});

  final DemoCharacter character;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Glass(
      radius: 26,
      blur: 26,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: Portrait(
              initial: character.initial,
              colors: character.colors,
              radius: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: p.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '继续上次',
                      style: appText(
                        10.5,
                        FontWeight.w600,
                        p.amber,
                        letterSpacing: .8,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '21:40',
                      style: appText(10.5, FontWeight.w400, p.textTertiary),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  character.name,
                  style: appText(16, FontWeight.w600, p.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '“有些坏消息，只配在雨天说。”',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appText(12, FontWeight.w400, p.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.amber.withValues(alpha: .18),
              border: Border.all(
                color: p.amber.withValues(alpha: .30),
                width: .8,
              ),
            ),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 17,
              color: p.amber,
            ),
          ),
        ],
      ),
    );
  }
}

class _CharacterTile extends StatelessWidget {
  const _CharacterTile({required this.character, required this.onTap});

  final DemoCharacter character;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Pressable(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Portrait(
            initial: character.initial,
            colors: character.colors,
            radius: 26,
          ),
          Positioned(
            top: 10,
            left: 10,
            child: Glass(
              radius: 11,
              blur: 14,
              shadow: false,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                character.tags.first,
                style: appText(9.5, FontWeight.w600, p.textPrimary),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GlassCircleButton(
              icon: character.favorite
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              size: 31,
              iconSize: 15,
              iconColor: character.favorite ? p.amber : p.textPrimary,
              tint: character.favorite ? p.amber : null,
              onTap: () {},
            ),
          ),
          Positioned(
            left: 14,
            right: 12,
            bottom: 13,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        character.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appText(
                          18,
                          FontWeight.w600,
                          Colors.white,
                          letterSpacing: -.3,
                        ),
                      ),
                    ),
                    if (character.unread > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: p.amber,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  character.tagline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: appText(
                    11,
                    FontWeight.w400,
                    Colors.white.withValues(alpha: .72),
                    height: 1.3,
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
