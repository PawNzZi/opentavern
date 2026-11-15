/// 对话列表（阶段 0：空态占位）。
library;

import 'package:flutter/material.dart';

import '../theme.dart';

class ChatsPage extends StatelessWidget {
  const ChatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('对话', style: TavernText.largeTitle),
            const SizedBox(height: 12),
            const Expanded(child: _EmptyChats()),
          ],
        ),
      ),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const <Widget>[
          Icon(Icons.chat_bubble_outline, size: 40, color: TavernColors.textFaint),
          SizedBox(height: 12),
          Text('还没有对话', style: TavernText.title),
          SizedBox(height: 6),
          Text(
            '去「角色」页选一个角色开始第一段故事。',
            style: TavernText.caption,
          ),
        ],
      ),
    );
  }
}
