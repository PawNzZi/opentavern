import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Extracts plain text from a .docx (OOXML) file using its document.xml.
String? extractDocxText(Uint8List bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? document;
    for (final file in archive.files) {
      if (file.name == 'word/document.xml') {
        document = file;
        break;
      }
    }
    if (document == null) return null;
    final xmlText = utf8.decode(document.content as List<int>, allowMalformed: true);
    final doc = XmlDocument.parse(xmlText);
    final buffer = StringBuffer();
    for (final paragraph in doc.descendants.whereType<XmlElement>()) {
      if (paragraph.localName != 'p') continue;
      final text = paragraph.descendants
          .whereType<XmlElement>()
          .where((e) => e.localName == 't')
          .map((e) => e.innerText)
          .join();
      if (text.trim().isEmpty) continue;
      buffer.writeln(text);
    }
    final result = buffer.toString().trim();
    return result.isEmpty ? null : result;
  } catch (_) {
    return null;
  }
}
