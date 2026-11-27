import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import '../models.dart';
import 'generator.dart';
import 'job_store.dart';
import 'novel_types.dart';
import 'stats.dart';
import 'text_stream.dart';

/// worker isolate 的启动参数（全部 JSON 安全值）。
///
/// 后台 isolate 不能用 platform channel，所以存储根目录、API 设置都由主
/// isolate 取好后以纯数据传进来。
class NovelWorkerArgs {
  const NovelWorkerArgs({
    required this.sendPort,
    required this.rootPath,
    required this.jobId,
    required this.configJson,
    required this.settingsJson,
    this.resume = false,
  });

  final SendPort sendPort;
  final String rootPath;
  final String jobId;
  final Map<String, dynamic> configJson;
  final Map<String, dynamic> settingsJson;
  final bool resume;

  Map<String, dynamic> toMessage() => {
        'sendPort': sendPort,
        'rootPath': rootPath,
        'jobId': jobId,
        'config': configJson,
        'settings': settingsJson,
        'resume': resume,
      };
}

/// isolate 入口。必须是顶层函数。
Future<void> novelWorkerMain(Map<String, dynamic> message) async {
  final sendPort = message['sendPort'] as SendPort;
  final control = ReceivePort();
  // 把控制端口回传主 isolate，用于暂停/继续/取消。
  sendPort.send({'type': 'control', 'port': control.sendPort});

  final runner = _WorkerRun(
    sendPort: sendPort,
    store: NovelJobStore((message['rootPath'] ?? '').toString()),
    jobId: (message['jobId'] ?? '').toString(),
    config: NovelJobConfig.fromJson(
      Map<String, dynamic>.from(message['config'] as Map? ?? const {}),
    ),
    settings: AppSettings.fromJson(
      Map<String, dynamic>.from(message['settings'] as Map? ?? const {}),
    ),
    resume: message['resume'] == true,
  );

  control.listen((dynamic cmd) {
    switch (cmd) {
      case 'pause':
        runner.paused = true;
        runner.emit(force: true);
      case 'resume':
        runner.paused = false;
        runner.emit(force: true);
      case 'cancel':
        runner.cancelled = true;
        runner.paused = false;
    }
  });

  try {
    await runner.run();
  } catch (e) {
    if (e is NovelCancelledException || e is NovelStoppedException) {
      runner.state = GenState.cancelled;
      runner.emit(force: true);
      sendPort.send({'type': 'cancelled'});
    } else {
      runner.state = GenState.error;
      runner.error = e.toString();
      runner.emit(force: true);
      // 显式错误消息：进度里的 error 已带上，但单独一条更方便主 isolate 记录/展示。
      sendPort.send({'type': 'error', 'message': e.toString()});
    }
  } finally {
    // 任何退出路径（成功/取消/出错）都清掉 docx/pdf 的临时 txt。
    await runner.cleanupTemp();
    control.close();
  }
}

class _WorkerRun {
  _WorkerRun({
    required this.sendPort,
    required this.store,
    required this.jobId,
    required this.config,
    required this.settings,
    required this.resume,
  });

  final SendPort sendPort;
  final NovelJobStore store;
  final String jobId;
  final NovelJobConfig config;
  final AppSettings settings;
  final bool resume;

  bool paused = false;
  bool cancelled = false;

  GenState state = GenState.running;
  GenPhase phase = GenPhase.indexing;
  double phaseFraction = 0;
  int doneBlocks = 0;
  int totalBlocks = 0;
  int tokensUsed = 0;
  int failedBlocks = 0;
  String currentLabel = '';
  String error = '';
  final List<String> logs = [];
  final List<String> failedIds = [];

  late final NovelGenerator generator = NovelGenerator(settings: settings);
  final Stopwatch clock = Stopwatch()..start();
  int _lastEmitMs = -1000;
  int _extractStartMs = 0;
  int _extractDoneAtStart = 0;

  /// docx/pdf 转出的临时 txt 路径（txt 原文件为 null）。任务结束要清理。
  String? _tempTextPath;

  /// 预算是否已烧完（烧完后停止抽取，用已有块成稿）。
  bool _budgetExhausted = false;

  bool get shouldStop => cancelled;

  /// 当前总 token 消耗（真实值优先，估算兜底）。
  int get usedTokens => tokensUsed + generator.tokensUsed;

  bool get overBudget =>
      config.tokenBudget > 0 && usedTokens >= config.tokenBudget;

  void log(String line) {
    logs.add(line);
    if (logs.length > 200) logs.removeRange(0, logs.length - 200);
  }

  /// 进度上报（节流 200ms，避免刷屏；force 用于状态切换）。
  void emit({bool force = false}) {
    final now = clock.elapsedMilliseconds;
    if (!force && now - _lastEmitMs < 200) return;
    _lastEmitMs = now;

    var eta = 0;
    if (phase == GenPhase.extracting && totalBlocks > 0) {
      final doneSinceStart = doneBlocks - _extractDoneAtStart;
      final spent = now - _extractStartMs;
      if (doneSinceStart > 0 && spent > 0) {
        eta = (spent / doneSinceStart * (totalBlocks - doneBlocks)).round();
      }
    }

    sendPort.send({
      'type': 'progress',
      'progress': GenProgress(
        state: cancelled
            ? GenState.cancelling
            : (paused ? GenState.paused : state),
        phase: phase,
        phaseFraction: phaseFraction,
        doneBlocks: doneBlocks,
        totalBlocks: totalBlocks,
        tokensUsed: tokensUsed + generator.tokensUsed,
        elapsedMs: now,
        etaMs: eta,
        currentLabel: currentLabel,
        failedBlocks: failedBlocks,
        logs: List<String>.from(logs),
        error: error,
      ).toJson(),
    });
  }

  Future<void> waitIfPaused() async {
    while (paused && !cancelled) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (cancelled) throw const NovelStoppedException();
  }

  void setPhase(GenPhase next, {double fraction = 0}) {
    phase = next;
    phaseFraction = fraction;
    emit(force: true);
  }

  Future<void> run() async {
    var job = resume ? await store.loadJob(jobId) : null;
    job ??= NovelJob(
      id: jobId,
      config: config,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    // ---------------------------------------------------- 1. 读取切章
    setPhase(GenPhase.indexing);
    currentLabel = '准备文本…';
    emit(force: true);
    // docx/pdf 每次都会转出新的临时 txt：先把旧的任务级临时目录扫掉，
    // 避免长期使用后越积越多（单任务串行，不会误删正在用的目录）。
    await sweepTempExtracts();
    final textPath = await NovelTextStream.prepareTextFile(config.filePath);
    _tempTextPath = textPath == config.filePath ? null : textPath;

    ChapterIndex? index = job.index;
    if (index != null) {
      // 文件被改过就不能复用旧索引。
      final stamp = await NovelTextStream.fileFingerprint(textPath);
      if (stamp != index.fingerprint) index = null;
    }
    if (index == null) {
      log('开始读取并切章：${config.fileName}');
      // 手动指定的编码优先于自动探测（短 GBK 文件的兜底）。
      NovelEncoding? encOverride;
      final encName = config.encodingOverride.trim();
      if (encName.isNotEmpty) {
        for (final e in NovelEncoding.values) {
          if (e.name == encName) {
            encOverride = e;
            break;
          }
        }
      }
      index = await NovelTextStream.buildIndex(
        textPath,
        encoding: encOverride,
        onProgress: (done, total) {
          phaseFraction = total == 0 ? 0 : done / total;
          currentLabel = '读取中 ${(phaseFraction * 100).toStringAsFixed(0)}%';
          emit();
        },
        shouldStop: () => shouldStop,
      );
      log('识别到 ${index.chapters.length} 章 · 编码 ${index.encoding.label} '
          '· 约 ${index.totalChars} 字');
      job = job.copyWith(index: index);
      await store.saveJob(job);
    } else {
      log('复用上次章节索引（${index.chapters.length} 章）');
    }
    phaseFraction = 1;
    emit(force: true);
    await waitIfPaused();

    // ---------------------------------------------------- 2. 本地统计
    setPhase(GenPhase.scanning);
    var stats = job.stats;
    if (stats == null) {
      currentLabel = '本地统计词频（不消耗 API）';
      emit(force: true);
      stats = await NovelSampler.scan(
        textPath,
        index,
        onProgress: (done, total) {
          phaseFraction = total == 0 ? 0 : done / total;
          emit();
        },
        shouldStop: () => shouldStop,
      );
      log('人名候选 ${stats.nameCandidates.length} 个 · '
          '专名候选 ${stats.termCandidates.length} 个');
      job = job.copyWith(stats: stats);
      await store.saveJob(job);
    }
    phaseFraction = 1;
    emit(force: true);
    await waitIfPaused();

    // ---------------------------------------------------- 3. 选块
    // 注意：这里只记录「块的位置」，不持正文。几百 MB 走全书精读时，
    // 若把所有块正文攒在内存里会直接 OOM；正文在抽取时按需读取。
    setPhase(GenPhase.extracting);
    final selected = job.selectedChapters.isNotEmpty
        ? job.selectedChapters
        : NovelSampler.selectChapters(index, stats, config);
    final plans = <_BlockPlan>[];
    for (var s = 0; s < selected.length; s++) {
      await waitIfPaused();
      final chapterIndex = selected[s];
      if (chapterIndex < 0 || chapterIndex >= index.chapters.length) continue;
      final ch = index.chapters[chapterIndex];
      // 逐章读一遍只为数出精确的块数，读完即丢，内存恒定。
      final text = await NovelTextStream.readChapter(textPath, index, ch);
      final pieces = NovelTextStream.splitBlocks(text, config.blockChars);
      for (var p = 0; p < pieces.length; p++) {
        if (pieces[p].trim().isEmpty) continue;
        plans.add(_BlockPlan(
          id: 'c$chapterIndex-p$p',
          chapterIndex: chapterIndex,
          chapterTitle: ch.title,
          pieceIndex: p,
        ));
      }
      phaseFraction = selected.isEmpty ? 0 : (s + 1) / selected.length;
      currentLabel = '规划抽取块 ${s + 1}/${selected.length} 章';
      emit();
    }
    totalBlocks = plans.length;
    job = job.copyWith(selectedChapters: selected, totalBlocks: totalBlocks);
    await store.saveJob(job);
    log('计划抽取 $totalBlocks 块（${selected.length} 章）');

    // ---------------------------------------------------- 4. L1 抽取
    setPhase(GenPhase.extracting);
    _extractStartMs = clock.elapsedMilliseconds;
    phaseFraction = 0;
    final cached = await store.loadBlocks(jobId);
    final done = <String, BlockExtraction>{...cached};
    doneBlocks = cached.length;
    _extractDoneAtStart = doneBlocks;
    if (cached.isNotEmpty) log('断点续跑：已完成 ${cached.length} 块，跳过');
    emit(force: true);

    final pending = plans.where((b) => !done.containsKey(b.id)).toList();
    // 章节正文小缓存：同一章被切成多块时不重复读盘，但只保留最近几章，
    // 内存与文件大小无关。
    final chapterCache = <int, List<String>>{};
    final cacheOrder = <int>[];

    Future<String> textFor(_BlockPlan plan) async {
      final key = plan.chapterIndex;
      final cachedPieces = chapterCache[key];
      if (cachedPieces != null) {
        return plan.pieceIndex < cachedPieces.length
            ? cachedPieces[plan.pieceIndex]
            : '';
      }
      final idx = index!;
      final text = await NovelTextStream.readChapter(
        textPath,
        idx,
        idx.chapters[key],
      );
      final pieces = NovelTextStream.splitBlocks(text, config.blockChars);
      chapterCache[key] = pieces;
      cacheOrder.add(key);
      while (cacheOrder.length > 4) {
        chapterCache.remove(cacheOrder.removeAt(0));
      }
      return plan.pieceIndex < pieces.length ? pieces[plan.pieceIndex] : '';
    }

    await _pool(pending, config.concurrency.clamp(1, 4), (plan) async {
      await waitIfPaused();
      // 预算闸门：烧完就不再发新请求，用已有块直接成稿。
      if (overBudget) {
        _budgetExhausted = true;
        return;
      }
      currentLabel = plan.chapterTitle.isEmpty
          ? '第${plan.chapterIndex + 1}章'
          : plan.chapterTitle;
      emit(force: true);
      try {
        final text = await textFor(plan);
        if (text.trim().isEmpty) {
          log('· ${plan.id} 空片，跳过');
          return;
        }
        final extraction = await generator.extractBlock(
          blockId: plan.id,
          chapterIndex: plan.chapterIndex,
          chapterTitle: plan.chapterTitle,
          text: text,
          extraInstruction: config.extraInstruction,
          shouldStop: () => shouldStop,
        );
        done[plan.id] = extraction;
        await store.saveBlock(jobId, extraction);
        log('✓ ${plan.id} ${plan.chapterTitle} '
            '人物${extraction.characters.length} 设定${extraction.lore.length}');
      } on NovelStoppedException {
        rethrow;
      } on NovelCancelledException {
        rethrow;
      } catch (e) {
        failedBlocks++;
        failedIds.add(plan.id);
        log('✗ ${plan.id} 失败：$e');
      } finally {
        doneBlocks = done.length;
        phaseFraction = totalBlocks == 0 ? 1 : doneBlocks / totalBlocks;
        emit(force: true);
      }
    });

    if (cancelled) throw const NovelStoppedException();
    if (_budgetExhausted) {
      log('已达 token 预算（${_compactTokens(usedTokens)}/${_compactTokens(config.tokenBudget)}），'
          '用已完成的 $doneBlocks 块继续成稿');
    }
    if (done.isEmpty) {
      throw Exception('所有块都抽取失败，请检查 API 配置或网络后重试');
    }
    tokensUsed = usedTokens;
    job = job.copyWith(tokensUsed: tokensUsed, failedBlocks: failedIds);
    await store.saveJob(job);

    // ---------------------------------------------------- 5. L2 归并
    setPhase(GenPhase.merging, fraction: .2);
    currentLabel = '归并人物与设定';
    emit(force: true);
    final ordered = plans
        .map((b) => done[b.id])
        .whereType<BlockExtraction>()
        .toList();
    var characters = NovelGenerator.mergeCharacters(ordered);
    final lore = NovelGenerator.mergeLore(ordered);
    log('本地归并：${characters.length} 个人物 · ${lore.length} 条设定');

    // L2.5 人物消歧：让模型把「姓名/称谓/别名」指同一个人的条目合并。
    // 失败时保守地保持原样（宁可重复也不合并错人）。
    if (characters.length >= 2) {
      await waitIfPaused();
      currentLabel = 'AI 人物消歧';
      phaseFraction = .6;
      emit(force: true);
      final before = characters.length;
      try {
        characters = await generator.resolveCharacterAliases(
          characters,
          shouldStop: () => shouldStop,
        );
        if (characters.length != before) {
          log('消歧合并：$before → ${characters.length} 个人物');
        }
      } on NovelStoppedException {
        rethrow;
      } catch (e) {
        log('· 消歧失败（保持本地归并结果）：$e');
      }
      characters.sort((a, b) => b.mentions.compareTo(a.mentions));
    }

    // 剧情梗概：块级 summary 按章节顺序串成一条线，喂给成稿阶段，
    // 让开场白/性格贴合人物经历而不是只有静态设定。
    final plotParts = ordered
        .where((b) => b.summary.trim().isNotEmpty)
        .map((b) => b.summary.trim())
        .toList();
    var plotSummary = plotParts.join('\n');
    if (plotSummary.length > 1600) plotSummary = plotSummary.substring(0, 1600);
    log('剧情梗概 ${plotParts.length} 段'
        '${plotParts.isEmpty ? '' : '（${plotSummary.length} 字）'}');

    final worldSummary = lore
        .take(12)
        .map((l) => '${l.topic}：${l.content}')
        .join('\n');
    phaseFraction = 1;
    emit(force: true);
    await waitIfPaused();

    // ---------------------------------------------------- 6. L3 成稿
    setPhase(GenPhase.composing);
    final cardCount = config.maxCards.clamp(1, 10);
    final targets = characters.take(cardCount).toList();
    final cards = <DraftCard>[];
    for (var i = 0; i < targets.length; i++) {
      await waitIfPaused();
      currentLabel = '生成角色卡：${targets[i].name}';
      phaseFraction = targets.isEmpty ? 1 : i / (targets.length + 1);
      emit(force: true);
      final avatar = i < config.avatarPaths.length ? config.avatarPaths[i] : '';
      final card = await generator.composeCard(
        character: targets[i],
        worldSummary: worldSummary,
        plotSummary: plotSummary,
        extraInstruction: config.extraInstruction,
        avatarPath: avatar,
        shouldStop: () => shouldStop,
      );
      cards.add(card);
      log('✓ 角色卡「${card.name}」');
    }

    await waitIfPaused();
    currentLabel = '生成世界书条目';
    phaseFraction = targets.isEmpty ? .9 : targets.length / (targets.length + 1);
    emit(force: true);
    final entries = await generator.composeLore(
      lore: lore,
      maxEntries: config.maxLoreEntries,
      extraInstruction: config.extraInstruction,
      shouldStop: () => shouldStop,
    );
    log('✓ 世界书 ${entries.length} 条');

    final bookName = _bookName(config.fileName);
    final result = GenResult(
      bookName: bookName,
      cards: cards,
      lore: entries,
      tokensUsed: usedTokens,
      failedBlocks: failedIds,
      scannedBlocks: done.length,
      totalBlocks: totalBlocks,
    );
    await store.saveResult(jobId, result);
    await store.saveJob(job.copyWith(finished: true));

    phase = GenPhase.done;
    phaseFraction = 1;
    state = GenState.done;
    currentLabel = '完成';
    emit(force: true);
    sendPort.send({'type': 'result', 'result': result.toJson()});
    await cleanupTemp();
  }

  /// 清理 docx/pdf 转出的临时 txt 目录（幂等，失败不影响主流程）。
  Future<void> cleanupTemp() async {
    final temp = _tempTextPath;
    _tempTextPath = null;
    if (temp == null) return;
    try {
      final dir = File(temp).parent;
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  /// 扫掉历史遗留的 novel_extract_* 临时目录（当前任务的新目录还没建，全清）。
  Future<void> sweepTempExtracts() async {
    try {
      final tmp = Directory.systemTemp;
      if (!await tmp.exists()) return;
      await for (final entity in tmp.list()) {
        if (entity is! Directory) continue;
        final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (!name.startsWith('novel_extract_')) continue;
        try {
          await entity.delete(recursive: true);
        } catch (_) {}
      }
    } catch (_) {}
  }

  static String _compactTokens(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}k';
    return '$n';
  }

  /// 有限并发池：单 isolate 内 `i++` 不会被打断，安全。
  Future<void> _pool(
    List<_BlockPlan> items,
    int concurrency,
    Future<void> Function(_BlockPlan) task,
  ) async {
    var cursor = 0;
    Future<void> lane() async {
      while (true) {
        if (cancelled) return;
        await waitIfPaused();
        final i = cursor++;
        if (i >= items.length) return;
        await task(items[i]);
      }
    }

    await Future.wait(List.generate(concurrency, (_) => lane()));
  }

  static String _bookName(String fileName) {
    final stem = fileName.replaceAll(RegExp(r'\.[A-Za-z0-9]+$'), '').trim();
    return stem.isEmpty ? '小说世界书' : '$stem · 世界书';
  }
}

class _BlockPlan {
  const _BlockPlan({
    required this.id,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.pieceIndex,
  });

  final String id;
  final int chapterIndex;
  final String chapterTitle;

  /// 该块在本章 splitBlocks 结果里的下标（正文在抽取时按需读取）。
  final int pieceIndex;
}
