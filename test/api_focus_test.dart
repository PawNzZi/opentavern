import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/screens/connection.dart';

void main() {
  testWidgets('API key field keeps focus', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ConnectionPage()));
    await tester.pumpAndSettle();
    final keyField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.obscureText,
    );
    expect(keyField, findsOneWidget);
    await tester.tap(keyField);
    await tester.pump();
    await tester.enterText(keyField, 'sk-test');
    await tester.pump(const Duration(milliseconds: 50));
    final field = tester.widget<TextField>(keyField);
    expect(field.controller?.text, 'sk-test');
    expect(field.focusNode?.hasFocus ?? true, isTrue);
  });
}
