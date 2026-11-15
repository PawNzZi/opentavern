/// 对话列表。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/store/tavern_store.dart';
import '../nav.dart';
import '../theme.dart';
import 'chat_page.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  List<Map<String, dynamic>> _chats = TavernStore.instance.chats;

  void _refresh() => setState(() => _chats = TavernStore.instance.chats);

  Future<void> _open(Map<String, dynamic> chat) async {
    await pushPage<void>(context, ChatPage(chatId: '${chat['id']}'));
    _refresh();
  }

  Future<void> _delete(Map<String, dynamic> chat) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('删除对话？', style: TavernText.title),
        content: Text(
          '「${chat['title'] ?? ''}」的全部消息会被删除。',
          style: TavernText.secondary,
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除', style: TextStyle(color: TavernColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await TavernStore.instance.deleteChat('${chat['id']}');
    if (!mounted) return;
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('对话', style: TavernText.largeTitle),
          ),
          Expanded(
            child: _chats.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.chat_bubble_outline, size: 40, color: TavernColors.textFaint),
                        const SizedBox(height: 12),
                        const Text('还没有对话', style: TavernText.title),
                        const SizedBox(height: 6),
                        const Text('去「角色」页选一个角色开始第一段故事。', style: TavernText.caption),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    itemCount: _chats.length,
                    separatorBuilder: (BuildContext _, int _) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final Map<String, dynamic> chat = _chats[index];
                      return GestureDetector(
                        onTap: () => unawaited(_open(chat)),
                        onLongPress: () => unawaited(_delete(chat)),
                        child: CardBox(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: <Widget>[
                              _avatar(chat),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: Text(
                                            '${chat['title'] ?? ''}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TavernText.title,
                                          ),
                                        ),
                                        Text(_time(chat['updatedAt']), style: TavernText.tiny),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _lastText(chat),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TavernText.caption,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(Map<String, dynamic> chat) {
    final Map<String, dynamic>? character =
        TavernStore.instance.character('${chat['characterId']}');
    final String path = '${character?['avatar'] ?? ''}';
    if (path.isNotEmpty && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(File(path), width: 44, height: 44, fit: BoxFit.cover),
      );
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: TavernColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        '${character?['name'] ?? '?'}'.substring(0, 1),
        style: const TextStyle(color: TavernColors.accent, fontSize: 16),
      ),
    );
  }

  String _lastText(Map<String, dynamic> chat) {
    final List<dynamic> messages = chat['messages'] is List ? chat['messages'] as List : <dynamic>[];
    for (int i = messages.length - 1; i >= 0; i--) {
      final Object? item = messages[i];
      if (item is Map) {
        final String text = '${item['text'] ?? ''}'.replaceAll('\n', ' ').trim();
        if (text.isNotEmpty) return text;
      }
    }
    return '暂无消息';
  }

  String _time(Object? raw) {
    final int at = raw is num ? raw.toInt() : 0;
    if (at == 0) return '';
    final DateTime time = DateTime.fromMillisecondsSinceEpoch(at);
    final DateTime now = DateTime.now();
    if (time.year == now.year && time.month == now.month && time.day == now.day) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    return '${time.month}/${time.day}';
  }
}
