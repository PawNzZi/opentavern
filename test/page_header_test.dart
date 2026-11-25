import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/core/store.dart';
import 'package:tavern_app/design/theme.dart';
import 'package:tavern_app/screens/chats.dart';
import 'package:tavern_app/screens/settings.dart';

void main() {
  testWidgets('chats page header stays fixed while the list scrolls',
      (tester) async {
    AppStore.instance.sessions.clear();
    for (var i = 0; i < 12; i++) {
      AppStore.instance.sessions.add(ChatSession(
        id: 's$i',
        characterName: '角色$i',
        title: '对话$i',
      ));
    }
    await tester.pumpWidget(MaterialApp(
      theme: buildTavernTheme(dark: true),
      home: Scaffold(
        body: ChatsScreen(
          onOpenChat: (_) {},
          onSearch: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('对话'), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('对话'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings page header stays fixed while the list scrolls',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTavernTheme(dark: true),
      home: SettingsScreen(onOpenConnect: () {}),
    ));
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
