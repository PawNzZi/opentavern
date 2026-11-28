import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../store.dart';
import 'job_store.dart';
import 'novel_types.dart';
import 'worker.dart';

/// 小说生成任务的主 isolate 控制器（单例）。
///
/// 单例是刻意的：用户离开进度页去逛角色库时任务要继续跑，回来还能看到进度。
/// 重活全在 worker isolate，这里只收消息 + 通知 UI，所以界面不掉帧。
class NovelGenController extends ChangeNotifier {
  NovelGenController._();

  static final NovelGenController instance = NovelGenController._();

  GenProgress _progress = const GenProgress();
  GenProgress get progress => _progress;

  GenResult? _result;
  GenResult? get result => _result;

  String? _jobId;
  String? get jobId => _jobId;

  String _fileName = '';
  String get fileName => _fileName;

  /// 当前/最近一次任务的实际配置（进度面板显示预算等用）。
  NovelJobConfig? _runningConfig;
  NovelJobConfig? get runningConfig => _runningConfig;

  Isolate? _isolate;
  ReceivePort? _port;
  SendPort? _control;

  bool get busy =>
      _progress.state == GenState.running ||
      _progress.state == GenState.paused ||
      _progress.state == GenState.cancelling;

  bool get hasResult => _result != null;

  /// 任务列表（「继续上次生成」用）。
  Future<List<NovelJobSummary>> jobs() async {
    final root = AppStore.instance.storagePath ?? '';
    return NovelJobStore(root).listJobs();
  }

  Future<void> deleteJob(String id) async {
    final root = AppStore.instance.storagePath ?? '';
    await NovelJobStore(root).deleteJob(id);
    notifyListeners();
  }

  /// 开新任务。
  Future<void> start(NovelJobConfig config) async {
    if (busy) return;
    final root = AppStore.instance.storagePath ?? '';
    final id = NovelJobStore.newJobId(config.fileName);
    final job = NovelJob(
      id: id,
      config: config,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await NovelJobStore(root).saveJob(job);
    await _spawn(rootPath: root, jobId: id, config: config, resume: false);
  }

  /// 续跑上次任务（已完成的块不重复花钱）。
  ///
  /// [retryFinished]：任务已结束但有失败块时也允许重进管道——
  /// 缓存的块全部命中，只有失败块会真正重跑，然后重新归并成稿。
  /// [overrides]：用配置页当前填写的运行时参数（服务商/模型/并发/预算/
  /// 立绘/附加要求等）覆盖旧任务；文件、扫描模式与块选择仍沿用原任务，
  /// 保证已花的钱不作废。若编码被改动，旧的块坐标失效，会清掉块缓存重建。
  Future<void> resumeJob(
    String id, {
    bool retryFinished = false,
    NovelJobConfig? overrides,
  }) async {
    if (busy) return;
    final root = AppStore.instance.storagePath ?? '';
    final store = NovelJobStore(root);
    var job = await store.loadJob(id);
    if (job == null) return;
    if (job.finished && !retryFinished) return;

    if (overrides != null) {
      final old = job.config;
      final merged = NovelJobConfig(
        // 与文件切章相关的沿用原任务
        filePath: old.filePath,
        fileName: old.fileName,
        scanMode: old.scanMode,
        maxBlocks: old.maxBlocks,
        headChapters: old.headChapters,
        blockChars: old.blockChars,
        // 运行时参数取新表单
        maxLoreEntries: overrides.maxLoreEntries,
        concurrency: overrides.concurrency,
        providerOverride: overrides.providerOverride,
        modelOverride: overrides.modelOverride,
        avatarPaths: overrides.avatarPaths,
        extraInstruction: overrides.extraInstruction,
        tokenBudget: overrides.tokenBudget,
        encodingOverride: overrides.encodingOverride,
        cardCharacter: overrides.cardCharacter,
        cardUser: overrides.cardUser,
        cardUserDescription: overrides.cardUserDescription,
        detail: overrides.detail,
        supportingLimit: overrides.supportingLimit,
      );
      final encodingChanged =
          merged.encodingOverride != old.encodingOverride;
      if (encodingChanged) {
        // 换编码 = 章节坐标全变，旧块与旧索引都不能再用。
        await store.clearBlocks(id);
        job = novelCopyWithoutIndex(job, merged);
      } else {
        job = job.copyWith(config: merged, finished: false);
      }
      await store.saveJob(job);
    }

    await _spawn(
      rootPath: root,
      jobId: id,
      config: job.config,
      resume: true,
    );
  }

  /// 构造一个丢掉章节索引/统计/块选择的任务（换编码后重建用）。
  NovelJob novelCopyWithoutIndex(NovelJob job, NovelJobConfig config) => NovelJob(
        id: job.id,
        config: config,
        createdAt: job.createdAt,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        selectedChapters: const [],
        totalBlocks: 0,
        tokensUsed: job.tokensUsed,
        failedBlocks: const [],
        finished: false,
      );

  /// 打开已完成任务的结果（纯本地读 result.json，不 spawn、不花 token）。
  /// 返回 false = 该任务没有可回看的结果。
  Future<bool> openJob(String id) async {
    if (busy) return false;
    final root = AppStore.instance.storagePath ?? '';
    final store = NovelJobStore(root);
    final job = await store.loadJob(id);
    if (job == null) return false;
    final result = await store.loadResult(id);
    if (result == null) return false;
    _jobId = id;
    _fileName = job.config.fileName;
    _runningConfig = job.config;
    _result = result;
    _progress = const GenProgress(state: GenState.done, phase: GenPhase.done);
    notifyListeners();
    return true;
  }

  Future<void> _spawn({
    required String rootPath,
    required String jobId,
    required NovelJobConfig config,
    required bool resume,
  }) async {
    _jobId = jobId;
    _fileName = config.fileName;
    _runningConfig = config;
    _result = null;
    _progress = GenProgress(
      state: GenState.running,
      phase: GenPhase.indexing,
      currentLabel: resume ? '续跑上次任务…' : '启动后台任务…',
    );
    notifyListeners();

    // 生成期间防锁屏：iOS 退后台会挂起，前台保活 + 断点续跑是本地单机的上限。
    try {
      await WakelockPlus.enable();
    } catch (_) {}

    final base = AppStore.instance.settings;
    final api = AppStore.instance.apiForProvider(
      config.providerOverride,
      model: config.modelOverride,
    );
    final settings = base.copyWith(api: api);

    final port = ReceivePort();
    _port = port;
    port.listen(_onMessage);

    try {
      _isolate = await Isolate.spawn(
        novelWorkerMain,
        NovelWorkerArgs(
          sendPort: port.sendPort,
          rootPath: rootPath,
          jobId: jobId,
          configJson: config.toJson(),
          settingsJson: settings.toJson(),
          resume: resume,
        ).toMessage(),
        debugName: 'novel-gen',
      );
    } catch (e) {
      _progress = _progress.copyWith(
        state: GenState.error,
        error: '无法启动后台任务：$e',
      );
      await _teardown();
      notifyListeners();
    }
  }

  void _onMessage(dynamic message) {
    if (message is! Map) return;
    switch (message['type']) {
      case 'control':
        _control = message['port'] as SendPort?;
      case 'progress':
        final raw = message['progress'];
        if (raw is Map) {
          _progress = GenProgress.fromJson(Map<String, dynamic>.from(raw));
          notifyListeners();
        }
      case 'result':
        final raw = message['result'];
        if (raw is Map) {
          _result = GenResult.fromJson(Map<String, dynamic>.from(raw));
        }
        _progress = _progress.copyWith(state: GenState.done, phaseFraction: 1);
        notifyListeners();
        _teardown();
      case 'error':
        _progress = _progress.copyWith(
          state: GenState.error,
          error: (message['message'] ?? '生成失败').toString(),
        );
        notifyListeners();
        _teardown();
    }
    // worker 自己报告的终态（取消/错误）也要收尾。
    if (_progress.state == GenState.cancelled ||
        _progress.state == GenState.error) {
      _teardown();
    }
  }

  void pause() {
    if (_progress.state != GenState.running) return;
    _control?.send('pause');
    _progress = _progress.copyWith(state: GenState.paused);
    notifyListeners();
  }

  void resume() {
    if (_progress.state != GenState.paused) return;
    _control?.send('resume');
    _progress = _progress.copyWith(state: GenState.running);
    notifyListeners();
  }

  void cancel() {
    if (!busy) return;
    _control?.send('cancel');
    _progress = _progress.copyWith(state: GenState.cancelling);
    notifyListeners();
    // 兜底：worker 若卡在长请求里，2 秒后强杀，已完成的块已落盘不会丢。
    Timer(const Duration(seconds: 2), () {
      if (_isolate != null) {
        _progress = _progress.copyWith(state: GenState.cancelled);
        notifyListeners();
        _teardown();
      }
    });
  }

  /// 清空当前结果（用户保存完或主动放弃）。
  void clear() {
    if (busy) return;
    _result = null;
    _jobId = null;
    _fileName = '';
    _runningConfig = null;
    _progress = const GenProgress();
    notifyListeners();
  }

  Future<void> _teardown() async {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _port?.close();
    _port = null;
    _control = null;
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }

  /// 预览页编辑后回写结果（勾选/改字段）。
  void updateResult(GenResult next) {
    _result = next;
    notifyListeners();
  }
}
