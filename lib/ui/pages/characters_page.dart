/// 角色列表（阶段 0：空态占位）。
library;

import 'package:flutter/material.dart';

import '../theme.dart';

class CharactersPage extends StatelessWidget {
  const CharactersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('角色', style: TavernText.largeTitle),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const <Widget>[
                    Icon(Icons.person_outline, size: 40, color: TavernColors.textFaint),
                    SizedBox(height: 12),
                    Text('还没有角色卡', style: TavernText.title),
                    SizedBox(height: 6),
                    Text('导入 PNG / JSON / charx 角色卡即可开始。', style: TavernText.caption),
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
