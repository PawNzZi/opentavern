import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tavern/core/card/card_io.dart';
import 'package:open_tavern/core/card/png_card_codec.dart';
import 'package:open_tavern/core/models/tavern_card.dart';

Map<String, dynamic> _v2Card() {
  return <String, dynamic>{
    'spec': 'chara_card_v2',
    'spec_version': '2.0',
    'data': <String, dynamic>{
      'name': '测试角色',
      'description': '一个用于测试的角色',
      'personality': '冷静',
      'scenario': '夜晚的书房',
      'first_mes': '你来了。',
      'mes_example': '<START>',
      'tags': <String>['测试', '中文'],
      'creator': 'unit-test',
      'alternate_greetings': <String>['又见面了。'],
      'character_book': <String, dynamic>{
        'name': '测试世界书',
        'entries': <Map<String, dynamic>>[
          <String, dynamic>{
            'keys': <String>['书房'],
            'content': '书房里有一盏旧台灯。',
            'comment': '场景',
          },
          <String, dynamic>{
            'keys': <String>['开场'],
            'content': '另一段开场白。',
            'comment': '开场白',
          },
        ],
      },
    },
  };
}

void main() {
  test('V2 卡归一化：字段与内嵌世界书', () {
    final TavernCard card = CardIo.normalize(_v2Card());
    expect(card.name, '测试角色');
    expect(card.firstMes, '你来了。');
    expect(card.tags, <String>['测试', '中文']);
    expect(card.book, isNotNull);
    expect(card.book!.entries.length, 2);
    // 世界书里命中「开场白」的条目会并进 alternateGreetings
    expect(card.alternateGreetings.contains('另一段开场白。'), isTrue);
  });

  test('V1 卡（无 data 包装）也能解析', () {
    final TavernCard card = CardIo.normalize(<String, dynamic>{
      'name': 'V1 角色',
      'description': '老格式',
      'first_mes': '你好',
    });
    expect(card.name, 'V1 角色');
    expect(card.firstMes, '你好');
  });

  test('缺少 name 时报错', () {
    expect(
      () => CardIo.normalize(<String, dynamic>{'description': 'x'}),
      throwsA(isA<CardException>()),
    );
  });

  test('JSON 导出是 V2 结构', () {
    final TavernCard card = CardIo.normalize(_v2Card());
    final Map<String, dynamic> json = jsonDecode(CardIo.exportJson(card)) as Map<String, dynamic>;
    expect(json['spec'], 'chara_card_v2');
    expect((json['data'] as Map)['name'], '测试角色');
    expect((json['data'] as Map)['first_mes'], '你来了。');
  });

  test('PNG 写入后再读回', () {
    final TavernCard card = CardIo.normalize(_v2Card());
    final Uint8List png = CardIo.exportPng(card);
    expect(PngCardCodec.looksLikePng(png), isTrue);

    final Map<String, dynamic>? raw = PngCardCodec.readCardJson(png);
    expect(raw, isNotNull);
    expect((raw!['data'] as Map)['name'], '测试角色');

    final CardImportResult parsed = CardIo.parse(png, fileName: 'card.png');
    expect(parsed.source, 'png');
    expect(parsed.card.name, '测试角色');
    expect(parsed.image, isNotNull);
  });

  test('不是 PNG 卡时报「没有元数据」', () {
    final Uint8List png = PngCardCodec.fallbackPng;
    expect(
      () => CardIo.parse(png, fileName: 'empty.png'),
      throwsA(isA<CardException>()),
    );
  });
}
