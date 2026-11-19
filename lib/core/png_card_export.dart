import 'dart:convert';
import 'dart:typed_data';

/// Embeds SillyTavern V2/V3 card metadata into a PNG as `tEXt` chunks.
///
/// The function keeps the original image chunks, removes previous card
/// metadata, and writes both `chara` (V2) and `ccv3` (V3 header) chunks.
Uint8List embedCardInPng(Uint8List png, Map<String, dynamic> card) {
  if (!_isPng(png)) {
    throw const FormatException('Not a PNG');
  }
  final v2 = base64Encode(utf8.encode(jsonEncode(card)));
  final v3Json = Map<String, dynamic>.from(card)
    ..['spec'] = 'chara_card_v3'
    ..['spec_version'] = '3.0';
  final v3 = base64Encode(utf8.encode(jsonEncode(v3Json)));

  final out = BytesBuilder(copy: false);
  out.add(png.sublist(0, 8));

  var offset = 8;
  var wrote = false;
  while (offset + 12 <= png.length) {
    final length = _u32(png, offset);
    final typeBytes = png.sublist(offset + 4, offset + 8);
    final type = latin1.decode(typeBytes);
    final end = offset + 12 + length;
    if (end > png.length) break;
    final data = png.sublist(offset + 8, offset + 8 + length);

    if (type == 'IEND' && !wrote) {
      out.add(_textChunk('chara', v2));
      out.add(_textChunk('ccv3', v3));
      wrote = true;
    }
    if (type == 'tEXt' || type == 'iTXt') {
      final zero = data.indexOf(0);
      final key = zero > 0 ? latin1.decode(data.sublist(0, zero)) : '';
      if (key == 'chara' || key == 'ccv3') {
        offset = end;
        continue;
      }
    }
    out.add(png.sublist(offset, end));
    offset = end;
  }
  if (!wrote) {
    out.add(_textChunk('chara', v2));
    out.add(_textChunk('ccv3', v3));
    out.add(_chunk('IEND', Uint8List(0)));
  }
  return out.takeBytes();
}

Uint8List _textChunk(String keyword, String text) {
  final payload = <int>[
    ...latin1.encode(keyword),
    0,
    ...utf8.encode(text),
  ];
  return _chunk('tEXt', Uint8List.fromList(payload));
}

Uint8List _chunk(String type, Uint8List data) {
  final typeBytes = latin1.encode(type);
  final out = BytesBuilder(copy: false);
  out.add(_u32Bytes(data.length));
  out.add(typeBytes);
  out.add(data);
  final crcInput = Uint8List.fromList([...typeBytes, ...data]);
  out.add(_u32Bytes(_crc32(crcInput)));
  return out.takeBytes();
}

bool _isPng(Uint8List b) {
  const sig = [137, 80, 78, 71, 13, 10, 26, 10];
  if (b.length < 8) return false;
  for (var i = 0; i < 8; i++) {
    if (b[i] != sig[i]) return false;
  }
  return true;
}

int _u32(Uint8List b, int o) =>
    (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];

Uint8List _u32Bytes(int value) => Uint8List.fromList([
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ]);

int _crc32(Uint8List data) {
  var crc = 0xFFFFFFFF;
  for (final byte in data) {
    crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});
