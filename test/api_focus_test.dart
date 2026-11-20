import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/screens/connection.dart';

void main() {
  testWidgets('API key field keeps focus', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ConnectionPage()));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));
    await tester.tap(fields.at(1));
    await tester.pump();
    await tester.enterText(fields.at(1), 'sk-test');
    await tester.pump();
    final field = tester.widget<TextField>(fields.at(1));
    expect(field.controller?.text, 'sk-test');
  });
}
