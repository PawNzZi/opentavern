import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/design/theme.dart';
import 'package:tavern_app/screens/provider_picker.dart';

void main() {
  // 模拟 showTavernSheet 的 SingleChildScrollView 包裹：这里若用 ListView
  // 会因无界高度塌成空白（线上出现过的 bug），必须能正常渲染出所有选项。
  Widget wrap(Widget child) => MaterialApp(
        theme: buildTavernTheme(dark: true),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  testWidgets('provider picker lists follow-global plus every provider',
      (tester) async {
    await tester.pumpWidget(wrap(
      ProviderPickerBody(
        providers: kProviderOrder,
        configured: (_) => true,
        current: '',
        globalProvider: 'openai',
        onSelect: (_) {},
      ),
    ));
    expect(find.text('跟随全局'), findsOneWidget);
    expect(find.text('当前全局：OpenAI'), findsOneWidget);
    for (final id in kProviderOrder) {
      expect(find.text(kProviderLabels[id]!), findsOneWidget);
    }
    expect(find.text('未配置密钥'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('provider picker marks current selection and unconfigured',
      (tester) async {
    await tester.pumpWidget(wrap(
      ProviderPickerBody(
        providers: kProviderOrder,
        configured: (id) => id != 'custom',
        current: 'deepseek',
        globalProvider: 'openai',
        onSelect: (_) {},
      ),
    ));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('未配置密钥'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('provider picker taps emit the provider id', (tester) async {
    String? picked;
    await tester.pumpWidget(wrap(
      ProviderPickerBody(
        providers: kProviderOrder,
        configured: (_) => true,
        current: '',
        globalProvider: 'openai',
        onSelect: (id) => picked = id,
      ),
    ));
    await tester.tap(find.text('DeepSeek'));
    expect(picked, 'deepseek');
    await tester.tap(find.text('跟随全局'));
    expect(picked, '');
  });
}
