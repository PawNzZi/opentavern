/// PNG 角色卡的读写：角色数据存在 PNG 的 `tEXt` 块里（关键字 `chara` / `ccv3`）。
library;

import 'dart:convert';
import 'dart:typed_data';

class PngCardCodec {
  PngCardCodec._();

  static const List<int> signature = <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];

  /// 1x1 透明 PNG：导出时没有头像就用它兜底。
  static final Uint8List fallbackPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  static bool looksLikePng(Uint8List bytes) {
    if (bytes.length < 8) return false;
    for (int i = 0; i < 8; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }

  /// 读出 PNG 里的角色卡 JSON；没有元数据返回 null。
  static Map<String, dynamic>? readCardJson(Uint8List bytes) {
    if (!looksLikePng(bytes)) return null;
    final ByteData data = ByteData.sublistView(bytes);
    int offset = 8;
    String? v3;
    String? v2;
    while (offset + 12 <= bytes.length) {
      final int length = data.getUint32(offset);
      final String type = latin1.decode(bytes.sublist(offset + 4, offset + 8));
      final int start = offset + 8;
      final int end = start + length;
      if (end > bytes.length) break;
      if (type == 'tEXt') {
        final Uint8List chunk = bytes.sublist(start, end);
        final int zero = chunk.indexOf(0);
        if (zero > 0) {
          final String keyword = latin1.decode(chunk.sublist(0, zero)).toLowerCase();
          final String value = latin1.decode(chunk.sublist(zero + 1));
          if (keyword == 'ccv3') {
            v3 = value;
          } else if (keyword == 'chara') {
            v2 = value;
          }
        }
      }
      offset = end + 4;
      if (type == 'IEND') break;
    }
    final String? encoded = v3 ?? v2;
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final Object? parsed = jsonDecode(utf8.decode(base64Decode(encoded)));
      return parsed is Map ? Map<String, dynamic>.from(parsed) : null;
    } catch (_) {
      return null;
    }
  }

  /// 把角色 JSON 写进 PNG 的 `chara` 块（会先删掉旧的 chara / ccv3 块）。
  static Uint8List embedCard(Uint8List png, Map<String, dynamic> cardJson) {
    final Uint8List base = looksLikePng(png) ? png : fallbackPng;
    final ByteData data = ByteData.sublistView(base);
    final String payload = base64Encode(utf8.encode(jsonEncode(cardJson)));
    final Uint8List textChunk = _textChunk('chara', payload);

    final BytesBuilder out = BytesBuilder(copy: false);
    out.add(signature);
    int offset = 8;
    while (offset + 12 <= base.length) {
      final int length = data.getUint32(offset);
      final String type = latin1.decode(base.sublist(offset + 4, offset + 8));
      final int end = offset + 8 + length + 4;
      bool skip = false;
      if (type == 'tEXt') {
        final Uint8List chunk = base.sublist(offset + 8, offset + 8 + length);
        final int zero = chunk.indexOf(0);
        if (zero > 0) {
          final String keyword = latin1.decode(chunk.sublist(0, zero)).toLowerCase();
          if (keyword == 'chara' || keyword == 'ccv3') skip = true;
        }
      }
      if (type == 'IEND') {
        out.add(textChunk);
      }
      if (!skip) {
        out.add(base.sublist(offset, end));
      }
      offset = end;
      if (type == 'IEND') break;
    }
    return out.toBytes();
  }

  static Uint8List _textChunk(String keyword, String value) {
    final List<int> payload = <int>[
      ...latin1.encode(keyword),
      0,
      ...latin1.encode(value),
    ];
    final Uint8List typeBytes = Uint8List.fromList(latin1.encode('tEXt'));
    final Uint8List body = Uint8List.fromList(<int>[...typeBytes, ...payload]);
    final ByteData length = ByteData(4)..setUint32(0, payload.length);
    final ByteData crc = ByteData(4)..setUint32(0, _crc32(body));
    return Uint8List.fromList(<int>[
      ...length.buffer.asUint8List(),
      ...body,
      ...crc.buffer.asUint8List(),
    ]);
  }

  static int _crc32(List<int> data) {
    int crc = 0xffffffff;
    for (final int byte in data) {
      crc ^= byte;
      for (int bit = 0; bit < 8; bit++) {
        crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
      }
    }
    return (crc ^ 0xffffffff) & 0xffffffff;
  }
}
