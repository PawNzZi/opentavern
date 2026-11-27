import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/novel/novel_types.dart';
import 'package:tavern_app/core/novel/stats.dart';
import 'package:tavern_app/core/novel/text_stream.dart';

/// 200 章合成小说：i % 5 == 0 的章人名密度高（40 行对话），其余低（8 行）。
String chapterText(int i) {
  final b = StringBuffer();
  b.writeln('第${i + 1}章 试炼$i');
  final reps = i % 5 == 0 ? 40 : 8;
  for (var k = 0; k < reps; k++) {
    b.writeln('李明说道：「青云城的试炼开始了。」王芳笑了笑，欧阳锋看着远方。');
  }
  b.writeln('山风吹过青云城外的荒野，卷起漫天黄沙。' * 80);
  b.writeln('天剑宗的弟子们前往青云城，修炼《九转玄功》。');
  return b.toString();
}

void main() {
  late Directory tmp;
  late String path;
  late ChapterIndex index;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('novel_stats_test_');
    final text = [for (var i = 0; i < 200; i++) chapterText(i)].join();
    final f = File('${tmp.path}${Platform.pathSeparator}novel.txt');
    await f.writeAsBytes(utf8.encode(text), flush: true);
    path = f.path;
    index = await NovelTextStream.buildIndex(path);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  NovelJobConfig config({
    ScanMode mode = ScanMode.smart,
    int maxBlocks = 120,
    int headChapters = 20,
  }) =>
      NovelJobConfig(
        filePath: path,
        fileName: 'novel.txt',
        scanMode: mode,
        maxBlocks: maxBlocks,
        headChapters: headChapters,
      );

  group('scan', () {
    test('人名/专有名词候选、每章字数与戏份密度', () async {
      final stats = await NovelSampler.scan(path, index);
      expect(stats.nameCandidates['李明'], greaterThan(0));
      expect(stats.nameCandidates.containsKey('王芳'), isTrue);
      expect(stats.nameCandidates.containsKey('欧阳锋'), isTrue);
      expect(stats.termCandidates.containsKey('青云城'), isTrue);
      expect(stats.termCandidates.containsKey('天剑宗'), isTrue);
      expect(stats.termCandidates.containsKey('九转玄功'), isTrue);
      expect(stats.chapterCharCounts.length, 200);
      for (final c in stats.chapterCharCounts) {
        expect(c, greaterThan(0));
      }
      // 高密度章（0）命中显著多于低密度章（1）。
      expect(stats.chapterNameHits[0], greaterThan(stats.chapterNameHits[1]!));
      expect(stats.nameCandidates.length, lessThanOrEqualTo(300));
      expect(stats.termCandidates.length, lessThanOrEqualTo(300));
    });

    test('候选 map 有界：529 个不同人名只保留 300', () async {
      const chars = '甲乙丙丁戊己庚辛壬癸子丑寅卯辰巳午未申酉戌亥天';
      final b = StringBuffer();
      for (final a in chars.runes) {
        for (final c in chars.runes) {
          b.writeln('${String.fromCharCode(a)}${String.fromCharCode(c)}说道。');
        }
      }
      final f = File('${tmp.path}${Platform.pathSeparator}names.txt');
      await f.writeAsBytes(utf8.encode(b.toString()), flush: true);
      final idx = await NovelTextStream.buildIndex(f.path);
      final stats = await NovelSampler.scan(f.path, idx);
      expect(stats.nameCandidates.length, 300);
    });

    test('onProgress 到达总数；shouldStop 抛 NovelCancelledException',
        () async {
      final calls = <(int, int)>[];
      await NovelSampler.scan(path, index,
          onProgress: (d, t) => calls.add((d, t)));
      expect(calls.last, (200, 200));
      expect(
        () => NovelSampler.scan(path, index, shouldStop: () => true),
        throwsA(isA<NovelCancelledException>()),
      );
    });
  });

  group('selectChapters', () {
    late NovelStats stats;

    setUp(() async {
      stats = await NovelSampler.scan(path, index);
    });

    test('smart：不超预算、含首尾、升序、确定性、密度补齐', () async {
      final cfg = config(maxBlocks: 30);
      final a = NovelSampler.selectChapters(index, stats, cfg);
      final b = NovelSampler.selectChapters(index, stats, cfg);
      expect(a, b); // 确定性
      expect(a.length, 30);
      expect(a, containsAll([0, 1, 2, 198, 199]));
      for (var i = 1; i < a.length; i++) {
        expect(a[i], greaterThan(a[i - 1])); // 严格升序（去重）
      }
      // 高密度章（5 的倍数）应被密度补齐选中。
      expect(a, contains(5));
    });

    test('smart：n 小于预算返回全部', () async {
      final a = NovelSampler.selectChapters(index, stats, config(maxBlocks: 500));
      expect(a, List.generate(200, (i) => i));
    });

    test('smart：极小预算优先开头', () async {
      final a = NovelSampler.selectChapters(index, stats, config(maxBlocks: 3));
      expect(a, [0, 1, 2]);
    });

    test('full：全部章', () async {
      final a =
          NovelSampler.selectChapters(index, stats, config(mode: ScanMode.full));
      expect(a, List.generate(200, (i) => i));
    });

    test('headOnly：前 N 章，N 超界取全部', () async {
      final a = NovelSampler.selectChapters(index, stats,
          config(mode: ScanMode.headOnly, headChapters: 7));
      expect(a, [0, 1, 2, 3, 4, 5, 6]);
      final b = NovelSampler.selectChapters(index, stats,
          config(mode: ScanMode.headOnly, headChapters: 500));
      expect(b.length, 200);
    });
  });
}
