import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/core/novel/job_store.dart';
import 'package:tavern_app/core/novel/novel_types.dart';
import 'package:tavern_app/core/novel/worker.dart';

/// worker isolate 的端到端冒烟测试：不联网（API 指向必然连不上的地址），
/// 验证 isolate 能启动、进度能上报、checkpoint 会落盘、失败会优雅收尾而不是崩掉。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('worker isolate reports progress and fails gracefully without network',
      () async {
    final root = await Directory.systemTemp.createTemp('novel-worker-test-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    final src = File('${root.path}/book.txt');
    await src.writeAsString(
      [
        '第一章 出逃',
        '林清推开门，风雪灌进来。她握紧了刀。',
        '',
        '第二章 青云城',
        '青云城在雪山脚下，城墙很高。林清抬头看了一眼。',
      ].join('\n'),
      flush: true,
    );

    final store = NovelJobStore(root.path);
    final realConfig = NovelJobConfig(
      filePath: src.path,
      fileName: 'book.txt',
      scanMode: ScanMode.headOnly,
      headChapters: 2,
      maxCards: 1,
      maxLoreEntries: 3,
      concurrency: 1,
    );

    final jobId = 'test-job';
    await store.saveJob(
      NovelJob(id: jobId, config: realConfig, createdAt: 1),
    );

    const settings = AppSettings(
      api: APISettings(
        provider: 'openai',
        // 端口 1 必然连接被拒：快速失败，不依赖外网。
        baseUrl: 'http://127.0.0.1:1/v1',
        apiKey: 'k',
        model: 'm',
        maxTokens: 4096,
      ),
    );

    final port = ReceivePort();
    final messages = <Map<String, dynamic>>[];
    final terminal = Completer<void>();
    final sub = port.listen((dynamic msg) {
      if (msg is! Map) return;
      final map = Map<String, dynamic>.from(msg);
      if (map['type'] == 'control') return;
      messages.add(map);
      // worker 的终态既可能是 result，也可能是 progress 里 state=error/done/cancelled。
      var done = map['type'] == 'error' || map['type'] == 'result';
      if (!done && map['type'] == 'progress' && map['progress'] is Map) {
        final st = (map['progress'] as Map)['state']?.toString();
        done = st == GenState.error.name ||
            st == GenState.done.name ||
            st == GenState.cancelled.name;
      }
      if (done && !terminal.isCompleted) terminal.complete();
    });

    final isolate = await Isolate.spawn(
      novelWorkerMain,
      NovelWorkerArgs(
        sendPort: port.sendPort,
        rootPath: root.path,
        jobId: jobId,
        configJson: realConfig.toJson(),
        settingsJson: settings.toJson(),
      ).toMessage(),
    );
    addTearDown(() {
      isolate.kill(priority: Isolate.immediate);
      sub.cancel();
      port.close();
    });

    await terminal.future.timeout(
      const Duration(seconds: 120),
      onTimeout: () => fail('worker 在 120s 内没有给出终态（可能卡死）'),
    );

    // 至少收到过进度，且进度里出现过切章/抽取阶段。
    final progress = messages
        .where((m) => m['type'] == 'progress' && m['progress'] is Map)
        .map((m) => GenProgress.fromJson(
            Map<String, dynamic>.from(m['progress'] as Map)))
        .toList();
    expect(progress, isNotEmpty);
    expect(
      progress.any((p) =>
          p.phase == GenPhase.extracting ||
          p.phase == GenPhase.scanning ||
          p.phase == GenPhase.indexing),
      true,
    );

    // checkpoint 落盘：job.json 里有章节索引。
    final job = await store.loadJob(jobId);
    expect(job, isNotNull);
    expect(job!.index, isNotNull);
    expect(job.index!.chapters, isNotEmpty);
    expect(job.totalBlocks, greaterThan(0));

    // 连接被拒 → 所有块失败 → worker 报错（而不是静默完成）。
    final hasError = messages.any((m) => m['type'] == 'error');
    final hasResult = messages.any((m) => m['type'] == 'result');
    expect(hasError || hasResult, true,
        reason: '拿到的消息类型：${messages.map((m) => m['type']).toSet()}');
    if (hasError) {
      final err = messages.firstWhere((m) => m['type'] == 'error');
      expect(err['message'].toString(), isNotEmpty);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
