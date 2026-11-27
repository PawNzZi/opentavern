import 'dart:math';

import 'novel_types.dart';
import 'text_stream.dart';

/// 本地全量统计 + 智能采样（零 API 调用）。
///
/// 扫描阶段逐章流式读回（一次只持有一章文本），用轻量启发式收集人名/
/// 专有名词候选与每章「戏份密度」；两个候选 map 周期性裁剪，只保留出现
/// 次数最高的 300 项，内存有界。采样阶段按配置给出确定性章号列表，
/// 同样输入必得同样输出，便于测试与断点续跑。
class NovelSampler {
  NovelSampler._();

  static const _maxCandidates = 300;
  static const _pruneThreshold = 600;

  // ---- 人名启发式 ----
  // 用「边界字符 + 捕获组」代替后行断言，兼容性最好。

  /// 2–4 字中文串出现在言说/动作动词前：「李明说道」「王芳笑了笑」。
  static final _nameBeforeVerb = RegExp(
    r'(^|[^\u4e00-\u9fff])([\u4e00-\u9fff]{2,4}?)'
    r'(?=低声|轻声|点头|摇头|回答|开口|冷笑|微笑|大喊|心想|暗想|说道|问道|笑道|说|道|笑|问|答|看|想|喊|叫|骂|叹)',
  );

  /// 被「」/『』/“”包裹的 2–4 字纯中文短串（称谓/名字常被这样标注）。
  static final _quotedName = RegExp(r'[「『“]([\u4e00-\u9fff]{2,4})[」』”]');

  /// 名字 + 的 + 身体/情绪词：「李明的眼睛」「王芳心中一紧」。
  static final _nameDe = RegExp(
    r'(^|[^\u4e00-\u9fff])([\u4e00-\u9fff]{2,4}?)'
    r'(?=的(?:眼睛|脸上|心中|心里|嘴角|眉头|目光|声音|语气|身影|肩膀|眼泪|泪水|笑容|表情|头发|嘴唇|脸|眼|手|心|背))',
  );

  /// 含这些字的候选基本是虚词/代词组合，不是名字。
  static const _nameBadChars = '他她它你您我们着了的地得是在和与就都而及过这那么呢吧啊呀吗之其此该某各每又再才只却便很更最太';
  static const _nameStopWords = {
    '众人', '大家', '自己', '对方', '有人', '无人', '别人', '何人', '此人', '那人',
  };
  static final _numPeople = RegExp(r'^[零一二三四五六七八九十百千万两0-9]+人$');

  // ---- 专有名词启发式 ----

  /// 以 城/镇/村/山/河/派/宗/门/帮/星/界 结尾的 2–6 字词。
  static final _termSuffix1 =
      RegExp(r'([\u4e00-\u9fff]{1,5}?[城镇村山河派宗门帮星界])');

  /// 以双字后缀结尾的 3–6 字词。
  static final _termSuffix2 =
      RegExp(r'([\u4e00-\u9fff]{1,4}?(?:公司|集团|大学|学院|大陆|帝国))');

  /// 《》内词（书名/功法/物品）。
  static final _bookTitle = RegExp(r'《([^》\n]{1,20})》');

  /// 匹配可能从句首动词/介词开始（「前往青云城」），剥掉这些前导字。
  static const _termLeadStop = '我你他她它您们的地得了着是在和与就都而及过这那有个来到去向往从对把被让给赴入出前另其此该某每又再才只却便吹卷';
  static const _termStopWords = {
    '城门', '大门', '山门', '掌门', '开门', '关门', '出门', '进门', '敲门', '推门',
    '门派', '宗派', '帮派', '小镇', '山村', '高山', '火山',
  };

  /// 逐章扫描统计。[shouldStop] 返回 true 时抛 [NovelCancelledException]。
  static Future<NovelStats> scan(
    String path,
    ChapterIndex index, {
    void Function(int done, int total)? onProgress,
    bool Function()? shouldStop,
  }) async {
    final chapters = index.chapters;
    final total = chapters.length;
    final counts = List<int>.filled(total, 0);
    final hits = <int, int>{};
    var names = <String, int>{};
    var terms = <String, int>{};

    for (var i = 0; i < total; i++) {
      if (shouldStop != null && shouldStop()) {
        throw const NovelCancelledException();
      }
      final ch = chapters[i];
      final text = await NovelTextStream.readChapter(path, index, ch);
      if (ch.index >= 0 && ch.index < total) {
        counts[ch.index] = text.length;
      }
      var chapterHits = 0;

      void addName(String raw) {
        if (_badName(raw)) return;
        names[raw] = (names[raw] ?? 0) + 1;
        chapterHits++;
      }

      for (final m in _nameBeforeVerb.allMatches(text)) {
        addName(m.group(2)!);
      }
      for (final m in _quotedName.allMatches(text)) {
        addName(m.group(1)!);
      }
      for (final m in _nameDe.allMatches(text)) {
        addName(m.group(2)!);
      }

      void addTerm(String raw) {
        final term = _cleanTerm(raw);
        if (term.length < 2 || _termStopWords.contains(term)) return;
        terms[term] = (terms[term] ?? 0) + 1;
      }

      for (final m in _termSuffix1.allMatches(text)) {
        addTerm(m.group(1)!);
      }
      for (final m in _termSuffix2.allMatches(text)) {
        addTerm(m.group(1)!);
      }
      for (final m in _bookTitle.allMatches(text)) {
        final t = m.group(1)!.trim();
        if (t.isNotEmpty) terms[t] = (terms[t] ?? 0) + 1;
      }

      hits[ch.index] = chapterHits;
      if (names.length > _pruneThreshold) names = _prune(names);
      if (terms.length > _pruneThreshold) terms = _prune(terms);
      onProgress?.call(i + 1, total);
    }
    if (names.length > _maxCandidates) names = _prune(names);
    if (terms.length > _maxCandidates) terms = _prune(terms);
    return NovelStats(
      nameCandidates: names,
      termCandidates: terms,
      chapterCharCounts: counts,
      chapterNameHits: hits,
    );
  }

  static bool _badName(String name) {
    if (name.length < 2) return true;
    if (_nameStopWords.contains(name) || _numPeople.hasMatch(name)) return true;
    for (var i = 0; i < name.length; i++) {
      if (_nameBadChars.contains(name[i])) return true;
    }
    return false;
  }

  static String _cleanTerm(String raw) {
    var start = 0;
    while (start < raw.length - 2 && _termLeadStop.contains(raw[start])) {
      start++;
    }
    return raw.substring(start);
  }

  /// 只保留出现次数最高的 300 项；次数相同按字典序，保证确定性。
  static Map<String, int> _prune(Map<String, int> map) {
    final entries = map.entries.toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return Map<String, int>.fromEntries(entries.take(_maxCandidates));
  }

  /// 按扫描模式挑选要送入 LLM 的章（返回 [ChapterRef.index]，升序、去重、
  /// 确定性）。smart：必选开头 min(3,n) 章 + 结尾 min(2,n) 章，再沿全书
  /// 均匀覆盖取点，剩余额度按戏份密度（chapterNameHits）从高到低补齐，
  /// 总数不超过 maxBlocks；n 小于预算时返回全部。
  static List<int> selectChapters(
    ChapterIndex index,
    NovelStats stats,
    NovelJobConfig config,
  ) {
    final chapters = index.chapters;
    final n = chapters.length;
    if (n == 0) return const [];
    final ids = [for (final c in chapters) c.index];
    switch (config.scanMode) {
      case ScanMode.full:
        return ids..sort();
      case ScanMode.headOnly:
        final k = config.headChapters.clamp(0, n);
        return ids.sublist(0, k)..sort();
      case ScanMode.smart:
        final budget = config.maxBlocks;
        if (budget <= 0) return const [];
        if (n <= budget) return ids..sort();
        final picked = <int>{};
        void add(int pos) {
          if (picked.length < budget) picked.add(ids[pos]);
        }

        // 1) 必选首尾。
        final head = min(3, n);
        for (var i = 0; i < head; i++) {
          add(i);
        }
        final tail = min(2, n);
        for (var i = n - tail; i < n; i++) {
          add(i);
        }
        // 2) 均匀覆盖取点（最多用掉剩余额度的一半左右）。
        var remaining = budget - picked.length;
        if (remaining > 0) {
          final k = min(remaining, max(2, budget ~/ 2));
          for (var i = 0; i < k && picked.length < budget; i++) {
            final pos = k == 1 ? n ~/ 2 : (i * (n - 1)) ~/ (k - 1);
            add(pos);
          }
          remaining = budget - picked.length;
        }
        // 3) 戏份密度补齐（次数相同按章号升序，确定性）。
        if (remaining > 0) {
          final order = List<int>.generate(n, (i) => i)
            ..sort((a, b) {
              final ha = stats.chapterNameHits[ids[a]] ?? 0;
              final hb = stats.chapterNameHits[ids[b]] ?? 0;
              final c = hb.compareTo(ha);
              return c != 0 ? c : a.compareTo(b);
            });
          for (final pos in order) {
            if (picked.length >= budget) break;
            picked.add(ids[pos]);
          }
        }
        return picked.toList()..sort();
    }
  }
}
