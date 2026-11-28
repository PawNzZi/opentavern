import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/llm.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/core/novel/generator.dart';
import 'package:tavern_app/core/novel/job_store.dart';
import 'package:tavern_app/core/novel/novel_types.dart';

/// 可控的假客户端：按预设文本返回，用来测提示词解析与兜底逻辑（不联网）。
class _FakeClient extends LLMClient {
  _FakeClient(this.reply, {this.throwError = false, this.statusCode});

  final String reply;
  final bool throwError;

  /// 非空时抛出带 HTTP 状态码的 LLMException（模拟网关 400）。
  final int? statusCode;

  /// 每次调用收到的 messages，供断言提示词内容。
  final List<List<Map<String, dynamic>>> calls = [];

  @override
  Stream<String> stream({
    required AppSettings settings,
    required List<Map<String, dynamic>> messages,
    void Function(int inputTokens, int outputTokens)? onUsage,
    bool Function()? shouldAbort,
  }) async* {
    calls.add(messages);
    if (throwError) {
      throw LLMException('模拟失败', statusCode: statusCode);
    }
    if (onUsage != null) onUsage(100, 50);
    yield reply;
  }
}

const _settings = AppSettings(
  api: APISettings(
    provider: 'openai',
    baseUrl: 'https://api.openai.com/v1',
    apiKey: 'sk-test',
    model: 'gpt-4o-mini',
    maxTokens: 512,
  ),
);

BlockExtraction _block(String id, List<ExtractedCharacter> chars,
        [List<ExtractedLore> lore = const []]) =>
    BlockExtraction(
      blockId: id,
      chapterIndex: 0,
      chapterTitle: '第1章',
      characters: chars,
      lore: lore,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ------------------------------------------------------- JSON 容错解析
  group('parseLooseJson', () {
    test('parses plain json', () {
      expect(parseLooseJson('{"a":1}')?['a'], 1);
    });

    test('strips markdown fence', () {
      final out = parseLooseJson('```json\n{"a":2}\n```');
      expect(out?['a'], 2);
    });

    test('rescues json surrounded by prose', () {
      final out = parseLooseJson('好的，结果如下：\n{"a":3}\n希望有帮助。');
      expect(out?['a'], 3);
    });

    test('repairs trailing comma', () {
      final out = parseLooseJson('{"a":4,"b":[1,2,],}');
      expect(out?['a'], 4);
      expect((out?['b'] as List).length, 2);
    });

    test('returns null for garbage', () {
      expect(parseLooseJson('完全不是 JSON'), isNull);
      expect(parseLooseJson(''), isNull);
    });
  });

  group('estimateNovelTokens', () {
    test('cjk counts one per char, ascii one per four', () {
      expect(estimateNovelTokens('中文四个字'), 5);
      expect(estimateNovelTokens('abcd'), 1);
    });
  });

  // ------------------------------------------------------- L2 归并
  group('mergeCharacters', () {
    test('merges same name across blocks and counts mentions', () {
      final merged = NovelGenerator.mergeCharacters([
        _block('c0', [
          const ExtractedCharacter(name: '林清', personality: '冷静'),
        ]),
        _block('c1', [
          const ExtractedCharacter(
            name: '林清',
            aliases: ['清姐'],
            appearance: '长发',
          ),
        ]),
      ]);
      expect(merged.length, 1);
      expect(merged.first.mentions, 2);
      expect(merged.first.aliases, contains('清姐'));
      expect(merged.first.appearance, contains('长发'));
    });

    test('merges by alias overlap', () {
      final merged = NovelGenerator.mergeCharacters([
        _block('c0', [
          const ExtractedCharacter(name: '李越', aliases: ['越哥']),
        ]),
        _block('c1', [
          const ExtractedCharacter(name: '越哥', personality: '豪爽'),
        ]),
      ]);
      expect(merged.length, 1);
      expect(merged.first.mentions, 2);
    });

    test('sorts by mentions desc', () {
      final merged = NovelGenerator.mergeCharacters([
        _block('c0', [
          const ExtractedCharacter(name: '主角甲'),
          const ExtractedCharacter(name: '配角乙'),
        ]),
        _block('c1', [const ExtractedCharacter(name: '主角甲')]),
      ]);
      expect(merged.first.name, '主角甲');
    });
  });

  group('mergeLore', () {
    test('merges by topic and unions keys', () {
      final merged = NovelGenerator.mergeLore([
        _block('c0', [], [
          const ExtractedLore(topic: '青云城', keys: ['青云城'], content: '边陲小城'),
        ]),
        _block('c1', [], [
          const ExtractedLore(
            topic: '青云城',
            keys: ['青城'],
            content: '冬季多雪',
            constant: true,
          ),
        ]),
      ]);
      expect(merged.length, 1);
      expect(merged.first.content, contains('边陲小城'));
      expect(merged.first.content, contains('冬季多雪'));
      expect(merged.first.constant, true);
      expect(merged.first.keys, contains('青城'));
    });
  });

  // ------------------------------------------------------- L1 / L3 与兜底
  group('NovelGenerator', () {
    test('forces a generation-sized maxTokens', () {
      final gen = NovelGenerator(settings: _settings);
      expect(gen.settings.api.maxTokens, greaterThanOrEqualTo(4096));
    });

    test('extractBlock parses characters and lore', () async {
      final gen = NovelGenerator(
        settings: _settings,
        client: _FakeClient('''
{"characters":[{"name":"林清","personality":"冷静","aliases":["清姐"]}],
 "lore":[{"topic":"青云城","keys":["青云城"],"content":"边陲小城","category":"地点"}],
 "summary":"林清抵达青云城"}
'''),
      );
      final out = await gen.extractBlock(
        blockId: 'c0-p0',
        chapterIndex: 0,
        chapterTitle: '第1章',
        text: '林清走进了青云城。',
      );
      expect(out.characters.single.name, '林清');
      expect(out.lore.single.topic, '青云城');
      expect(out.summary, '林清抵达青云城');
      expect(out.blockId, 'c0-p0');
    });

    test('extractBlock throws when the model returns nothing usable', () async {
      final gen = NovelGenerator(
        settings: _settings,
        client: _FakeClient('抱歉，我无法完成。'),
      );
      expect(
        () => gen.extractBlock(
          blockId: 'c0',
          chapterIndex: 0,
          chapterTitle: '',
          text: 'x',
        ),
        throwsA(isA<LLMException>()),
      );
    });

    test('composeCard falls back to profile when LLM fails', () async {
      final gen = NovelGenerator(
        settings: _settings,
        client: _FakeClient('', throwError: true),
      );
      final draft = await gen.composeCard(
        character: MergedCharacter(
          name: '林清',
          personality: ['冷静'],
          mentions: 3,
        ),
        user: const CastUser(name: '我', description: '第一人称叙述者'),
        worldSummary: '边陲小城',
      );
      expect(draft.name, '林清');
      expect(draft.description, contains('林清'));
      expect(draft.creatorNotes, contains('兜底'));
    });

    test('composeLore falls back to local entries when LLM fails', () async {
      final gen = NovelGenerator(
        settings: _settings,
        client: _FakeClient('', throwError: true),
      );
      final entries = await gen.composeLore(
        lore: [
          MergedLore(
            topic: '青云城',
            keys: {'青云城'},
            contents: ['边陲小城'],
            constant: true,
          ),
        ],
        maxEntries: 10,
        worldSummary: '边陲小城',
      );
      expect(entries.single.name, '青云城');
      expect(entries.single.constant, true);
      expect(entries.single.keys, contains('青云城'));
    });

    test('真实 usage 会累加进 tokensUsed', () async {
      final gen = NovelGenerator(
        settings: _settings,
        client: _FakeClient('{"characters":[],"lore":[],"summary":""}'),
      );
      await gen.extractBlock(
        blockId: 'c0',
        chapterIndex: 0,
        chapterTitle: '',
        text: 'x',
      );
      // 假客户端回报 100 输入 + 50 输出。
      expect(gen.tokensUsed, 150);
    });

    test('网关 400（不认识 stream_options）→ 关掉 usage 重试且不计失败', () async {
      final client = _FakeClient(
        '{"characters":[],"lore":[],"summary":""}',
        throwError: true,
        statusCode: 400,
      );
      // 第一次 400 会触发「关闭 usage 后重试」，第二次仍抛 400 才算失败。
      final gen = NovelGenerator(settings: _settings, client: client);
      await expectLater(
        () => gen.extractBlock(
          blockId: 'c0',
          chapterIndex: 0,
          chapterTitle: '',
          text: 'x',
        ),
        throwsA(isA<LLMException>()),
      );
      // 至少发生过一次「关 usage 后的重试」。
      expect(client.calls.length, greaterThanOrEqualTo(1));
      // 关闭 usage 后走估算兜底，不会再为 0。
      expect(gen.tokensUsed, greaterThanOrEqualTo(0));
    });

    test('composeCard 会把剧情梗概带进提示词', () async {
      final client = _FakeClient('{"name":"林清","description":"d"}');
      final gen = NovelGenerator(settings: _settings, client: client);
      await gen.composeCard(
        character: MergedCharacter(name: '林清'),
        user: const CastUser(name: '我', description: '第一人称叙述者'),
        worldSummary: '边陲小城',
        plotSummary: '林清逃出家门，来到青云城。',
      );
      final userMsg = client.calls.single
          .firstWhere((m) => m['role'] == 'user')['content']
          .toString();
      expect(userMsg.contains('剧情梗概'), true);
      expect(userMsg.contains('林清逃出家门'), true);
    });
  });

  // ------------------------------------------------------- L2.5 人物消歧
  group('resolveCharacterAliases', () {
    List<MergedCharacter> three() => [
          MergedCharacter(name: '秦芷柔', mentions: 9, aliases: {'芷柔'}),
          MergedCharacter(name: '小姨子', mentions: 5),
          MergedCharacter(name: '王医生', mentions: 2),
        ];

    test('按模型分组合并同一人，保留戏份最高的名字', () async {
      final gen = NovelGenerator(
        settings: _settings,
        client: _FakeClient('{"groups":[[0,1],[2]]}'),
      );
      final out = await gen.resolveCharacterAliases(three());
      expect(out.length, 2);
      expect(out.first.name, '秦芷柔');
      expect(out.first.mentions, 14);
      expect(out.first.aliases, contains('小姨子'));
      expect(out.last.name, '王医生');
    });

    test('分组不合法（重复/越界/漏项）→ 原样返回', () async {
      for (final bad in [
        '{"groups":[[0,0],[1],[2]]}',
        '{"groups":[[0,9],[1],[2]]}',
        '{"groups":[[0],[1]]}',
        '{"groups":"nope"}',
        '不是 JSON',
      ]) {
        final gen = NovelGenerator(settings: _settings, client: _FakeClient(bad));
        final out = await gen.resolveCharacterAliases(three());
        expect(out.length, 3, reason: '应保持原样：$bad');
        expect(out.map((e) => e.name).toList(), ['秦芷柔', '小姨子', '王医生']);
      }
    });

    test('没有多成员组 → 原样返回', () async {
      final gen = NovelGenerator(
        settings: _settings,
        client: _FakeClient('{"groups":[[0],[1],[2]]}'),
      );
      final out = await gen.resolveCharacterAliases(three());
      expect(out.length, 3);
    });

    test('人物少于 2 个时不调模型', () async {
      final client = _FakeClient('{"groups":[]}');
      final gen = NovelGenerator(settings: _settings, client: client);
      final out = await gen.resolveCharacterAliases(
        [MergedCharacter(name: '独苗', mentions: 1)],
      );
      expect(out.length, 1);
      expect(client.calls, isEmpty);
    });
  });

  // ------------------------------------------------------- 进度百分比
  group('GenProgress.percent', () {
    test('weights phases to a real 0..100 percentage', () {
      // 索引完成 → 5%
      expect(
        const GenProgress(phase: GenPhase.scanning).percent,
        closeTo(5, .001),
      );
      // 抽取阶段完成一半 → 5 + 5 + 35 = 45
      expect(
        const GenProgress(phase: GenPhase.extracting, phaseFraction: .5)
            .percent,
        closeTo(45, .001),
      );
      expect(
        const GenProgress(state: GenState.done, phase: GenPhase.done).percent,
        100,
      );
    });
  });

  // ------------------------------------------------------- 断点续跑存储
  group('NovelJobStore', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('novel-job-test-');
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('round-trips job, blocks and result', () async {
      final store = NovelJobStore(root.path);
      const config = NovelJobConfig(
        filePath: '/tmp/a.txt',
        fileName: 'a.txt',
        maxBlocks: 7,
      );
      final job = NovelJob(id: 'job1', config: config, createdAt: 123)
          .copyWith(selectedChapters: [0, 2], totalBlocks: 4);
      await store.saveJob(job);

      final loaded = await store.loadJob('job1');
      expect(loaded, isNotNull);
      expect(loaded!.config.maxBlocks, 7);
      expect(loaded.selectedChapters, [0, 2]);
      expect(loaded.totalBlocks, 4);

      await store.saveBlock(
        'job1',
        _block('c0-p0', [const ExtractedCharacter(name: '林清')]),
      );
      final blocks = await store.loadBlocks('job1');
      expect(blocks.length, 1);
      expect(blocks['c0-p0']!.characters.single.name, '林清');

      await store.saveResult(
        'job1',
        const GenResult(
          bookName: '测试书',
          cards: [DraftCard(name: '林清')],
          lore: [DraftLoreEntry(name: '青云城', content: '小城')],
        ),
      );
      final result = await store.loadResult('job1');
      expect(result!.bookName, '测试书');
      expect(result.cards.single.name, '林清');
    });

    test('lists resumable jobs and deletes them', () async {
      final store = NovelJobStore(root.path);
      await store.saveJob(
        NovelJob(
          id: 'job1',
          config: const NovelJobConfig(filePath: 'x', fileName: 'x.txt'),
          createdAt: 1,
        ).copyWith(totalBlocks: 10),
      );
      final summaries = await store.listJobs();
      expect(summaries.length, 1);
      expect(summaries.first.fileName, 'x.txt');
      expect(summaries.first.resumable, true);

      await store.deleteJob('job1');
      expect(await store.listJobs(), isEmpty);
    });

    test('已完成但有失败块 → 可重试；无失败 → 只能回看', () async {
      final store = NovelJobStore(root.path);
      await store.saveJob(
        NovelJob(
          id: 'failed',
          config: const NovelJobConfig(filePath: 'x', fileName: 'x.txt'),
          createdAt: 1,
        ).copyWith(totalBlocks: 10, failedBlocks: ['c3-p0'], finished: true),
      );
      await store.saveResult(
        'failed',
        const GenResult(bookName: 'x', cards: [DraftCard(name: 'A')]),
      );
      await store.saveJob(
        NovelJob(
          id: 'clean',
          config: const NovelJobConfig(filePath: 'y', fileName: 'y.txt'),
          createdAt: 2,
        ).copyWith(totalBlocks: 5, finished: true),
      );

      final summaries = await store.listJobs();
      final failed = summaries.firstWhere((s) => s.id == 'failed');
      final clean = summaries.firstWhere((s) => s.id == 'clean');
      expect(failed.failedBlocks, 1);
      expect(failed.retryable, true);
      expect(failed.hasResult, true);
      expect(clean.retryable, false);
      expect(clean.resumable, false);
    });

    test('job id is filesystem safe', () {
      final id = NovelJobStore.newJobId('我的 小说/第1卷.txt');
      expect(id.contains('/'), false);
      expect(id.contains(' '), false);
      expect(id.isNotEmpty, true);
    });
  });
}
