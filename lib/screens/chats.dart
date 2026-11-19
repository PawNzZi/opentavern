import 'package:flutter/material.dart';

import '../data/demo.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/routes.dart';
import '../design/theme.dart';
import 'search.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({
    super.key,
    required this.onOpenChat,
    required this.onSearch,
  });

  final ValueChanged<DemoCharacter> onOpenChat;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final pinned = demoChats.where((c) => c.pinned).toList();
    final recent = demoChats.where((c) => !c.pinned).toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 148),
        physics: const BouncingScrollPhysics(),
        children: [
          PageHeader(
            eyebrow: 'YOUR STORIES',
            title: '对话',
            subtitle: '6 段故事，等你回来。',
            trailing: GlassCircleButton(
              icon: Icons.search_rounded,
              size: 46,
              onTap: onSearch,
            ),
          ),
          const SizedBox(height: 20),
          SearchField(
            hint: '搜索对话或角色',
            onTap: () => openGlassPage(context, const SearchPage()),
          ),
          const SizedBox(height: 6),
          if (pinned.isNotEmpty) ...[
            const SectionLabel('置顶'),
            Glass(
              radius: 26,
              blur: 26,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _ChatGroup(
                chats: pinned,
                onOpenChat: onOpenChat,
              ),
            ),
          ],
          const SectionLabel('最近'),
          Glass(
            radius: 26,
            blur: 26,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _ChatGroup(chats: recent, onOpenChat: onOpenChat),
          ),
          const SizedBox(height: 18),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.swipe_left_alt_rounded,
                  size: 14,
                  color: p.textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  '左滑对话可置顶或删除',
                  style: appText(11, FontWeight.w400, p.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatGroup extends StatelessWidget {
  const _ChatGroup({required this.chats, required this.onOpenChat});

  final List<DemoChat> chats;
  final ValueChanged<DemoCharacter> onOpenChat;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < chats.length; i++) ...[
          _ChatRow(
            chat: chats[i],
            onTap: () => onOpenChat(chats[i].character),
          ),
          if (i != chats.length - 1) const Hairline(indent: 76),
        ],
      ],
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.chat, required this.onTap});

  final DemoChat chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        child: Row(
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: Portrait(
                initial: chat.character.initial,
                colors: chat.character.colors,
                radius: 16,
                showInitial: true,
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
                          chat.character.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appText(15, FontWeight.w600, p.textPrimary),
                        ),
                      ),
                      if (chat.pinned) ...[
                        const SizedBox(width: 5),
                        Icon(
                          Icons.push_pin_rounded,
                          size: 11,
                          color: p.amber.withValues(alpha: .8),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        chat.time,
                        style: appText(10.5, FontWeight.w400, p.textTertiary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.snippet,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appText(
                            12.5,
                            FontWeight.w400,
                            p.textSecondary,
                          ),
                        ),
                      ),
                      if (chat.unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 17,
                          height: 17,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.amber,
                          ),
                          child: Text(
                            '${chat.unread}',
                            style: appText(
                              9.5,
                              FontWeight.w700,
                              p.onUserBubble,
                            ),
                          ),
                        ),
                      ],
                    ],
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
