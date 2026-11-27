import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/demo.dart';
import 'models.dart';
import 'png_card_export.dart';

/// Builds a PNG character card, embedding V2/V3 metadata.
///
/// When [book] is given, the lorebook is embedded as `data.character_book`
/// inside the same PNG, so one image carries both the card and its world info.
Future<Uint8List> buildCharacterCardPng(
  DemoCharacter character, {
  Lorebook? book,
}) async {
  final png = await _characterImage(character);
  return embedCardInPng(png, character.toCardJson(book: book));
}

Future<Uint8List> _characterImage(DemoCharacter character) async {
  final avatar = character.avatarBase64;
  if (avatar != null && avatar.isNotEmpty) {
    try {
      final codec = await ui.instantiateImageCodec(
        base64Decode(avatar),
        targetWidth: 512,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      if (data != null) return data.buffer.asUint8List();
    } catch (_) {}
  }
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const size = 512.0;
  final colors = character.colors.length >= 2
      ? [character.colors.first, character.colors.last]
      : [const Color(0xFF8C4A3F), const Color(0xFFD98E5F)];
  final paint = ui.Paint()
    ..shader = ui.Gradient.linear(
      Offset.zero,
      const Offset(size, size),
      colors,
    );
  canvas.drawRect(const Rect.fromLTWH(0, 0, size, size), paint);
  canvas.drawCircle(
    const Offset(390, 110),
    100,
    ui.Paint()..color = Colors.white.withValues(alpha: .16),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(512, 512);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}
