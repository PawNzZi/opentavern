import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/store.dart';
import '../data/demo.dart';
import '../design/glass.dart';
import '../design/routes.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';
import 'character.dart';
import 'chat.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.sessionId});

  final String? sessionId;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DemoCharacter? _characterFor(String name) {
    for (final c in AppStore.instance.characters) {
      if (c.name == name) return c;
    }
    return null;
  }

  void _openCharacter(DemoCharacter character) {
    openGlassPage(context, CharacterScreen(character: character));
  }

  void _openSession(ChatSession session) {
    final character = _characterFor(session.characterName);
    if (character == null) return;
    openGlassPage(
      context,
      ChatScreen(character: character, sessionId: session.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final q = _query.trim().toLowerCase();
    final scopedSessions = widget.sessionId == null
        ? AppStore.instance.sessions
        : AppStore.instance.sessions
            .where((s) => s.id == widget.sessionId)
            .toList();
    final characters = widget.sessionId == null
        ? AppStore.instance.characters.where((c) {
      if (q.isEmpty) return false;
      return c.name.toLowerCase().contains(q) ||
          c.title.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q) ||
          c.tags.any((t) => t.toLowerCase().contains(q));
    }).toList()
        : <DemoCharacter>[];

    final sessions = scopedSessions.where((s) {
      if (q.isEmpty) return false;
      if (s.title.toLowerCase().contains(q)) return true;
      if (s.characterName.toLowerCase().contains(q)) return true;
      return s.messages.any((m) => m.text.toLowerCase().contains(q));
    }).toList();

    final hits = <(ChatSession, ChatMessage)>[];
    if (q.isNotEmpty) {
      for (final session in scopedSessions) {
        for (final message in session.messages) {
          if (message.text.toLowerCase().contains(q)) {
            hits.add((session, message));
            if (hits.length >= 12) break;
          }
        }
        if (hits.length >= 12) break;
      }
    }

    return DetailPage(
      eyebrow: 'SEARCH',
      title: '搜索',
      subtitle: '角色、对话与消息，一次找全。',
      children: [
        const SizedBox(height: 16),
        SearchField(
          controller: _controller,
          autofocus: true,
          hint: '搜索角色、对话或消息',
          onChanged: (v) => setState(() => _query = v),
          trailing: Icon(
            Icons.mic_none_rounded,
            size: 17,
            color: p.textTertiary,
          ),
        ),
        const SizedBox(height: 12),
        if (q.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                '输入关键词开始搜索本地数据',
                style: appText(13, FontWeight.w400, p.textTertiary),
              ),
            ),
          )
        else if (characters.isEmpty && sessions.isEmpty && hits.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 50),
            child: Center(
              child: Text(
                '没有找到“$_query”',
                style: appText(13.5, FontWeight.w400, p.textTertiary),
              ),
            ),
          )
        else ...[
          if (characters.isNotEmpty) ...[
            const SectionLabel('角色'),
            Glass(
              radius: 22,
              blur: 22,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < characters.length; i++) ...[
                    _CharacterResult(
                      character: characters[i],
                      onTap: () => _openCharacter(characters[i]),
                    ),
                    if (i != characters.length - 1)
                      const Hairline(indent: 66),
                  ],
                ],
              ),
            ),
          ],
          if (sessions.isNotEmpty) ...[
            const SectionLabel('对话'),
            Glass(
              radius: 22,
              blur: 22,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < sessions.length; i++) ...[
                    SettingRow(
                      icon: Icons.forum_outlined,
                      title: sessions[i].title,
                      subtitle:
                          '${sessions[i].characterName} · ${sessions[i].messages.length} 条消息',
                      iconColor: p.amber,
                      onTap: () => _openSession(sessions[i]),
                    ),
                    if (i != sessions.length - 1)
                      const Hairline(indent: 56),
                  ],
                ],
              ),
            ),
          ],
          if (hits.isNotEmpty) ...[
            const SectionLabel('消息'),
            Glass(
              radius: 22,
              blur: 22,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < hits.length; i++) ...[
                    _MessageHit(
                      session: hits[i].$1,
                      message: hits[i].$2,
                      query: _query,
                      onTap: () => _openSession(hits[i].$1),
                    ),
                    if (i != hits.length - 1) const Hairline(indent: 56),
                  ],
                ],
              ),
            ),
          ],
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              '最近搜索',
              style: appText(
                11,
                FontWeight.w600,
                p.textTertiary,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            Text('清除', style: appText(10.5, FontWeight.w400, p.amber)),
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
            GlassPill(label: '沉砚', height: 30),
          ],
        ),
      ],
    );
  }
}

class _CharacterResult extends StatelessWidget {
  const _CharacterResult({required this.character, required this.onTap});

  final DemoCharacter character;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Pressable(
      onTap: onTap,
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
                avatarBase64: character.avatarBase64,
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

class _MessageHit extends StatelessWidget {
  const _MessageHit({
    required this.session,
    required this.message,
    required this.query,
    required this.onTap,
  });

  final ChatSession session;
  final ChatMessage message;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final text = message.text.replaceAll('\n', ' ');
    final index = text.toLowerCase().indexOf(query.toLowerCase());
    final start = index < 0 ? 0 : (index - 18).clamp(0, text.length);
    final end = index < 0
        ? text.length.clamp(0, 90)
        : (index + query.length + 40).clamp(0, text.length);
    final snippet =
        '${start > 0 ? '…' : ''}${text.substring(start, end)}${end < text.length ? '…' : ''}';
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  session.characterName,
                  style: appText(12, FontWeight.w600, p.textPrimary),
                ),
                const SizedBox(width: 8),
                Text(
                  session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appText(9.5, FontWeight.w400, p.textTertiary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                children: _highlightSpans(
                  snippet,
                  query,
                  appText(11.5, FontWeight.w400, p.textSecondary, height: 1.4),
                  p.amber,
                ),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

List<TextSpan> _highlightSpans(
  String text,
  String query,
  TextStyle style,
  Color highlight,
) {
  final q = query.toLowerCase();
  if (q.isEmpty) return [TextSpan(text: text, style: style)];
  final lower = text.toLowerCase();
  final spans = <TextSpan>[];
  var start = 0;
  while (true) {
    final index = lower.indexOf(q, start);
    if (index < 0) {
      if (start < text.length) {
        spans.add(TextSpan(text: text.substring(start), style: style));
      }
      break;
    }
    if (index > start) {
      spans.add(TextSpan(text: text.substring(start, index), style: style));
    }
    spans.add(
      TextSpan(
        text: text.substring(index, index + q.length),
        style: style.copyWith(
          color: highlight,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    start = index + q.length;
  }
  return spans;
}
