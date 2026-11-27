import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:enough_convert/gbk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/novel/novel_types.dart';
import 'package:tavern_app/core/novel/text_stream.dart';

/// 造 UTF-16 字节（可选 BOM）。
Uint8List utf16Bytes(String text, {bool bigEndian = false, bool bom = true}) {
  final out = BytesBuilder();
  if (bom) out.add(bigEndian ? [0xFE, 0xFF] : [0xFF, 0xFE]);
  for (final u in text.codeUnits) {
    out.add(bigEndian ? [(u >> 8) & 0xFF, u & 0xFF] : [u & 0xFF, (u >> 8) & 0xFF]);
  }
  return out.takeBytes();
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('novel_stream_test_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<String> write(String name, List<int> bytes) async {
    final f = File('${tmp.path}${Platform.pathSeparator}$name');
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }

  group('detectEncoding', () {
    test('无 BOM 的 UTF-8 中文', () async {
      final p = await write('a.txt', utf8.encode('第一章 风起\n李明看着远方。\n'));
      expect(await NovelTextStream.detectEncoding(p), NovelEncoding.utf8);
    });

    test('GBK 中文', () async {
      final p = await write(
        'gbk.txt',
        const GbkCodec().encode('第一章 风起\n李明看着远处的青山。\n第二章 云涌\n王芳低声说道：「走吧。」\n'),
      );
      expect(await NovelTextStream.detectEncoding(p), NovelEncoding.gb18030);
    });

    test('BOM 优先：UTF-8 / UTF-16 LE / UTF-16 BE', () async {
      final u8 = await write('bom8.txt', [0xEF, 0xBB, 0xBF, ...utf8.encode('你好')]);
      expect(await NovelTextStream.detectEncoding(u8), NovelEncoding.utf8);
      final le = await write('bom16le.txt', utf16Bytes('第一章\n你好'));
      expect(await NovelTextStream.detectEncoding(le), NovelEncoding.utf16le);
      final be = await write('bom16be.txt', utf16Bytes('第一章\n你好', bigEndian: true));
      expect(await NovelTextStream.detectEncoding(be), NovelEncoding.utf16be);
    });

    test('非 UTF-8 且中文占比不合理 → Latin-1', () async {
      final p = await write('latin.txt', latin1.encode('Café résumé naïve coûté'));
      expect(await NovelTextStream.detectEncoding(p), NovelEncoding.latin1);
    });

    test('纯 ASCII → UTF-8', () async {
      final p = await write('ascii.txt', utf8.encode('Hello world\nChapter 1\n'));
      expect(await NovelTextStream.detectEncoding(p), NovelEncoding.utf8);
    });
  });

  group('buildIndex + readChapter', () {
    const parts = [
      '序章\n一切开始之前。\n',
      '第一章 风起\n李明看着远方。\n',
      '第二章 云涌\n王芳低声说道：「走吧。」\n',
      '第三章 落幕\n众人沉默。\n',
      'Chapter 4 The End\nFinal line.\n',
      '1. 新的开始\n短内容。\n',
    ];

    test('UTF-8：章节数、标题、按偏移读回与原文一致', () async {
      final bytes = utf8.encode(parts.join());
      final p = await write('novel.txt', bytes);
      final index = await NovelTextStream.buildIndex(p);
      expect(index.encoding, NovelEncoding.utf8);
      expect(index.fileSize, bytes.length);
      expect(index.fileName, 'novel.txt');
      expect(index.modifiedMs, greaterThan(0));
      expect(index.chapters.length, parts.length);
      expect(index.totalChars, greaterThan(0));
      for (var i = 0; i < parts.length; i++) {
        final ch = index.chapters[i];
        expect(ch.index, i);
        expect(ch.title, parts[i].split('\n').first);
        expect(ch.byteLength, greaterThan(0));
        expect(ch.charCount, greaterThan(0));
        expect(await NovelTextStream.readChapter(p, index, ch), parts[i]);
      }
      // 偏移铺满全文件。
      expect(index.chapters.first.byteOffset, 0);
      final last = index.chapters.last;
      expect(last.byteOffset + last.byteLength, bytes.length);
    });

    test('第一个标题前的非空内容并入「开篇」', () async {
      final p = await write('pre.txt', utf8.encode('这是简介。\n\n第一章 正文\n内容。\n'));
      final index = await NovelTextStream.buildIndex(p);
      expect(index.chapters.length, 2);
      expect(index.chapters[0].title, '开篇');
      expect(await NovelTextStream.readChapter(p, index, index.chapters[0]),
          '这是简介。\n\n');
      expect(await NovelTextStream.readChapter(p, index, index.chapters[1]),
          '第一章 正文\n内容。\n');
    });

    test('GBK：小 chunk 跨边界多字节序列，读回与原文一致', () async {
      final full = parts.join();
      final p = await write('gbk_novel.txt', const GbkCodec().encode(full));
      final index = await NovelTextStream.buildIndex(p, chunkBytes: 16);
      expect(index.encoding, NovelEncoding.gb18030);
      expect(index.chapters.length, parts.length);
      for (var i = 0; i < parts.length; i++) {
        expect(index.chapters[i].title, parts[i].split('\n').first);
        expect(await NovelTextStream.readChapter(p, index, index.chapters[i]),
            parts[i]);
      }
    });

    test('UTF-16 LE/BE：奇数 chunk 触发对齐余字节，读回一致', () async {
      for (final bigEndian in [false, true]) {
        final full = parts.join();
        final p = await write(
          'u16_${bigEndian ? 'be' : 'le'}.txt',
          utf16Bytes(full, bigEndian: bigEndian),
        );
        final index = await NovelTextStream.buildIndex(p, chunkBytes: 17);
        expect(index.encoding,
            bigEndian ? NovelEncoding.utf16be : NovelEncoding.utf16le);
        expect(index.chapters.length, parts.length);
        for (var i = 0; i < parts.length; i++) {
          expect(index.chapters[i].title, parts[i].split('\n').first);
          expect(await NovelTextStream.readChapter(p, index, index.chapters[i]),
              parts[i]);
        }
      }
    });

    test('无标题 → 按约 6000 字兜底切段，拼接还原全文', () async {
      final line = '正文内容' * 25; // 100 字，>=40 不会被当标题
      final text = '${List.filled(150, line).join('\n')}\n';
      final p = await write('plain.txt', utf8.encode(text));
      final index = await NovelTextStream.buildIndex(p);
      expect(index.chapters.length, 3);
      expect(index.chapters.map((c) => c.title).toList(),
          ['第1段', '第2段', '第3段']);
      expect(index.chapters.map((c) => c.charCount).toList(),
          [6000, 6000, 3000]);
      final joined = StringBuffer();
      for (var i = 0; i < index.chapters.length; i++) {
        final ch = index.chapters[i];
        if (i > 0) {
          final prev = index.chapters[i - 1];
          expect(ch.byteOffset, prev.byteOffset + prev.byteLength);
        }
        joined.write(await NovelTextStream.readChapter(p, index, ch));
      }
      expect(joined.toString(), text);
    });

    test('shouldStop → NovelCancelledException', () async {
      final p = await write('cancel.txt', utf8.encode('字' * 3000));
      expect(
        () => NovelTextStream.buildIndex(p,
            chunkBytes: 1024, shouldStop: () => true),
        throwsA(isA<NovelCancelledException>()),
      );
    });

    test('onProgress 单调递增且最终等于文件大小', () async {
      final bytes = utf8.encode('内容。\n' * 1000);
      final p = await write('prog.txt', bytes);
      final calls = <(int, int)>[];
      await NovelTextStream.buildIndex(p,
          chunkBytes: 1024, onProgress: (d, t) => calls.add((d, t)));
      expect(calls, isNotEmpty);
      for (var i = 0; i < calls.length; i++) {
        expect(calls[i].$2, bytes.length);
        if (i > 0) expect(calls[i].$1, greaterThan(calls[i - 1].$1));
      }
      expect(calls.last.$1, bytes.length);
    });

    test('大文件：200 章约 2.7MB，索引与抽样读回正确', () async {
      final body = '剧情推进，李明与王芳在青云城对话。' * 90;
      final parts = <String>[
        for (var i = 0; i < 200; i++) '第${i + 1}章 标题$i\n$body\n$body\n$body\n',
      ];
      final bytes = utf8.encode(parts.join());
      expect(bytes.length, greaterThan(2 * 1024 * 1024));
      final p = await write('big.txt', bytes);
      final progress = <int>[];
      final index = await NovelTextStream.buildIndex(p,
          onProgress: (d, t) => progress.add(d));
      expect(index.chapters.length, 200);
      expect(progress.last, bytes.length);
      expect(index.totalChars,
          index.chapters.fold<int>(0, (s, c) => s + c.charCount));
      for (final i in [0, 99, 199]) {
        final ch = index.chapters[i];
        expect(ch.title, '第${i + 1}章 标题$i');
        expect(await NovelTextStream.readChapter(p, index, ch), parts[i]);
      }
      final last = index.chapters.last;
      expect(last.byteOffset + last.byteLength, bytes.length);
    });
  });

  group('fileFingerprint', () {
    test('同一路径两次一致；与 ChapterIndex.fingerprint 相等；内容变化后变化',
        () async {
      final p = await write('fp.txt', utf8.encode('第一章 起\n内容。\n'));
      final fp1 = await NovelTextStream.fileFingerprint(p);
      final fp2 = await NovelTextStream.fileFingerprint(p);
      expect(fp2, fp1);
      final index = await NovelTextStream.buildIndex(p);
      expect(index.fingerprint, fp1);
      await File(p).writeAsString('追加内容改变文件大小', flush: true);
      final fp3 = await NovelTextStream.fileFingerprint(p);
      expect(fp3, isNot(fp1));
    });
  });

  group('splitBlocks', () {
    test('不超限返回单元素', () {
      expect(NovelTextStream.splitBlocks('abc', 10), ['abc']);
    });

    test('优先在段落边界切，拼接还原原文', () {
      final text = List.generate(6, (_) => '${'段' * 30}\n\n').join();
      final blocks = NovelTextStream.splitBlocks(text, 64);
      expect(blocks.length, 3);
      for (final b in blocks) {
        expect(b.length, lessThanOrEqualTo(64));
        expect(b.endsWith('\n\n'), isTrue);
      }
      expect(blocks.join(), text);
    });

    test('超长单行在句末标点处切', () {
      final line = '这是一个完整的句子。' * 20; // 200 字
      final blocks = NovelTextStream.splitBlocks(line, 50);
      expect(blocks.length, 4);
      for (final b in blocks) {
        expect(b.length, lessThanOrEqualTo(50));
        expect(b.endsWith('。'), isTrue);
      }
      expect(blocks.join(), line);
    });

    test('无标点超长行硬切仍不超限', () {
      final line = '字' * 250;
      final blocks = NovelTextStream.splitBlocks(line, 60);
      for (final b in blocks) {
        expect(b.length, lessThanOrEqualTo(60));
      }
      expect(blocks.join(), line);
    });
  });

  group('prepareTextFile', () {
    test('txt / md 原样返回', () async {
      final txt = await write('a.txt', utf8.encode('内容'));
      final md = await write('a.md', utf8.encode('# 标题'));
      expect(await NovelTextStream.prepareTextFile(txt), txt);
      expect(await NovelTextStream.prepareTextFile(md), md);
    });

    test('docx → UTF-8 临时 txt', () async {
      const xml =
          '<?xml version="1.0"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
          '<w:body><w:p><w:r><w:t>第一段</w:t></w:r></w:p>'
          '<w:p><w:r><w:t>第二段</w:t></w:r></w:p></w:body></w:document>';
      final xmlBytes = Uint8List.fromList(utf8.encode(xml));
      final archive = Archive()
        ..addFile(ArchiveFile('word/document.xml', xmlBytes.length, xmlBytes));
      final docx = Uint8List.fromList(ZipEncoder().encode(archive)!);
      final p = await write('book.docx', docx);
      final out = await NovelTextStream.prepareTextFile(p);
      addTearDown(() async {
        final dir = File(out).parent;
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      expect(out, isNot(p));
      expect(out.endsWith('.txt'), isTrue);
      final content = await File(out).readAsString();
      expect(content, contains('第一段'));
      expect(content, contains('第二段'));
      expect(await NovelTextStream.detectEncoding(out), NovelEncoding.utf8);
    });

    test('超过 maxDocBytes 抛可读异常', () async {
      final p = await write('big.docx', List.filled(30, 0x50));
      expect(
        () => NovelTextStream.prepareTextFile(p, maxDocBytes: 10),
        throwsA(isA<NovelFormatException>()
            .having((e) => e.message, 'message', contains('txt'))),
      );
    });

    test('损坏的 docx 抛可读异常', () async {
      final p = await write('bad.docx', utf8.encode('this is not a zip'));
      expect(
        () => NovelTextStream.prepareTextFile(p),
        throwsA(isA<NovelFormatException>()),
      );
    });
  });
}
