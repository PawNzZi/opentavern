import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/docx_text.dart';

void main() {
  test('DOCX text is extracted from document.xml', () {
    const xml =
        '<?xml version="1.0"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body><w:p><w:r><w:t>第一段</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>第二段</w:t></w:r></w:p></w:body></w:document>';
    final bytes = Uint8List.fromList(utf8.encode(xml));
    final archive = Archive()
      ..addFile(ArchiveFile('word/document.xml', bytes.length, bytes));
    final docx = Uint8List.fromList(ZipEncoder().encode(archive)!);
    final text = extractDocxText(docx);
    expect(text, contains('第一段'));
    expect(text, contains('第二段'));
  });
}
