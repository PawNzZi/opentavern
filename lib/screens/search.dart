import 'package:flutter/material.dart';

import '../data/demo.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DetailPage(
      eyebrow: 'SEARCH',
      title: '搜索',
      subtitle: '角色、对话与消息，一次找全。',
      children: [
        const SizedBox(height: 16),
        const SearchField(
          hint: '搜索“雨”',
          trailing: Icon(Icons.mic_none_rounded, size: 17),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: const [
              GlassPill(label: '全部', selected: true, height: 34),
              SizedBox(width: 7),
              GlassPill(label: '角色', height: 34),
              SizedBox(width: 7),
              GlassPill(label: '对话', height: 34),
              SizedBox(width: 7),
              GlassPill(label: '消息', height: 34),
            ],
          ),
        ),
        const SectionLabel('角色'),
        Glass(
          radius: 22,
          blur: 22,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < 2; i++) ...[
                _CharacterResult(character: demoCharacters[i]),
                if (i != 1) const Hairline(indent: 66),
              ],
            ],
          ),
        ),
        const SectionLabel('对话'),
        Glass(
          radius: 22,
          blur: 22,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < 2; i++) ...[
                _ChatResult(chat: demoChats[i]),
                if (i != 1) const Hairline(indent: 66),
              ],
            ],
          ),
        ),
        const SectionLabel('消息'),
        Glass(
          radius: 22,
          blur: 22,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            children: [
              _MessageResult(
                name: 'Seraphina',
                text: '是啊。王都的雨，总在预言之后来。',
                time: '21:39',
                query: '雨',
              ),
              const SizedBox(height: 12),
              const Hairline(),
              const SizedBox(height: 12),
              _MessageResult(
                name: 'Seraphina',
                text: '有些坏消息，只配在雨天说。',
                time: '21:40',
                query: '雨',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text(
              '最近搜索',
              style: appText(11, FontWeight.w600, p.textTertiary, letterSpacing: 1.2),
            ),
            const Spacer(),
            Text(
              '清除',
              style: appText(10.5, FontWeight.w400, p.amber),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: const [
            GlassPill(label: '王都', height: 30),
            GlassPill(label: '星图', height: 30),
            GlassPill(label: '坏消息', height: 30),
            GlassPill(label: '沈砚', height: 30),
          ],
        ),
      ],
    );
  }
}

class _CharacterResult extends StatelessWidget {
  const _CharacterResult({required this.character});

  final DemoCharacter character;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Pressable(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        child: Row(
          children: [
            SizedBox(
              width: 42,
              height: 42,
              child: Portrait(
                initial: character.initial,
                colors: character.colors,
                radius: 13,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    character.name,
                    style: appText(13.5, FontWeight.w500, p.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    character.tagline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appText(10, FontWeight.w400, p.textTertiary),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 17,
              color: p.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatResult extends StatelessWidget {
  const _ChatResult({required this.chat});

  final DemoChat chat;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: Portrait(
              initial: chat.character.initial,
              colors: chat.character.colors,
              radius: 13,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      chat.character.name,
                      style: appText(
                        13.5,
                        FontWeight.w500,
                        p.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      chat.time,
                      style: appText(9.5, FontWeight.w400, p.textTertiary),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  chat.snippet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appText(10, FontWeight.w400, p.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageResult extends StatelessWidget {
  const _MessageResult({
    required this.name,
    required this.text,
    required this.time,
    required this.query,
  });

  final String name;
  final String text;
  final String time;
  final String query;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final index = text.indexOf(query);
    final base = appText(12, FontWeight.w400, p.textSecondary, height: 1.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              name,
              style: appText(11, FontWeight.w600, p.textPrimary),
            ),
            const SizedBox(width: 7),
            Text(
              time,
              style: appText(9.5, FontWeight.w400, p.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        index == -1
            ? Text(text, style: base)
            : Text.rich(
                TextSpan(
                  style: base,
                  children: [
                    TextSpan(text: text.substring(0, index)),
                    TextSpan(
                      text: query,
                      style: base.copyWith(
                        color: p.onUserBubble,
                        backgroundColor: p.amber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: text.substring(index + query.length)),
                  ],
                ),
              ),
      ],
    );
  }
}
