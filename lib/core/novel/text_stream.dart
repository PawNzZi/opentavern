import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:enough_convert/gbk.dart';

import '../docx_text.dart';
import '../pdf_text.dart';
import 'novel_types.dart';

/// 用户取消任务时抛出。编排层捕获后把状态置为 cancelled，不算失败。
class NovelCancelledException implements Exception {
  const NovelCancelledException([this.message = '任务已取消']);

  final String message;

  @override
  String toString() => 'NovelCancelledException: $message';
}

/// 文档无法处理（过大 / 解析失败 / 提取不到文本）时抛出，message 可直接展示。
class NovelFormatException implements Exception {
  const NovelFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 小说文本的流式读取与切章 —— 几百 MB 文件内存恒定。
///
/// 核心约束：**绝不把整个文件读进内存**。任何时刻只持有 1~2 个 chunk
/// （默认 1MB）+ 当前一行（超长行有上限强制冲刷）+ 章节/兜底段索引。
///
/// 关键设计：章节边界在**字节域**找换行符，而不是先增量解码再找行。
/// UTF-8 / GBK / Latin-1 里 0x0A 都不可能出现在多字节序列内部（GBK 尾字节
/// 范围 0x40–0xFE，UTF-8 续字节 ≥0x80），UTF-16 按 2 字节对齐找 0x000A，
/// 因此按字节切行得到的偏移天然精确；不完整的尾字节自然留在行缓冲里等
/// 下一个 chunk，等价于「增量解码把截断序列留到下一轮」，且不需要
/// 解码后再编码回字节来推偏移（容错解码产生的 U+FFFD 无法往返）。
/// 每行单独解码用于标题识别与字数估算。
class NovelTextStream {
  NovelTextStream._();

  static const _sampleBytes = 64 * 1024;
  static const _fallbackChars = 6000;

  // ---- 章节标题规则（行首允许空白，整行 < 40 字才算标题）----

  static final _reChapterCn =
      RegExp(r'^第[零一二三四五六七八九十百千万两0-9]+[章回节卷集篇部]');
  static final _reChapterSpecial =
      RegExp(r'^(序章|楔子|前言|尾声|后记|番外|终章|序幕|引子)');
  static final _reChapterEn = RegExp(r'^Chapter\s+\d+', caseSensitive: false);
  static final _reChapterNum = RegExp(r'^\d{1,4}[.、]\s*\S');

  /// 文件指纹：`'<fileSize>-<modifiedMs>'`，与 [ChapterIndex.fingerprint]
  /// 格式完全一致。断点续跑用它判断「上次那个索引还是这个文件吗」。
  ///
  /// 注意：docx/pdf 经 [prepareTextFile] 转换后，要对**返回的临时 txt 路径**
  /// 取指纹（buildIndex 同理），才能与索引自洽。
  static Future<String> fileFingerprint(String path) async {
    final file = File(path);
    final size = await file.length();
    final mtime = (await file.lastModified()).millisecondsSinceEpoch;
    return '$size-$mtime';
  }

  /// 读前 64KB 样本探测编码。BOM 优先；无 BOM 先严格 UTF-8（裁掉样本末尾
  /// 被截断的多字节序列再试），失败则 GBK 试解，按「非 ASCII 解码结果里
  /// CJK 系字符的占比」判断，占比不合理回落 Latin-1；纯 ASCII 一律按 UTF-8。
  ///
  /// 短文件（样本即全文）放宽绝对数量门槛：极短的中文 GBK 文件（哪怕
  /// 只有「你好」两个汉字）也不该误判成 Latin-1。
  static Future<NovelEncoding> detectEncoding(String path) async {
    final raf = await File(path).open();
    try {
      final size = await raf.length();
      final sample = await raf.read(min(_sampleBytes, size));
      return _detectFromSample(sample, wholeFile: size <= _sampleBytes);
    } finally {
      await raf.close();
    }
  }

  /// 只读文件开头一段文本，不建立全书索引。
  ///
  /// 角色预检（判断谁是角色卡、谁是 {{user}}）只需要开头几千字；这本书可能
  /// 有几百 MB，不能为了预检扫全书。截断处的多字节字符由容错解码处理。
  static Future<String> readPrefix(
    String path, {
    int maxBytes = 96 * 1024,
  }) async {
    final enc = await detectEncoding(path);
    final raf = await File(path).open();
    try {
      final size = await raf.length();
      var bytes = await raf.read(min(maxBytes, size));
      if (enc.isWide && bytes.length.isOdd) {
        bytes = bytes.sublist(0, bytes.length - 1);
      }
      return _decodeBytes(bytes, enc);
    } finally {
      await raf.close();
    }
  }

  static NovelEncoding _detectFromSample(Uint8List sample,
      {bool wholeFile = false}) {
    if (sample.length >= 3 &&
        sample[0] == 0xEF &&
        sample[1] == 0xBB &&
        sample[2] == 0xBF) {
      return NovelEncoding.utf8;
    }
    if (sample.length >= 2 && sample[0] == 0xFF && sample[1] == 0xFE) {
      return NovelEncoding.utf16le;
    }
    if (sample.length >= 2 && sample[0] == 0xFE && sample[1] == 0xFF) {
      return NovelEncoding.utf16be;
    }
    if (sample.every((b) => b < 0x80)) return NovelEncoding.utf8;
    try {
      utf8.decode(_trimIncompleteUtf8(sample), allowMalformed: false);
      return NovelEncoding.utf8;
    } on FormatException {
      // 不是合法 UTF-8，继续往下试。
    }
    // GBK 试解，统计「非 ASCII 解码结果里 CJK 系字符的占比」。
    // 用这个比例而不是「占全部字符的比例」：短中文 GBK 文件里 ASCII
    // 标点/换行会稀释总数，而 Latin-1 西文重音文本解 GBK 会产生大量
    // 替换符（U+FFFD）和零星伪 CJK，占比天然上不去。
    final decoded = const GbkCodec(allowInvalid: true).decode(sample);
    var cjk = 0;
    var cjkIsh = 0;
    var nonAscii = 0;
    var fffd = 0;
    for (final r in decoded.runes) {
      if (r > 0x7F) nonAscii++;
      if (r == 0xFFFD) fffd++;
      if (r >= 0x4E00 && r <= 0x9FFF) {
        cjk++;
        cjkIsh++;
      } else if (_isCjkIsh(r)) {
        cjkIsh++;
      }
    }
    // 短文件（样本=全文）放宽绝对数量门槛：两个汉字也认。
    final minCjk = wholeFile ? 2 : 4;
    if (cjk >= minCjk &&
        nonAscii > 0 &&
        cjkIsh * 100 >= nonAscii * 60 &&
        fffd * 5 < nonAscii) {
      return NovelEncoding.gb18030;
    }
    return NovelEncoding.latin1;
  }

  /// CJK 系字符（含 CJK 标点与全角形式），GBK 中文文本的主体。
  static bool _isCjkIsh(int rune) =>
      (rune >= 0x3000 && rune <= 0x303F) || // CJK 标点
      (rune >= 0x4E00 && rune <= 0x9FFF) || // 汉字
      (rune >= 0xFF00 && rune <= 0xFFEF) || // 全角形式
      (rune >= 0x3400 && rune <= 0x4DBF) || // 扩展 A
      (rune >= 0xF900 && rune <= 0xFAFF); // 兼容表意

  /// 样本末尾可能截断多字节字符：把不完整序列裁掉再做严格试解。
  static Uint8List _trimIncompleteUtf8(Uint8List bytes) {
    final end = bytes.length;
    var i = end - 1;
    var back = 0;
    while (i >= 0 && back < 3 && (bytes[i] & 0xC0) == 0x80) {
      i--;
      back++;
    }
    if (i < 0) return bytes;
    final b = bytes[i];
    final int need;
    if (b < 0x80) {
      return bytes;
    } else if (b >= 0xC2 && b <= 0xDF) {
      need = 2;
    } else if (b >= 0xE0 && b <= 0xEF) {
      need = 3;
    } else if (b >= 0xF0 && b <= 0xF4) {
      need = 4;
    } else {
      return bytes; // 非法前导字节，让严格解码自己失败。
    }
    if (end - i < need) return bytes.sublist(0, i);
    return bytes;
  }

  /// 分块扫描全书建立章节索引。内存恒定：chunk + 行缓冲 + 索引。
  ///
  /// 识别不到任何标题时按约 6000 字兜底切段（在行边界切，标题 `第N段`），
  /// 保证下游一定能工作。第一个标题之前的非空内容并入「开篇」章。
  /// [shouldStop] 返回 true 时尽快抛 [NovelCancelledException]。
  ///
  /// [encoding] 手动指定编码（最高优先级，跳过探测）：自动探测对极短
  /// 中文 GBK 文件是启发式，用户手动指定是确定性的兜底。UTF-16 的
  /// 偏移对齐逻辑照常按 2 字节工作。
  static Future<ChapterIndex> buildIndex(
    String path, {
    int chunkBytes = 1 << 20,
    NovelEncoding? encoding,
    void Function(int doneBytes, int totalBytes)? onProgress,
    bool Function()? shouldStop,
  }) async {
    final file = File(path);
    final size = await file.length();
    final modifiedMs = (await file.lastModified()).millisecondsSinceEpoch;
    // 手动指定 > 自动探测。
    final enc = encoding ?? await detectEncoding(path);
    final scanner = _ChapterScanner(enc, size);
    final raf = await file.open();
    try {
      final wide = enc.isWide;
      final step = max(16, chunkBytes);
      var done = 0;
      var carry = Uint8List(0); // UTF-16 的 2 字节对齐余字节。
      while (done < size) {
        if (shouldStop != null && shouldStop()) {
          throw const NovelCancelledException();
        }
        final raw = await raf.read(min(step, size - done));
        if (raw.isEmpty) break;
        final readStart = done;
        done += raw.length;
        if (wide) {
          final Uint8List buf;
          final int base;
          if (carry.isEmpty) {
            buf = raw;
            base = readStart;
          } else {
            buf = Uint8List(carry.length + raw.length);
            buf.setAll(0, carry);
            buf.setAll(carry.length, raw);
            base = readStart - carry.length;
          }
          final usable = buf.length - (buf.length % 2);
          carry = usable == buf.length
              ? Uint8List(0)
              : Uint8List.fromList(buf.sublist(usable));
          scanner.feed(buf, usable, base);
        } else {
          // 单字节域：截断的多字节序列留在行缓冲里，天然跨 chunk。
          scanner.feed(raw, raw.length, readStart);
        }
        onProgress?.call(done, size);
      }
      scanner.finish();
      if (size == 0) onProgress?.call(0, 0);
      return ChapterIndex(
        filePath: path,
        fileName:
            file.uri.pathSegments.isEmpty ? path : file.uri.pathSegments.last,
        fileSize: size,
        modifiedMs: modifiedMs,
        encoding: enc,
        chapters: scanner.chapters,
        totalChars: scanner.totalChars,
      );
    } finally {
      await raf.close();
    }
  }

  /// 按索引里的字节偏移精确读回一章（含标题行），容错解码。
  /// UTF-16 偏移按 2 字节对齐。返回的字符串不含 BOM。
  static Future<String> readChapter(
    String path,
    ChapterIndex index,
    ChapterRef ch,
  ) async {
    var offset = ch.byteOffset;
    var length = ch.byteLength;
    if (index.encoding.isWide) {
      if (offset.isOdd) {
        offset -= 1;
        length += 1;
      }
      if (length.isOdd) length += 1;
    }
    final raf = await File(path).open();
    try {
      await raf.setPosition(offset);
      final builder = BytesBuilder(copy: false);
      var remaining = length;
      while (remaining > 0) {
        final part = await raf.read(remaining);
        if (part.isEmpty) break;
        builder.add(part);
        remaining -= part.length;
      }
      return _decodeBytes(builder.takeBytes(), index.encoding);
    } finally {
      await raf.close();
    }
  }

  /// 把过长章节切成 ≤[blockChars] 的片：优先段落（空行）边界，其次换行，
  /// 超长单行在句末标点附近切，实在没有才硬切。拼接结果与原文完全一致。
  static List<String> splitBlocks(String text, int blockChars) {
    final limit = blockChars > 0 ? blockChars : _fallbackChars;
    if (text.length <= limit) return [text];
    final blocks = <String>[];
    final buf = StringBuffer();
    void flush() {
      if (buf.isNotEmpty) {
        blocks.add(buf.toString());
        buf.clear();
      }
    }

    for (final para in _paragraphs(text)) {
      if (para.length > limit) {
        flush();
        blocks.addAll(_splitOversizeParagraph(para, limit));
      } else if (buf.length + para.length > limit) {
        flush();
        buf.write(para);
      } else {
        buf.write(para);
      }
    }
    flush();
    return blocks;
  }

  /// 按空行把文本拆成段落（保留换行符，拼接 == 原文）。
  static List<String> _paragraphs(String text) {
    final out = <String>[];
    final cur = StringBuffer();
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final last = i == lines.length - 1;
      cur.write(lines[i]);
      if (!last) cur.write('\n');
      if (!last && lines[i].trim().isEmpty) {
        out.add(cur.toString());
        cur.clear();
      }
    }
    if (cur.isNotEmpty) out.add(cur.toString());
    return out;
  }

  static List<String> _splitOversizeParagraph(String para, int limit) {
    final blocks = <String>[];
    final buf = StringBuffer();
    void flush() {
      if (buf.isNotEmpty) {
        blocks.add(buf.toString());
        buf.clear();
      }
    }

    final lines = para.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final last = i == lines.length - 1;
      var piece = last ? lines[i] : '${lines[i]}\n';
      while (piece.length > limit) {
        flush();
        final cut = _sentenceCut(piece, limit);
        blocks.add(piece.substring(0, cut));
        piece = piece.substring(cut);
      }
      if (piece.isEmpty) continue;
      if (buf.length + piece.length > limit) flush();
      buf.write(piece);
    }
    flush();
    return blocks;
  }

  /// 在 limit 附近的句末标点处切（向前找最多 20% 窗口），找不到就硬切。
  static int _sentenceCut(String s, int limit) {
    const ends = '。！？!?；;…';
    final windowStart = max(0, limit - max(1, limit ~/ 5));
    for (var i = limit - 1; i >= windowStart; i--) {
      if (ends.contains(s[i])) return i + 1;
    }
    return limit;
  }

  /// 导入预处理：txt/md/其它纯文本原样返回；docx/pdf 提取文本写成 UTF-8
  /// 临时 txt 并返回新路径。超过 [maxDocBytes] 或提取失败抛可读异常。
  ///
  /// 下游（buildIndex / fileFingerprint）必须使用**返回的路径**。
  static Future<String> prepareTextFile(
    String path, {
    int maxDocBytes = 80 * 1024 * 1024,
  }) async {
    final lower = path.toLowerCase();
    final isDocx = lower.endsWith('.docx');
    final isPdf = lower.endsWith('.pdf');
    if (!isDocx && !isPdf) return path;
    final file = File(path);
    final size = await file.length();
    if (size > maxDocBytes) {
      throw NovelFormatException(
        '文档过大（${(size / 1024 / 1024).toStringAsFixed(1)} MB），请先转成 txt 再导入',
      );
    }
    String? text;
    try {
      final bytes = await file.readAsBytes();
      text = isDocx ? extractDocxText(bytes) : extractPdfText(bytes);
    } catch (_) {
      throw const NovelFormatException('文档解析失败，请先转成 txt 再导入');
    }
    if (text == null || text.trim().isEmpty) {
      throw const NovelFormatException('无法从文档中提取文本，请先转成 txt 再导入');
    }
    final dir = await Directory.systemTemp.createTemp('novel_extract_');
    final out = File('${dir.path}${Platform.pathSeparator}extracted.txt');
    await out.writeAsString(text, flush: true);
    return out.path;
  }

  // ---- 内部：解码与标题 ----

  /// 容错解码一段字节；剥掉开头的 BOM 字符。
  static String _decodeBytes(List<int> bytes, NovelEncoding encoding) {
    String text;
    switch (encoding) {
      case NovelEncoding.utf8:
        text = utf8.decode(bytes, allowMalformed: true);
      case NovelEncoding.gb18030:
        text = const GbkCodec(allowInvalid: true).decode(bytes);
      case NovelEncoding.latin1:
        text = latin1.decode(bytes);
      case NovelEncoding.utf16le:
        text = _decodeUtf16(bytes, bigEndian: false);
      case NovelEncoding.utf16be:
        text = _decodeUtf16(bytes, bigEndian: true);
    }
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      text = text.substring(1);
    }
    return text;
  }

  /// Dart 字符串本身就是 UTF-16 码元序列：跨 chunk 的代理对拼接后自然成立。
  static String _decodeUtf16(List<int> bytes, {required bool bigEndian}) {
    final n = bytes.length ~/ 2;
    final units = Uint16List(n);
    for (var i = 0; i < n; i++) {
      final a = bytes[2 * i];
      final b = bytes[2 * i + 1];
      units[i] = bigEndian ? (a << 8) | b : (b << 8) | a;
    }
    return String.fromCharCodes(units);
  }

  static String? _matchTitle(String line) {
    final t = line.trim();
    if (t.isEmpty || t.length >= 40) return null;
    if (_reChapterCn.hasMatch(t) ||
        _reChapterSpecial.hasMatch(t) ||
        _reChapterEn.hasMatch(t) ||
        _reChapterNum.hasMatch(t)) {
      return t;
    }
    return null;
  }
}

/// 单次 buildIndex 的扫描状态：行缓冲 + 章节累积 + 兜底段累积。
/// 行缓冲有上限（超长行强制冲刷并标记「续行不算标题」），内存有界。
class _ChapterScanner {
  _ChapterScanner(this.encoding, this.fileSize);

  final NovelEncoding encoding;
  final int fileSize;

  static const _maxLineBytes = 64 * 1024;

  final BytesBuilder _pending = BytesBuilder(copy: false);
  int _pendingStart = 0;
  int _pendingLen = 0;
  bool _inLongLine = false;

  final List<ChapterRef> chapters = [];
  String? _openTitle;
  int _openOffset = 0;
  int _openChars = 0;
  bool _preambleHasContent = false;

  final List<ChapterRef> _segments = [];
  int _segStart = 0;
  int _segChars = 0;

  int totalChars = 0;

  bool get _wide => encoding.isWide;

  /// 处理一块字节：[base] 是 buf[0] 的原文件绝对偏移，只处理前 [usable] 字节。
  void feed(Uint8List buf, int usable, int base) {
    final width = _wide ? 2 : 1;
    final bigEndian = encoding == NovelEncoding.utf16be;
    var i = 0;
    var lineFrom = 0;
    while (i < usable) {
      final unit = _wide
          ? (bigEndian
              ? (buf[i] << 8) | buf[i + 1]
              : buf[i] | (buf[i + 1] << 8))
          : buf[i];
      if (unit == 0x0A) {
        final end = i + width;
        _append(buf.sublist(lineFrom, end), base + lineFrom);
        _finishLine(base + end);
        lineFrom = end;
      }
      i += width;
    }
    if (lineFrom < usable) {
      _append(buf.sublist(lineFrom, usable), base + lineFrom);
    }
  }

  void _append(Uint8List bytes, int absStart) {
    if (_pendingLen == 0) _pendingStart = absStart;
    _pending.add(bytes);
    _pendingLen += bytes.length;
    final cap = _wide ? _maxLineBytes * 2 : _maxLineBytes;
    if (_pendingLen > cap) {
      // 超长行（无换行的畸形文件）：强制冲刷，防止行缓冲无界增长。
      final data = _pending.takeBytes();
      final end = _pendingStart + data.length;
      _pendingLen = 0;
      _inLongLine = true;
      final text = NovelTextStream._decodeBytes(data, encoding);
      _count(text, end);
    }
  }

  void _finishLine(int end) {
    final bytes = _pending.takeBytes();
    _pendingLen = 0;
    final text = NovelTextStream._decodeBytes(bytes, encoding);
    final trimmed = text.trimRight();
    final title = _inLongLine ? null : NovelTextStream._matchTitle(trimmed);
    _inLongLine = false;
    if (title != null) {
      final start = end - bytes.length;
      if (_openTitle != null) {
        _closeChapter(start);
      } else if (_preambleHasContent) {
        chapters.add(ChapterRef(
          index: chapters.length,
          title: '开篇',
          byteOffset: 0,
          byteLength: start,
          charCount: _openChars,
        ));
      }
      _openTitle = title;
      _openOffset = start;
      _openChars = 0;
    }
    _count(text, end);
  }

  /// 字数累计 + 兜底段累计（标题章与兜底段同时维护，最后二选一）。
  void _count(String text, int end) {
    final trimmed = text.trimRight();
    final chars = trimmed.length;
    totalChars += chars;
    _openChars += chars;
    if (_openTitle == null && trimmed.trim().isNotEmpty) {
      _preambleHasContent = true;
    }
    _segChars += chars;
    if (_segChars >= NovelTextStream._fallbackChars) _closeSegment(end);
  }

  void _closeChapter(int end) {
    chapters.add(ChapterRef(
      index: chapters.length,
      title: _openTitle!,
      byteOffset: _openOffset,
      byteLength: end - _openOffset,
      charCount: _openChars,
    ));
    _openTitle = null;
    _openChars = 0;
  }

  void _closeSegment(int end) {
    if (end <= _segStart) return;
    _segments.add(ChapterRef(
      index: _segments.length,
      title: '第${_segments.length + 1}段',
      byteOffset: _segStart,
      byteLength: end - _segStart,
      charCount: _segChars,
    ));
    _segStart = end;
    _segChars = 0;
  }

  /// EOF：冲刷末行、收尾当前章/段；没有任何标题则启用兜底段。
  void finish() {
    if (_pendingLen > 0) {
      _finishLine(_pendingStart + _pendingLen);
    }
    if (_openTitle != null) {
      _closeChapter(fileSize);
    }
    // 全书无标题时不生成「开篇」章，交给兜底切段。
    if (_segStart < fileSize) _closeSegment(fileSize);
    if (chapters.isEmpty) {
      if (_segments.isEmpty) {
        _segments.add(ChapterRef(
          index: 0,
          title: '第1段',
          byteOffset: 0,
          byteLength: fileSize,
          charCount: totalChars,
        ));
      }
      chapters.addAll(_segments);
    }
  }
}
