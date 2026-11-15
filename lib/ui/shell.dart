/// 应用外壳：四个页签（对话 / 角色 / 世界书 / 设置）。
///
/// iOS 26+ 用系统 `UITabBarController` 的原生玻璃页签条；
/// 更低版本退回自绘胶囊条，保证布局一致。
library;

import 'package:flutter/material.dart';
import 'package:liquid_glass_native/liquid_glass_native.dart';

import 'glass.dart';
import 'pages/characters_page.dart';
import 'pages/chats_page.dart';
import 'pages/settings_page.dart';
import 'pages/worlds_page.dart';
import 'theme.dart';

class TavernShell extends StatefulWidget {
  const TavernShell({super.key});

  @override
  State<TavernShell> createState() => _TavernShellState();
}

class _TavernShellState extends State<TavernShell> {
  int _index = 0;

  static const List<TabItem> _tabs = <TabItem>[
    TabItem(label: '对话', sfSymbol: 'bubble.left.and.bubble.right'),
    TabItem(label: '角色', sfSymbol: 'person.crop.circle'),
    TabItem(label: '世界书', sfSymbol: 'book'),
    TabItem(label: '设置', sfSymbol: 'gearshape'),
  ];

  Widget _page() {
    switch (_index) {
      case 0:
        return const ChatsPage();
      case 1:
        return const CharactersPage();
      case 2:
        return const WorldsPage();
      default:
        return const SettingsPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TavernColors.bg,
      body: Stack(
        children: <Widget>[
          // 内容铺到底部，页签条浮在上面（iOS 的 tab bar 就是这样）
          Positioned.fill(child: _page()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _tabBar(),
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    if (supportsLiquidGlass) {
      return LiquidGlassTabBar(
        items: _tabs,
        currentIndex: _index,
        onTap: (int index) => setState(() => _index = index),
      );
    }
    // iOS < 26：自绘胶囊，保持同一套布局
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: FallbackGlass(
          radius: 28,
          tint: const Color(0xE6FFFFFF),
          child: SizedBox(
            height: 56,
            child: Row(
              children: <Widget>[
                for (int i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _index = i),
                      child: Center(
                        child: Text(
                          _tabs[i].label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                i == _index ? FontWeight.w600 : FontWeight.w400,
                            color: i == _index
                                ? TavernColors.accent
                                : TavernColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
