/// 「小说/文档 → 角色卡 + 世界书」的共享数据契约。
///
/// 这些类型同时用于三处，必须保持可 JSON 序列化（isolate 之间只传 JSON 安全值）：
///  * worker isolate 与主 isolate 之间的进度/结果消息；
///  * 断点续跑的 checkpoint 落盘；
///  * UI 预览与编辑。
library;

/// 文本编码。中文小说大量是 GBK/GB18030，必须支持，否则整本乱码。
enum NovelEncoding { utf8, utf16le, utf16be, gb18030, latin1 }

extension NovelEncodingLabel on NovelEncoding {
  String get label => switch (this) {
        NovelEncoding.utf8 => 'UTF-8',
        NovelEncoding.utf16le => 'UTF-16 LE',
        NovelEncoding.utf16be => 'UTF-16 BE',
        NovelEncoding.gb18030 => 'GBK / GB18030',
        NovelEncoding.latin1 => 'Latin-1',
      };

  /// UTF-16 的字节偏移必须按 2 字节对齐。
  bool get isWide =>
      this == NovelEncoding.utf16le || this == NovelEncoding.utf16be;
}

/// 一章在**原文件**中的位置。只存偏移与长度，绝不把全文留在内存里。
class ChapterRef {
  const ChapterRef({
    required this.index,
    required this.title,
    required this.byteOffset,
    required this.byteLength,
    required this.charCount,
  });

  final int index;
  final String title;
  final int byteOffset;
  final int byteLength;

  /// 估算字数（用于切块与采样权重，不是精确值）。
  final int charCount;

  Map<String, dynamic> toJson() => {
        'index': index,
        'title': title,
        'byteOffset': byteOffset,
        'byteLength': byteLength,
        'charCount': charCount,
      };

  factory ChapterRef.fromJson(Map<String, dynamic> j) => ChapterRef(
        index: (j['index'] as num?)?.toInt() ?? 0,
        title: (j['title'] ?? '').toString(),
        byteOffset: (j['byteOffset'] as num?)?.toInt() ?? 0,
        byteLength: (j['byteLength'] as num?)?.toInt() ?? 0,
        charCount: (j['charCount'] as num?)?.toInt() ?? 0,
      );
}

/// 全书章节索引 + 文件指纹。指纹用于判断「上次那个任务还是这个文件吗」。
class ChapterIndex {
  const ChapterIndex({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.modifiedMs,
    required this.encoding,
    required this.chapters,
    required this.totalChars,
  });

  final String filePath;
  final String fileName;
  final int fileSize;
  final int modifiedMs;
  final NovelEncoding encoding;
  final List<ChapterRef> chapters;
  final int totalChars;

  /// size + mtime 组合指纹：文件被换掉/改过就不能续跑旧结果。
  String get fingerprint => '$fileSize-$modifiedMs';

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'fileName': fileName,
        'fileSize': fileSize,
        'modifiedMs': modifiedMs,
        'encoding': encoding.name,
        'chapters': chapters.map((c) => c.toJson()).toList(),
        'totalChars': totalChars,
      };

  factory ChapterIndex.fromJson(Map<String, dynamic> j) => ChapterIndex(
        filePath: (j['filePath'] ?? '').toString(),
        fileName: (j['fileName'] ?? '').toString(),
        fileSize: (j['fileSize'] as num?)?.toInt() ?? 0,
        modifiedMs: (j['modifiedMs'] as num?)?.toInt() ?? 0,
        encoding: NovelEncoding.values.firstWhere(
          (e) => e.name == j['encoding'],
          orElse: () => NovelEncoding.utf8,
        ),
        chapters: (j['chapters'] as List?)
                ?.whereType<Map>()
                .map((e) => ChapterRef.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
        totalChars: (j['totalChars'] as num?)?.toInt() ?? 0,
      );
}

/// 本地全量扫描的统计结果（零 API 调用）。
class NovelStats {
  const NovelStats({
    this.nameCandidates = const {},
    this.termCandidates = const {},
    this.chapterCharCounts = const [],
    this.chapterNameHits = const {},
  });

  /// 人名/称谓候选 → 出现次数。
  final Map<String, int> nameCandidates;

  /// 地名/组织/物品等专有名词候选 → 出现次数。
  final Map<String, int> termCandidates;

  /// 每章字数，下标与 [ChapterRef.index] 对齐。
  final List<int> chapterCharCounts;

  /// 每章命中的人名候选次数之和，用于「戏份密度」采样权重。
  final Map<int, int> chapterNameHits;

  Map<String, dynamic> toJson() => {
        'nameCandidates': nameCandidates,
        'termCandidates': termCandidates,
        'chapterCharCounts': chapterCharCounts,
        'chapterNameHits':
            chapterNameHits.map((k, v) => MapEntry(k.toString(), v)),
      };

  factory NovelStats.fromJson(Map<String, dynamic> j) => NovelStats(
        nameCandidates: _intMap(j['nameCandidates']),
        termCandidates: _intMap(j['termCandidates']),
        chapterCharCounts: (j['chapterCharCounts'] as List?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            const [],
        chapterNameHits: _intMap(j['chapterNameHits'])
            .map((k, v) => MapEntry(int.tryParse(k) ?? 0, v)),
      );

  static Map<String, int> _intMap(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <String, int>{};
    raw.forEach((k, v) {
      if (v is num) out[k.toString()] = v.toInt();
    });
    return out;
  }
}

/// 扫描模式。几百 MB 全书精读要 20+ 小时，所以默认智能采样。
enum ScanMode {
  /// 首尾加权 + 均匀覆盖 + 戏份密度优先，块数上限可控（默认）。
  smart,

  /// 所有块都过 LLM：最完整，但极慢极贵，UI 需二次确认。
  full,

  /// 只读开头 N 章，最快试水。
  headOnly,
}

/// 一次生成任务的配置。
class NovelJobConfig {
  const NovelJobConfig({
    required this.filePath,
    required this.fileName,
    this.scanMode = ScanMode.smart,
    this.maxBlocks = 120,
    this.headChapters = 20,
    this.maxCards = 3,
    this.maxLoreEntries = 40,
    this.concurrency = 2,
    this.blockChars = 6000,
    this.providerOverride = '',
    this.modelOverride = '',
    this.avatarPaths = const [],
    this.extraInstruction = '',
    this.tokenBudget = 0,
    this.encodingOverride = '',
  });

  final String filePath;
  final String fileName;
  final ScanMode scanMode;

  /// smart 模式下送入 LLM 的块数上限。
  final int maxBlocks;

  /// headOnly 模式读多少章。
  final int headChapters;
  final int maxCards;
  final int maxLoreEntries;

  /// LLM 并发数（1~4）。
  final int concurrency;

  /// 单块目标字数（按模型上下文换算，中文约 1 字 ≈ 1.2 token）。
  final int blockChars;

  /// 空 = 跟随全局服务商。
  final String providerOverride;
  final String modelOverride;

  /// 用户上传的立绘（本地路径），按顺序分配给生成的角色卡。
  final List<String> avatarPaths;

  /// 用户附加要求（例如「只生成女性角色」）。
  final String extraInstruction;

  /// token 预算上限，0 = 不限。达到上限后停止抽取，用已有结果成稿。
  final int tokenBudget;

  /// 手动指定编码（[NovelEncoding].name），空 = 自动探测。
  /// 极短中文 GBK 文件的自动探测是启发式，给用户一个确定性的兜底。
  final String encodingOverride;

  NovelJobConfig copyWith({
    ScanMode? scanMode,
    int? maxBlocks,
    int? headChapters,
    int? maxCards,
    int? maxLoreEntries,
    int? concurrency,
    int? blockChars,
    String? providerOverride,
    String? modelOverride,
    List<String>? avatarPaths,
    String? extraInstruction,
    int? tokenBudget,
    String? encodingOverride,
  }) =>
      NovelJobConfig(
        filePath: filePath,
        fileName: fileName,
        scanMode: scanMode ?? this.scanMode,
        maxBlocks: maxBlocks ?? this.maxBlocks,
        headChapters: headChapters ?? this.headChapters,
        maxCards: maxCards ?? this.maxCards,
        maxLoreEntries: maxLoreEntries ?? this.maxLoreEntries,
        concurrency: concurrency ?? this.concurrency,
        blockChars: blockChars ?? this.blockChars,
        providerOverride: providerOverride ?? this.providerOverride,
        modelOverride: modelOverride ?? this.modelOverride,
        avatarPaths: avatarPaths ?? this.avatarPaths,
        extraInstruction: extraInstruction ?? this.extraInstruction,
        tokenBudget: tokenBudget ?? this.tokenBudget,
        encodingOverride: encodingOverride ?? this.encodingOverride,
      );

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'fileName': fileName,
        'scanMode': scanMode.name,
        'maxBlocks': maxBlocks,
        'headChapters': headChapters,
        'maxCards': maxCards,
        'maxLoreEntries': maxLoreEntries,
        'concurrency': concurrency,
        'blockChars': blockChars,
        'providerOverride': providerOverride,
        'modelOverride': modelOverride,
        'avatarPaths': avatarPaths,
        'extraInstruction': extraInstruction,
        'tokenBudget': tokenBudget,
        'encodingOverride': encodingOverride,
      };

  factory NovelJobConfig.fromJson(Map<String, dynamic> j) => NovelJobConfig(
        filePath: (j['filePath'] ?? '').toString(),
        fileName: (j['fileName'] ?? '').toString(),
        scanMode: ScanMode.values.firstWhere(
          (e) => e.name == j['scanMode'],
          orElse: () => ScanMode.smart,
        ),
        maxBlocks: (j['maxBlocks'] as num?)?.toInt() ?? 120,
        headChapters: (j['headChapters'] as num?)?.toInt() ?? 20,
        maxCards: (j['maxCards'] as num?)?.toInt() ?? 3,
        maxLoreEntries: (j['maxLoreEntries'] as num?)?.toInt() ?? 40,
        concurrency: (j['concurrency'] as num?)?.toInt() ?? 2,
        blockChars: (j['blockChars'] as num?)?.toInt() ?? 6000,
        providerOverride: (j['providerOverride'] ?? '').toString(),
        modelOverride: (j['modelOverride'] ?? '').toString(),
        avatarPaths: (j['avatarPaths'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        extraInstruction: (j['extraInstruction'] ?? '').toString(),
        tokenBudget: (j['tokenBudget'] as num?)?.toInt() ?? 0,
        encodingOverride: (j['encodingOverride'] ?? '').toString(),
      );
}

/// L1 从单块里抽到的一个人物。
class ExtractedCharacter {
  const ExtractedCharacter({
    required this.name,
    this.aliases = const [],
    this.appearance = '',
    this.personality = '',
    this.relationship = '',
    this.speechStyle = '',
    this.role = '',
  });

  final String name;
  final List<String> aliases;
  final String appearance;
  final String personality;
  final String relationship;
  final String speechStyle;

  /// 主角/配角/反派等。
  final String role;

  Map<String, dynamic> toJson() => {
        'name': name,
        'aliases': aliases,
        'appearance': appearance,
        'personality': personality,
        'relationship': relationship,
        'speechStyle': speechStyle,
        'role': role,
      };

  factory ExtractedCharacter.fromJson(Map<String, dynamic> j) =>
      ExtractedCharacter(
        name: (j['name'] ?? '').toString().trim(),
        aliases: _strList(j['aliases']),
        appearance: (j['appearance'] ?? '').toString(),
        personality: (j['personality'] ?? '').toString(),
        relationship: (j['relationship'] ?? '').toString(),
        speechStyle: (j['speechStyle'] ?? '').toString(),
        role: (j['role'] ?? '').toString(),
      );
}

/// L1 从单块里抽到的一条世界设定。
class ExtractedLore {
  const ExtractedLore({
    required this.topic,
    this.keys = const [],
    this.content = '',
    this.category = '',
    this.constant = false,
  });

  final String topic;
  final List<String> keys;
  final String content;

  /// 地点/组织/物品/规则/时间线。
  final String category;

  /// 是否为世界观常驻条目。
  final bool constant;

  Map<String, dynamic> toJson() => {
        'topic': topic,
        'keys': keys,
        'content': content,
        'category': category,
        'constant': constant,
      };

  factory ExtractedLore.fromJson(Map<String, dynamic> j) => ExtractedLore(
        topic: (j['topic'] ?? '').toString().trim(),
        keys: _strList(j['keys']),
        content: (j['content'] ?? '').toString(),
        category: (j['category'] ?? '').toString(),
        constant: j['constant'] == true,
      );
}

/// 一个块（一章或章内切片）的抽取结果，也是 checkpoint 的最小单位。
class BlockExtraction {
  const BlockExtraction({
    required this.blockId,
    required this.chapterIndex,
    required this.chapterTitle,
    this.characters = const [],
    this.lore = const [],
    this.summary = '',
    this.tokensUsed = 0,
  });

  /// 形如 `c12-p0`（第 12 章第 0 片）。
  final String blockId;
  final int chapterIndex;
  final String chapterTitle;
  final List<ExtractedCharacter> characters;
  final List<ExtractedLore> lore;
  final String summary;
  final int tokensUsed;

  Map<String, dynamic> toJson() => {
        'blockId': blockId,
        'chapterIndex': chapterIndex,
        'chapterTitle': chapterTitle,
        'characters': characters.map((c) => c.toJson()).toList(),
        'lore': lore.map((l) => l.toJson()).toList(),
        'summary': summary,
        'tokensUsed': tokensUsed,
      };

  factory BlockExtraction.fromJson(Map<String, dynamic> j) => BlockExtraction(
        blockId: (j['blockId'] ?? '').toString(),
        chapterIndex: (j['chapterIndex'] as num?)?.toInt() ?? 0,
        chapterTitle: (j['chapterTitle'] ?? '').toString(),
        characters: (j['characters'] as List?)
                ?.whereType<Map>()
                .map((e) =>
                    ExtractedCharacter.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
        lore: (j['lore'] as List?)
                ?.whereType<Map>()
                .map((e) => ExtractedLore.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
        summary: (j['summary'] ?? '').toString(),
        tokensUsed: (j['tokensUsed'] as num?)?.toInt() ?? 0,
      );
}

/// L3 成稿：一张待入库的角色卡草稿（字段与 DemoCharacter 对齐）。
class DraftCard {
  const DraftCard({
    required this.name,
    this.description = '',
    this.personality = '',
    this.scenario = '',
    this.firstMes = '',
    this.mesExample = '',
    this.alternateGreetings = const [],
    this.systemPrompt = '',
    this.creatorNotes = '',
    this.tags = const [],
    this.avatarPath = '',
    this.selected = true,
  });

  final String name;
  final String description;
  final String personality;
  final String scenario;
  final String firstMes;
  final String mesExample;
  final List<String> alternateGreetings;
  final String systemPrompt;
  final String creatorNotes;
  final List<String> tags;

  /// 分配到的立绘本地路径（空 = 用渐变占位图）。
  final String avatarPath;

  /// 预览页勾选状态。
  final bool selected;

  DraftCard copyWith({
    String? name,
    String? description,
    String? personality,
    String? scenario,
    String? firstMes,
    String? mesExample,
    List<String>? alternateGreetings,
    String? systemPrompt,
    String? creatorNotes,
    List<String>? tags,
    String? avatarPath,
    bool? selected,
  }) =>
      DraftCard(
        name: name ?? this.name,
        description: description ?? this.description,
        personality: personality ?? this.personality,
        scenario: scenario ?? this.scenario,
        firstMes: firstMes ?? this.firstMes,
        mesExample: mesExample ?? this.mesExample,
        alternateGreetings: alternateGreetings ?? this.alternateGreetings,
        systemPrompt: systemPrompt ?? this.systemPrompt,
        creatorNotes: creatorNotes ?? this.creatorNotes,
        tags: tags ?? this.tags,
        avatarPath: avatarPath ?? this.avatarPath,
        selected: selected ?? this.selected,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'personality': personality,
        'scenario': scenario,
        'firstMes': firstMes,
        'mesExample': mesExample,
        'alternateGreetings': alternateGreetings,
        'systemPrompt': systemPrompt,
        'creatorNotes': creatorNotes,
        'tags': tags,
        'avatarPath': avatarPath,
        'selected': selected,
      };

  factory DraftCard.fromJson(Map<String, dynamic> j) => DraftCard(
        name: (j['name'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        personality: (j['personality'] ?? '').toString(),
        scenario: (j['scenario'] ?? '').toString(),
        firstMes: (j['firstMes'] ?? '').toString(),
        mesExample: (j['mesExample'] ?? '').toString(),
        alternateGreetings: _strList(j['alternateGreetings']),
        systemPrompt: (j['systemPrompt'] ?? '').toString(),
        creatorNotes: (j['creatorNotes'] ?? '').toString(),
        tags: _strList(j['tags']),
        avatarPath: (j['avatarPath'] ?? '').toString(),
        selected: j['selected'] != false,
      );
}

/// L3 成稿：一条待入库的世界书条目草稿（字段与 LoreEntry 对齐）。
class DraftLoreEntry {
  const DraftLoreEntry({
    required this.name,
    this.keys = const [],
    this.secondaryKeys = const [],
    this.content = '',
    this.constant = false,
    this.order = 100,
    this.position = 'before',
    this.depth = 4,
    this.selected = true,
  });

  final String name;
  final List<String> keys;
  final List<String> secondaryKeys;
  final String content;
  final bool constant;
  final int order;
  final String position;
  final int depth;
  final bool selected;

  DraftLoreEntry copyWith({
    String? name,
    List<String>? keys,
    List<String>? secondaryKeys,
    String? content,
    bool? constant,
    int? order,
    String? position,
    int? depth,
    bool? selected,
  }) =>
      DraftLoreEntry(
        name: name ?? this.name,
        keys: keys ?? this.keys,
        secondaryKeys: secondaryKeys ?? this.secondaryKeys,
        content: content ?? this.content,
        constant: constant ?? this.constant,
        order: order ?? this.order,
        position: position ?? this.position,
        depth: depth ?? this.depth,
        selected: selected ?? this.selected,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'keys': keys,
        'secondaryKeys': secondaryKeys,
        'content': content,
        'constant': constant,
        'order': order,
        'position': position,
        'depth': depth,
        'selected': selected,
      };

  factory DraftLoreEntry.fromJson(Map<String, dynamic> j) => DraftLoreEntry(
        name: (j['name'] ?? '').toString(),
        keys: _strList(j['keys']),
        secondaryKeys: _strList(j['secondaryKeys']),
        content: (j['content'] ?? '').toString(),
        constant: j['constant'] == true,
        order: (j['order'] as num?)?.toInt() ?? 100,
        position: (j['position'] ?? 'before').toString(),
        depth: (j['depth'] as num?)?.toInt() ?? 4,
        selected: j['selected'] != false,
      );
}

/// 最终产物。
class GenResult {
  const GenResult({
    this.bookName = '',
    this.cards = const [],
    this.lore = const [],
    this.tokensUsed = 0,
    this.failedBlocks = const [],
    this.scannedBlocks = 0,
    this.totalBlocks = 0,
  });

  final String bookName;
  final List<DraftCard> cards;
  final List<DraftLoreEntry> lore;
  final int tokensUsed;
  final List<String> failedBlocks;
  final int scannedBlocks;
  final int totalBlocks;

  Map<String, dynamic> toJson() => {
        'bookName': bookName,
        'cards': cards.map((c) => c.toJson()).toList(),
        'lore': lore.map((l) => l.toJson()).toList(),
        'tokensUsed': tokensUsed,
        'failedBlocks': failedBlocks,
        'scannedBlocks': scannedBlocks,
        'totalBlocks': totalBlocks,
      };

  factory GenResult.fromJson(Map<String, dynamic> j) => GenResult(
        bookName: (j['bookName'] ?? '').toString(),
        cards: (j['cards'] as List?)
                ?.whereType<Map>()
                .map((e) => DraftCard.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
        lore: (j['lore'] as List?)
                ?.whereType<Map>()
                .map((e) => DraftLoreEntry.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
        tokensUsed: (j['tokensUsed'] as num?)?.toInt() ?? 0,
        failedBlocks: _strList(j['failedBlocks']),
        scannedBlocks: (j['scannedBlocks'] as num?)?.toInt() ?? 0,
        totalBlocks: (j['totalBlocks'] as num?)?.toInt() ?? 0,
      );
}

/// 生成阶段。百分比按阶段权重推进，见 `GenProgress.phaseWeight`。
enum GenPhase { indexing, scanning, extracting, merging, composing, done }

extension GenPhaseInfo on GenPhase {
  String get label => switch (this) {
        GenPhase.indexing => '读取并切章',
        GenPhase.scanning => '本地统计词频',
        GenPhase.extracting => 'AI 抽取设定',
        GenPhase.merging => '归并去重',
        GenPhase.composing => '生成卡与世界书',
        GenPhase.done => '已完成',
      };

  /// 各阶段占总进度的权重（合计 100）。
  int get weight => switch (this) {
        GenPhase.indexing => 5,
        GenPhase.scanning => 5,
        GenPhase.extracting => 70,
        GenPhase.merging => 8,
        GenPhase.composing => 12,
        GenPhase.done => 0,
      };
}

enum GenState { idle, running, paused, cancelling, done, error, cancelled }

/// 进度快照。isolate → 主 isolate 只传这个（JSON 安全）。
class GenProgress {
  const GenProgress({
    this.state = GenState.idle,
    this.phase = GenPhase.indexing,
    this.phaseFraction = 0,
    this.doneBlocks = 0,
    this.totalBlocks = 0,
    this.tokensUsed = 0,
    this.elapsedMs = 0,
    this.etaMs = 0,
    this.currentLabel = '',
    this.failedBlocks = 0,
    this.logs = const [],
    this.error = '',
  });

  final GenState state;
  final GenPhase phase;

  /// 当前阶段内部完成度 0..1。
  final double phaseFraction;
  final int doneBlocks;
  final int totalBlocks;
  final int tokensUsed;
  final int elapsedMs;
  final int etaMs;
  final String currentLabel;
  final int failedBlocks;

  /// 最近的日志行（最多保留 200 条）。
  final List<String> logs;
  final String error;

  /// 真实总百分比 0..100：已完成阶段权重 + 当前阶段权重 × 阶段内完成度。
  double get percent {
    if (state == GenState.done) return 100;
    var acc = 0;
    for (final p in GenPhase.values) {
      if (p.index >= phase.index) break;
      acc += p.weight;
    }
    final f = phaseFraction.clamp(0.0, 1.0);
    return (acc + phase.weight * f).clamp(0.0, 100.0);
  }

  GenProgress copyWith({
    GenState? state,
    GenPhase? phase,
    double? phaseFraction,
    int? doneBlocks,
    int? totalBlocks,
    int? tokensUsed,
    int? elapsedMs,
    int? etaMs,
    String? currentLabel,
    int? failedBlocks,
    List<String>? logs,
    String? error,
  }) =>
      GenProgress(
        state: state ?? this.state,
        phase: phase ?? this.phase,
        phaseFraction: phaseFraction ?? this.phaseFraction,
        doneBlocks: doneBlocks ?? this.doneBlocks,
        totalBlocks: totalBlocks ?? this.totalBlocks,
        tokensUsed: tokensUsed ?? this.tokensUsed,
        elapsedMs: elapsedMs ?? this.elapsedMs,
        etaMs: etaMs ?? this.etaMs,
        currentLabel: currentLabel ?? this.currentLabel,
        failedBlocks: failedBlocks ?? this.failedBlocks,
        logs: logs ?? this.logs,
        error: error ?? this.error,
      );

  Map<String, dynamic> toJson() => {
        'state': state.name,
        'phase': phase.name,
        'phaseFraction': phaseFraction,
        'doneBlocks': doneBlocks,
        'totalBlocks': totalBlocks,
        'tokensUsed': tokensUsed,
        'elapsedMs': elapsedMs,
        'etaMs': etaMs,
        'currentLabel': currentLabel,
        'failedBlocks': failedBlocks,
        'logs': logs,
        'error': error,
      };

  factory GenProgress.fromJson(Map<String, dynamic> j) => GenProgress(
        state: GenState.values.firstWhere(
          (e) => e.name == j['state'],
          orElse: () => GenState.idle,
        ),
        phase: GenPhase.values.firstWhere(
          (e) => e.name == j['phase'],
          orElse: () => GenPhase.indexing,
        ),
        phaseFraction: (j['phaseFraction'] as num?)?.toDouble() ?? 0,
        doneBlocks: (j['doneBlocks'] as num?)?.toInt() ?? 0,
        totalBlocks: (j['totalBlocks'] as num?)?.toInt() ?? 0,
        tokensUsed: (j['tokensUsed'] as num?)?.toInt() ?? 0,
        elapsedMs: (j['elapsedMs'] as num?)?.toInt() ?? 0,
        etaMs: (j['etaMs'] as num?)?.toInt() ?? 0,
        currentLabel: (j['currentLabel'] ?? '').toString(),
        failedBlocks: (j['failedBlocks'] as num?)?.toInt() ?? 0,
        logs: _strList(j['logs']),
        error: (j['error'] ?? '').toString(),
      );
}

List<String> _strList(dynamic raw) => raw is List
    ? raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
    : const <String>[];
