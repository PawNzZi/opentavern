import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/pdf_text.dart';

void main() {
  test('extracts Tj text from an uncompressed PDF stream', () {
    const content = 'BT /F1 12 Tf (Hello PDF) Tj ET';
    final pdf =
        '%PDF-1.4\n1 0 obj\n<< /Length ${content.length} >>\nstream\n$content\nendstream\nendobj\n%%EOF';
    final text = extractPdfText(Uint8List.fromList(utf8.encode(pdf)));
    expect(text, contains('Hello PDF'));
  });
}
