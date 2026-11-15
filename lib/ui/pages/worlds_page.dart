/// 世界书列表（阶段 0：空态占位）。
library;

import 'package:flutter/material.dart';

import '../theme.dart';

class WorldsPage extends StatelessWidget {
  const WorldsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('世界书', style: TavernText.largeTitle),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const <Widget>[
                    Icon(Icons.menu_book_outlined, size: 40, color: TavernColors.textFaint),
                    SizedBox(height: 12),
                    Text('还没有世界书', style: TavernText.title),
                    SizedBox(height: 6),
                    Text('角色卡里内嵌的世界书会在导入时自动带过来。', style: TavernText.caption),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
