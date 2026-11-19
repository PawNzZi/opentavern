import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Best-effort PDF text extraction.
///
/// Handles FlateDecode content streams and plain `Tj` / `TJ` operators. It is
/// intentionally dependency-free and does not attempt to render PDFs.
String? extractPdfText(Uint8List bytes) {
  try {
    final raw = latin1.decode(bytes, allowInvalid: true);
    final buffer = StringBuffer();
    var search = 0;
    while (true) {
      final start = raw.indexOf('stream', search);
      if (start < 0) break;
      var dataStart = start + 6;
      if (dataStart < raw.length && raw[dataStart] == '\r') dataStart++;
      if (dataStart < raw.length && raw[dataStart] == '\n') dataStart++;
      final end = raw.indexOf('endstream', dataStart);
      if (end < 0) break;
      final chunk = bytes.sublist(
        dataStart,
        end.clamp(0, bytes.length),
      );
      String content;
      try {
        final inflated = ZLibDecoder().decodeBytes(chunk);
        content = latin1.decode(inflated, allowInvalid: true);
      } catch (_) {
        content = latin1.decode(chunk, allowInvalid: true);
      }
      buffer.write(_contentText(content));
      buffer.write('\n');
      search = end + 9;
    }
    final text = buffer.toString().trim();
    return text.isEmpty ? null : text;
  } catch (_) {
    return null;
  }
}

String _contentText(String content) {
  final out = StringBuffer();
  final matches = RegExp(r'\((?:\\.|[^\\)])*\)\s*Tj').allMatches(content);
  for (final match in matches) {
    final token = match.group(0)!;
    final end = token.lastIndexOf(')');
    if (end > 0) {
      out.writeln(_unescape(token.substring(1, end)));
    }
  }
  final arrays = RegExp(r'\[(.*?)\]\s*TJ', dotAll: true).allMatches(content);
  for (final match in arrays) {
    final body = match.group(1) ?? '';
    final pieces = RegExp(r'\((?:\\.|[^\\)])*\)').allMatches(body);
    final line = StringBuffer();
    for (final piece in pieces) {
      final text = piece.group(0)!;
      line.write(_unescape(text.substring(1, text.length - 1)));
    }
    if (line.isNotEmpty) out.writeln(line);
  }
  return out.toString();
}

String _unescape(String value) {
  final buffer = StringBuffer();
  for (var i = 0; i < value.length; i++) {
    final ch = value[i];
    if (ch != r'\' || i + 1 >= value.length) {
      buffer.write(ch);
      continue;
    }
    i++;
    final next = value[i];
    switch (next) {
      case 'n':
        buffer.write('\n');
      case 'r':
        buffer.write('\r');
      case 't':
        buffer.write('\t');
      case '(':
      case ')':
      case r'\':
        buffer.write(next);
      default:
        buffer.write(next);
    }
  }
  return buffer.toString();
}
