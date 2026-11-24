import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/design/theme.dart';
import 'package:tavern_app/screens/status_bar.dart';

void main() {
  final data = {
    '时间': {'日期': '2024年12月6日', '时段': '下午'},
    '郑怡云': {
      '攻略阶段': 12,
      '警惕程度': 30,
      '当前位置': '公司',
      '是否怀孕': false,
      '对user态度': '警惕',
    },
  };

  Widget wrap(Widget child) => MaterialApp(
        theme: buildTavernTheme(dark: true),
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      );

  testWidgets('status bar shows a compact summary and expands to grouped fields',
      (tester) async {
    await tester.pumpWidget(wrap(StatusBarPanel(
      data: data,
      ranges: const {'郑怡云/攻略阶段': 200, '郑怡云/警惕程度': 100},
    )));
    expect(find.text('状态栏'), findsOneWidget);
    // 收起时不显示分组明细。
    expect(find.text('郑怡云'), findsNothing);

    await tester.tap(find.text('状态栏'));
    await tester.pumpAndSettle();
    expect(find.text('郑怡云'), findsOneWidget);
    expect(find.text('时间'), findsOneWidget);
    expect(find.text('攻略阶段'), findsOneWidget);
    expect(find.text('警惕'), findsOneWidget); // 枚举 → 标签
    expect(find.text('否'), findsOneWidget); // 布尔 → 徽章
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty data renders nothing', (tester) async {
    await tester.pumpWidget(wrap(const StatusBarPanel(data: {})));
    expect(find.text('状态栏'), findsNothing);
  });
}
