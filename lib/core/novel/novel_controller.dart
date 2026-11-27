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
  Future<void> resumeJob(String id) async {
    if (busy) return;
    final root = AppStore.instance.storagePath ?? '';
    final job = await NovelJobStore(root).loadJob(id);
    if (job == null) return;
    await _spawn(
      rootPath: root,
      jobId: id,
      config: job.config,
      resume: true,
    );
  }

  Future<void> _spawn({
    required String rootPath,
    required String jobId,
    required NovelJobConfig config,
    required bool resume,
  }) async {
    _jobId = jobId;
    _fileName = config.fileName;
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
