import 'dart:convert';
import 'dart:io';

import 'novel_types.dart';

/// 生成任务的断点续跑存储。
///
/// 目录结构（root 由主 isolate 传入，因为后台 isolate 不能用 platform channel）：
/// ```
/// <root>/gen_jobs/<jobId>/job.json        任务配置 + 章节索引 + 选块 + 统计
/// <root>/gen_jobs/<jobId>/blocks/<id>.json 每块抽取结果（checkpoint 最小单位）
/// <root>/gen_jobs/<jobId>/result.json     最终产物
/// ```
/// 每块抽完立刻落盘，App 被杀/崩溃后重进可以接着跑，已完成的块不重复花钱。
class NovelJob {
  const NovelJob({
    required this.id,
    required this.config,
    required this.createdAt,
    this.updatedAt = 0,
    this.index,
    this.stats,
    this.selectedChapters = const [],
    this.totalBlocks = 0,
    this.tokensUsed = 0,
    this.failedBlocks = const [],
    this.finished = false,
  });

  final String id;
  final NovelJobConfig config;
  final int createdAt;
  final int updatedAt;
  final ChapterIndex? index;
  final NovelStats? stats;

  /// 送进 LLM 的章节下标（升序）。
  final List<int> selectedChapters;
  final int totalBlocks;
  final int tokensUsed;
  final List<String> failedBlocks;
  final bool finished;

  NovelJob copyWith({
    ChapterIndex? index,
    NovelStats? stats,
    List<int>? selectedChapters,
    int? totalBlocks,
    int? tokensUsed,
    List<String>? failedBlocks,
    bool? finished,
  }) =>
      NovelJob(
        id: id,
        config: config,
        createdAt: createdAt,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        index: index ?? this.index,
        stats: stats ?? this.stats,
        selectedChapters: selectedChapters ?? this.selectedChapters,
        totalBlocks: totalBlocks ?? this.totalBlocks,
        tokensUsed: tokensUsed ?? this.tokensUsed,
        failedBlocks: failedBlocks ?? this.failedBlocks,
        finished: finished ?? this.finished,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'config': config.toJson(),
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'index': index?.toJson(),
        'stats': stats?.toJson(),
        'selectedChapters': selectedChapters,
        'totalBlocks': totalBlocks,
        'tokensUsed': tokensUsed,
        'failedBlocks': failedBlocks,
        'finished': finished,
      };

  factory NovelJob.fromJson(Map<String, dynamic> j) => NovelJob(
        id: (j['id'] ?? '').toString(),
        config: NovelJobConfig.fromJson(
          j['config'] is Map
              ? Map<String, dynamic>.from(j['config'] as Map)
              : const {},
        ),
        createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
        updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
        index: j['index'] is Map
            ? ChapterIndex.fromJson(Map<String, dynamic>.from(j['index'] as Map))
            : null,
        stats: j['stats'] is Map
            ? NovelStats.fromJson(Map<String, dynamic>.from(j['stats'] as Map))
            : null,
        selectedChapters: (j['selectedChapters'] as List?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            const [],
        totalBlocks: (j['totalBlocks'] as num?)?.toInt() ?? 0,
        tokensUsed: (j['tokensUsed'] as num?)?.toInt() ?? 0,
        failedBlocks: (j['failedBlocks'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        finished: j['finished'] == true,
      );
}

/// 任务列表项（用于「继续上次生成」入口）。
class NovelJobSummary {
  const NovelJobSummary({
    required this.id,
    required this.fileName,
    required this.updatedAt,
    required this.doneBlocks,
    required this.totalBlocks,
    required this.finished,
    required this.hasResult,
  });

  final String id;
  final String fileName;
  final int updatedAt;
  final int doneBlocks;
  final int totalBlocks;
  final bool finished;
  final bool hasResult;

  bool get resumable => !finished && totalBlocks > 0;
}

class NovelJobStore {
  const NovelJobStore(this.rootPath);

  /// 本地存储根目录（`AppStore.storagePath`）。空 = 无本地存储，全部退化为内存。
  final String rootPath;

  bool get available => rootPath.isNotEmpty;

  Directory get _jobsDir => Directory('$rootPath/gen_jobs');

  Directory jobDir(String id) => Directory('${_jobsDir.path}/$id');

  File _jobFile(String id) => File('${jobDir(id).path}/job.json');

  File _resultFile(String id) => File('${jobDir(id).path}/result.json');

  Directory _blocksDir(String id) => Directory('${jobDir(id).path}/blocks');

  /// 新建任务 id（时间戳 + 文件名摘要，便于人眼辨认）。
  static String newJobId(String fileName) {
    final stem = fileName
        .replaceAll(RegExp(r'\.[A-Za-z0-9]+$'), '')
        .replaceAll(RegExp(r'[^\w\u4e00-\u9fff-]'), '')
        .trim();
    final short = stem.isEmpty
        ? 'novel'
        : stem.substring(0, stem.length > 12 ? 12 : stem.length);
    return '${DateTime.now().millisecondsSinceEpoch}-$short';
  }

  Future<void> saveJob(NovelJob job) async {
    if (!available) return;
    try {
      final dir = jobDir(job.id);
      if (!await dir.exists()) await dir.create(recursive: true);
      await _jobFile(job.id).writeAsString(jsonEncode(job.toJson()), flush: true);
    } catch (_) {
      // checkpoint 失败不该中断生成，最坏情况是这块下次重跑。
    }
  }

  Future<NovelJob?> loadJob(String id) async {
    if (!available) return null;
    try {
      final file = _jobFile(id);
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      return NovelJob.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveBlock(String jobId, BlockExtraction block) async {
    if (!available) return;
    try {
      final dir = _blocksDir(jobId);
      if (!await dir.exists()) await dir.create(recursive: true);
      // blockId 可能含路径不安全字符，统一净化。
      final safe = block.blockId.replaceAll(RegExp(r'[^\w-]'), '_');
      await File('${dir.path}/$safe.json')
          .writeAsString(jsonEncode(block.toJson()), flush: true);
    } catch (_) {}
  }

  Future<Map<String, BlockExtraction>> loadBlocks(String jobId) async {
    final out = <String, BlockExtraction>{};
    if (!available) return out;
    try {
      final dir = _blocksDir(jobId);
      if (!await dir.exists()) return out;
      await for (final entity in dir.list()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        try {
          final decoded = jsonDecode(await entity.readAsString());
          if (decoded is! Map) continue;
          final block =
              BlockExtraction.fromJson(Map<String, dynamic>.from(decoded));
          if (block.blockId.isNotEmpty) out[block.blockId] = block;
        } catch (_) {
          // 单块损坏就当作没跑过，重跑该块。
        }
      }
    } catch (_) {}
    return out;
  }

  Future<void> saveResult(String jobId, GenResult result) async {
    if (!available) return;
    try {
      await _resultFile(jobId)
          .writeAsString(jsonEncode(result.toJson()), flush: true);
    } catch (_) {}
  }

  Future<GenResult?> loadResult(String jobId) async {
    if (!available) return null;
    try {
      final file = _resultFile(jobId);
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      return GenResult.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<List<NovelJobSummary>> listJobs() async {
    final out = <NovelJobSummary>[];
    if (!available) return out;
    try {
      if (!await _jobsDir.exists()) return out;
      await for (final entity in _jobsDir.list()) {
        if (entity is! Directory) continue;
        final id = entity.uri.pathSegments
            .where((s) => s.isNotEmpty)
            .last;
        final job = await loadJob(id);
        if (job == null) continue;
        final blocks = await loadBlocks(id);
        out.add(NovelJobSummary(
          id: id,
          fileName: job.config.fileName,
          updatedAt: job.updatedAt == 0 ? job.createdAt : job.updatedAt,
          doneBlocks: blocks.length,
          totalBlocks: job.totalBlocks,
          finished: job.finished,
          hasResult: await _resultFile(id).exists(),
        ));
      }
      out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (_) {}
    return out;
  }

  Future<void> deleteJob(String id) async {
    if (!available) return;
    try {
      final dir = jobDir(id);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}
