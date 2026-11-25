import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/design/scaffold.dart';
import 'package:tavern_app/design/theme.dart';

void main() {
  testWidgets('long right-side value ellipsizes without squeezing the title',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTavernTheme(dark: true),
      home: Scaffold(
        body: SettingRow(
          icon: Icons.title_rounded,
          title: '聊天标题',
          value: '这是一个非常非常非常非常非常非常非常非常非常非常长的描述文字用来测试省略号截断',
        ),
      ),
    ));
    // 标题仍在，且没有发生布局溢出。
    expect(find.text('聊天标题'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short value still renders fully', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTavernTheme(dark: true),
      home: Scaffold(
        body: SettingRow(
          icon: Icons.person_outline_rounded,
          title: '当前人格',
          value: '旅人',
        ),
      ),
    ));
    expect(find.text('旅人'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
