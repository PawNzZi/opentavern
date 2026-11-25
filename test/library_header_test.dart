import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/store.dart';
import 'package:tavern_app/data/demo.dart';
import 'package:tavern_app/design/theme.dart';
import 'package:tavern_app/screens/library.dart';

void main() {
  testWidgets('character library header stays fixed while the grid scrolls',
      (tester) async {
    AppStore.instance.characters.clear();
    for (var i = 0; i < 12; i++) {
      AppStore.instance.characters.add(DemoCharacter(
        name: '角色$i',
        initial: '角',
        title: '',
        tagline: '简介$i',
        creator: '',
        version: '',
        description: '',
        greeting: '',
        tags: const [],
        lorebook: '',
        preset: '',
        chats: 0,
        tokens: '',
        colors: const [Color(0xFF6B4E3D), Color(0xFFC99A6B)],
      ));
    }
    await tester.pumpWidget(MaterialApp(
      theme: buildTavernTheme(dark: true),
      home: CharacterLibraryPage(
        onOpenCharacter: (_) {},
        onOpenChat: (_) {},
        onImport: () async {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('角色库'), findsOneWidget);

    // 向上滚动网格，顶栏应固定不动。
    await tester.drag(find.byType(GridView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('角色库'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
