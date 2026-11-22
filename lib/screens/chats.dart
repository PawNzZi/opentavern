import 'package:flutter/material.dart';

import '../core/store.dart';
import '../data/demo.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/theme.dart';
import '../design/toast.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({
    super.key,
    required this.onOpenChat,
    required this.onSearch,
  });

  final ValueChanged<DemoChat> onOpenChat;
  final VoidCallback onSearch;

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  late List<DemoChat> _chats = _fromStore();
  final _query = TextEditingController();

  List<DemoChat> _fromStore() {
    final result = <DemoChat>[];
    for (final session in AppStore.instance.sessions) {
      final character = AppStore.instance.characters.firstWhere(
        (c) => c.name == session.characterName,
        orElse: () => DemoCharacter(
          name: session.characterName,
          initial: session.characterName.isEmpty ? '?' : session.characterName.characters.first,
          title: '', tagline: '', creator: '', version: '', description: '',
          greeting: '', tags: const [], lorebook: '', preset: '', chats: 0,
          tokens: '', colors: const [Color(0xFF8C4A3F), Color(0xFFD98E5F), Color(0xFF3B1E2A)],
        ),
      );
      result.add(DemoChat(
        character: character,
        snippet: session.snippet,
        time: _timeLabel(session.updatedAt),
        pinned: session.pinned,
        sessionId: session.id,
        title: session.title,
      ));
    }
    return result;
  }

  String _timeLabel(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.month}/${d.day}';
  }

  @override
  void initState() {
    super.initState();
    AppStore.instance.addListener(_sync);
  }

  void _sync() {
    if (!mounted) return;
    setState(() => _chats = _fromStore());
  }

  @override
  void dispose() {
    AppStore.instance.removeListener(_sync);
    _query.dispose();
    super.dispose();
  }

  void _togglePin(DemoChat chat) {
    final session = chat.sessionId != null
        ? AppStore.instance.sessionById(chat.sessionId)!
        : AppStore.instance.sessions.firstWhere(
            (s) => s.characterName == chat.character.name,
          );
    session.pinned = !session.pinned;
    AppStore.instance.saveSessions();
    setState(() => _chats = _fromStore());
    showTavernToast(context, chat.pinned ? '已取消置顶' : '已置顶对话');
  }

  void _delete(DemoChat chat) {
    if (chat.sessionId != null) {
      AppStore.instance.sessions.removeWhere((s) => s.id == chat.sessionId);
    } else {
      AppStore.instance.sessions.removeWhere(
        (s) => s.characterName == chat.character.name,
      );
    }
    AppStore.instance.saveSessions();
    setState(() => _chats = _fromStore());
    showTavernToast(context, '已删除对话');
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final q = _query.text.trim().toLowerCase();
    final visible = _chats.where((c) {
      if (q.isEmpty) return true;
      return c.title.toLowerCase().contains(q) ||
          c.character.name.toLowerCase().contains(q) ||
          c.snippet.toLowerCase().contains(q);
    }).toList();
    final pinned = visible.where((c) => c.pinned).toList();
    final recent = visible.where((c) => !c.pinned).toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 148),
        physics: const BouncingScrollPhysics(),
        children: [
          PageHeader(
            eyebrow: 'YOUR STORIES',
            title: '对话',
            subtitle: '${visible.length} 段故事，等你回来。',
            trailing: GlassCircleButton(
              icon: Icons.search_rounded,
              size: 46,
              onTap: widget.onSearch,
            ),
          ),
          const SizedBox(height: 20),
          SearchField(
            hint: '搜索对话或角色',
            controller: _query,
            onChanged: (_) => setState(() {}),
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
                onOpenChat: widget.onOpenChat,
                onPin: _togglePin,
                onDelete: _delete,
              ),
            ),
          ],
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Text(
                  _chats.isEmpty ? '还没有对话，去角色页开始一段故事' : '没有找到匹配的对话',
                  style: appText(13, FontWeight.w400, p.textTertiary),
                ),
              ),
            )
          else if (recent.isNotEmpty) ...[
            const SectionLabel('最近'),
            Glass(
              radius: 26,
              blur: 26,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _ChatGroup(
                chats: recent,
                onOpenChat: widget.onOpenChat,
                onPin: _togglePin,
                onDelete: _delete,
              ),
            ),
          ],
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
  const _ChatGroup({
    required this.chats,
    required this.onOpenChat,
    required this.onPin,
    required this.onDelete,
  });

  final List<DemoChat> chats;
  final ValueChanged<DemoChat> onOpenChat;
  final ValueChanged<DemoChat> onPin;
  final ValueChanged<DemoChat> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < chats.length; i++) ...[
          _SwipeChatRow(
            key: ValueKey(chats[i].character.name),
            chat: chats[i],
            onTap: () => onOpenChat(chats[i]),
            onPin: () => onPin(chats[i]),
            onDelete: () => onDelete(chats[i]),
          ),
          if (i != chats.length - 1) const Hairline(indent: 76),
        ],
      ],
    );
  }
}

class _SwipeChatRow extends StatefulWidget {
  const _SwipeChatRow({
    super.key,
    required this.chat,
    required this.onTap,
    required this.onPin,
    required this.onDelete,
  });

  final DemoChat chat;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final VoidCallback onDelete;

  @override
  State<_SwipeChatRow> createState() => _SwipeChatRowState();
}

class _SwipeChatRowState extends State<_SwipeChatRow> {
  static const _max = 144.0;
  double _offset = 0;

  void _update(DragUpdateDetails details) {
    setState(() {
      _offset = (_offset - details.delta.dx).clamp(0.0, _max);
    });
  }

  void _end(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final open = _offset > 44 || velocity < -300;
    setState(() => _offset = open ? _max : 0);
  }

  void _run(VoidCallback action) {
    setState(() => _offset = 0);
    action();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: _offset == 0,
              child: Opacity(
                opacity: _offset == 0 ? 0 : 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SwipeAction(
                      icon: widget.chat.pinned
                          ? Icons.push_pin_outlined
                          : Icons.push_pin_rounded,
                      label: widget.chat.pinned ? '取消' : '置顶',
                      color: p.amber,
                      onTap: () => _run(widget.onPin),
                    ),
                    _SwipeAction(
                      icon: Icons.delete_outline_rounded,
                      label: '删除',
                      color: p.danger,
                      onTap: () => _run(widget.onDelete),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(-_offset, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: _update,
              onHorizontalDragEnd: _end,
              child: _ChatRow(
                chat: widget.chat,
                onTap: () {
                  if (_offset > 0) {
                    setState(() => _offset = 0);
                  } else {
                    widget.onTap();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeAction extends StatelessWidget {
  const _SwipeAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 72,
        color: color.withValues(alpha: .18),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: appText(10.5, FontWeight.w600, color),
            ),
          ],
        ),
      ),
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
                avatarBase64: chat.character.avatarBase64,
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
                          chat.title.isEmpty ? chat.character.name : chat.title,
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
