import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/store.dart';
import '../data/demo.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/routes.dart';
import '../design/theme.dart';
import 'chat.dart';
import 'search.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.onOpenCharacter,
    required this.onOpenChat,
    required this.onImport,
  });

  final ValueChanged<DemoCharacter> onOpenCharacter;
  final ValueChanged<DemoCharacter> onOpenChat;
  final Future<void> Function() onImport;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _tag = '全部';

  List<String> get _tags {
    final tags = <String>{'全部', '最近', '收藏'};
    for (final character in AppStore.instance.characters) {
      tags.addAll(character.tags.where((t) => t.trim().isNotEmpty));
    }
    return tags.toList();
  }

  @override
  void initState() {
    super.initState();
    AppStore.instance.addListener(_sync);
  }

  void _sync() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppStore.instance.removeListener(_sync);
    super.dispose();
  }

  List<DemoCharacter> get _filtered {
    switch (_tag) {
      case '全部':
      case '最近':
        return AppStore.instance.characters;
      case '收藏':
        return AppStore.instance.characters.where((c) => c.favorite).toList();
      default:
        return AppStore.instance.characters.where((c) => c.tags.contains(_tag)).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final characters = _filtered;
    ChatSession? latestSession;
    for (final session in AppStore.instance.sessions) {
      if (latestSession == null ||
          session.updatedAt > latestSession.updatedAt) {
        latestSession = session;
      }
    }
    DemoCharacter? continueCharacter;
    if (latestSession != null) {
      for (final c in AppStore.instance.characters) {
        if (c.name == latestSession!.characterName) {
          continueCharacter = c;
          break;
        }
      }
    }
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 148),
        physics: const BouncingScrollPhysics(),
        children: [
          PageHeader(
            eyebrow: _todayLabel(),
            title: '酒馆',
            subtitle: '挑一个角色，继续今晚的故事。',
            trailing: GlassCircleButton(
              icon: Icons.add_rounded,
              size: 46,
              onTap: () async {
                await widget.onImport();
                if (mounted) setState(() => _tag = '全部');
              },
            ),
          ),
          const SizedBox(height: 20),
          SearchField(
            hint: '搜索角色或标签',
            onTap: () => openGlassPage(context, const SearchPage()),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _tags.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final tag = _tags[i];
                return GlassPill(
                  label: tag,
                  selected: _tag == tag,
                  onTap: () => setState(() => _tag = tag),
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          if (latestSession != null && continueCharacter != null)
            _ContinueCard(
              character: continueCharacter!,
              session: latestSession,
              onTap: () => openGlassPage(
                context,
                ChatScreen(
                  character: continueCharacter!,
                  sessionId: latestSession!.id,
                ),
              ),
            ),
          SectionLabel(
            '角色',
            trailing: Text(
              '${characters.length} 位 · 管理',
              style: appText(12.5, FontWeight.w500, p.textTertiary),
            ),
          ),
          if (characters.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  AppStore.instance.characters.isEmpty
                      ? '还没有角色，点右上角导入角色卡'
                      : '没有“$_tag”标签的角色',
                  style: appText(13, FontWeight.w400, p.textTertiary),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: characters.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: .72,
              ),
              itemBuilder: (context, i) {
                final c = characters[i];
                return _CharacterTile(
                  character: c,
                  onTap: () => c.alternateGreetings.isNotEmpty
                      ? widget.onOpenCharacter(c)
                      : widget.onOpenChat(c),
                  onOpenDetails: () => widget.onOpenCharacter(c),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.character,
    required this.session,
    required this.onTap,
  });

  final DemoCharacter character;
  final ChatSession session;
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
              avatarBase64: character.avatarBase64,
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
                      _sessionTime(session.updatedAt),
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
                  session.snippet.isEmpty ? '继续这段对话' : session.snippet,
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
  const _CharacterTile({
    required this.character,
    required this.onTap,
    required this.onOpenDetails,
  });

  final DemoCharacter character;
  final VoidCallback onTap;
  final VoidCallback onOpenDetails;

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
            avatarBase64: character.avatarBase64,
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
                character.tags.isEmpty ? '角色' : character.tags.first,
                style: appText(9.5, FontWeight.w600, p.textPrimary),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                GlassCircleButton(
                  icon: Icons.info_outline_rounded,
                  size: 31,
                  iconSize: 15,
                  onTap: onOpenDetails,
                ),
                const SizedBox(width: 6),
                GlassCircleButton(
                  icon: character.favorite
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 31,
                  iconSize: 15,
                  iconColor: character.favorite ? p.amber : p.textPrimary,
                  tint: character.favorite ? p.amber : null,
                  onTap: () async {
                    await AppStore.instance.addCharacter(
                      character.copyWith(favorite: !character.favorite),
                    );
                  },
                ),
              ],
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

String _todayLabel() {
  const weekdays = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY',
  ];
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  final now = DateTime.now();
  return '${weekdays[now.weekday - 1]} · ${now.day} ${months[now.month - 1]}';
}

String _sessionTime(int millis) {
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  final now = DateTime.now();
  if (d.year == now.year && d.month == now.month && d.day == now.day) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
  return '${d.month}/${d.day}';
}
