import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/novel/job_store.dart';
import '../core/novel/novel_controller.dart';
import '../core/novel/novel_types.dart';
import '../core/novel/publish.dart';
import '../core/store.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';
import '../design/toast.dart';
import 'model_picker.dart';
import 'provider_picker.dart';

/// 「小说/文档 → 角色卡 + 世界书」向导。
///
/// 三段式界面：配置 → 进度 → 结果预览。任务跑在 worker isolate，控制器是单例，
/// 所以离开本页去逛角色库时任务继续，回来还能看到进度。
class NovelImportPage extends StatefulWidget {
  const NovelImportPage({super.key});

  @override
  State<NovelImportPage> createState() => _NovelImportPageState();
}

class _NovelImportPageState extends State<NovelImportPage> {
  final _gen = NovelGenController.instance;
  final _extra = TextEditingController();

  String _filePath = '';
  String _fileName = '';
  int _fileSize = 0;
  List<String> _avatars = [];

  ScanMode _mode = ScanMode.smart;
  int _maxBlocks = 120;
  int _maxCards = 3;
  int _maxLore = 40;
  int _concurrency = 2;
  String _provider = '';
  String _model = '';

  List<NovelJobSummary> _jobs = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _gen.addListener(_onGen);
    _loadJobs();
  }

  @override
  void dispose() {
    _gen.removeListener(_onGen);
    _extra.dispose();
    super.dispose();
  }

  void _onGen() {
    if (mounted) setState(() {});
  }

  Future<void> _loadJobs() async {
    final jobs = await _gen.jobs();
    if (!mounted) return;
    setState(() => _jobs = jobs);
  }

  // ------------------------------------------------------------ 选料

  Future<void> _pickFile() async {
    final file = await FilePickerPlatform.instance.pickFile();
    if (file == null) return;
    var path = file.path;
    // 少数平台只给字节不给路径：落一份临时文件，后续仍是流式读取。
    if (path == null || path.isEmpty) {
      final bytes = await file.readAsBytes();
      final dir = await Directory.systemTemp.createTemp('novel-');
      final tmp = File('${dir.path}/${file.name}');
      await tmp.writeAsBytes(bytes, flush: true);
      path = tmp.path;
    }
    final ext = file.name.split('.').last.toLowerCase();
    const supported = {'txt', 'md', 'markdown', 'text', 'docx', 'pdf'};
    if (!supported.contains(ext)) {
      if (!mounted) return;
      showTavernToast(context, '暂不支持 .$ext，请用 txt / md / docx / pdf');
      return;
    }
    final size = await File(path).length();
    if (!mounted) return;
    setState(() {
      _filePath = path!;
      _fileName = file.name;
      _fileSize = size;
    });
  }

  Future<void> _pickAvatars() async {
    final files = await FilePickerPlatform.instance.pickFiles(
      dialogTitle: '选择角色立绘（可多选）',
    );
    if (files.isEmpty) return;
    final paths = <String>[];
    for (final f in files) {
      final p = f.path;
      if (p != null && p.isNotEmpty) paths.add(p);
    }
    if (!mounted) return;
    setState(() => _avatars = paths);
    showTavernToast(context, '已选 ${paths.length} 张立绘，按顺序分配给角色');
  }

  Future<void> _pickProvider() async {
    final api = AppStore.instance.settings.api;
    bool configured(String id) =>
        (api.profiles[id]?.apiKey.trim().isNotEmpty ?? false) ||
        (id == api.provider && api.apiKey.trim().isNotEmpty);
    final picked = await showProviderPicker(
      context,
      providers: kProviderOrder,
      configured: configured,
      current: _provider,
      globalProvider: api.provider,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _provider = picked;
      _model = '';
    });
  }

  Future<void> _pickModel() async {
    final api = AppStore.instance.apiForProvider(_provider, model: _model);
    final picked = await showModelPicker(
      context,
      api: api,
      current: api.model.trim(),
      subtitle: '${kProviderLabels[api.provider] ?? api.provider} · 选择模型',
    );
    if (picked == null || !mounted) return;
    setState(() => _model = picked);
  }

  // ------------------------------------------------------------ 启动

  NovelJobConfig get _config => NovelJobConfig(
        filePath: _filePath,
        fileName: _fileName,
        scanMode: _mode,
        maxBlocks: _maxBlocks,
        maxCards: _maxCards,
        maxLoreEntries: _maxLore,
        concurrency: _concurrency,
        providerOverride: _provider,
        modelOverride: _model,
        avatarPaths: _avatars,
        extraInstruction: _extra.text.trim(),
      );

  Future<void> _start() async {
    if (_filePath.isEmpty) {
      showTavernToast(context, '请先选择小说或文档文件');
      return;
    }
    final api = AppStore.instance.apiForProvider(_provider, model: _model);
    if (!api.configured) {
      showTavernToast(context, '该服务商还没配置密钥，请先去「API 连接」填写');
      return;
    }
    if (_mode == ScanMode.full) {
      final ok = await _confirmFullScan();
      if (ok != true) return;
    }
    await _gen.start(_config);
  }

  Future<bool?> _confirmFullScan() {
    final mb = _fileSize / 1024 / 1024;
    // 粗估：1MB 中文约 35 万字 ≈ 42 万 token，按 6000 字/块。
    final estBlocks = (mb * 350000 / 6000).round();
    final estHours = (estBlocks * 8 / _concurrency / 3600).toStringAsFixed(1);
    return showTavernSheet<bool>(
      context,
      title: '全书精读确认',
      subtitle: '这会非常慢且消耗大量 token',
      heightFactor: .46,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HintCard(
            text: '文件约 ${mb.toStringAsFixed(1)} MB，估计需要抽取 $estBlocks 块，'
                '按当前并发 $_concurrency 预计耗时 $estHours 小时以上，'
                'token 消耗巨大。建议改用「智能采样」。',
            icon: Icons.warning_amber_rounded,
            color: AppPalette.of(context).danger,
          ),
          const SizedBox(height: 14),
          GlassPrimaryButton(
            label: '我了解，仍要全书精读',
            icon: Icons.play_arrow_rounded,
            onTap: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 8),
          GlassPill(
            label: '改用智能采样',
            icon: Icons.auto_awesome_rounded,
            height: 38,
            onTap: () {
              setState(() => _mode = ScanMode.smart);
              Navigator.of(context).pop(false);
            },
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ 保存/导出

  Future<void> _save() async {
    final result = _gen.result;
    if (result == null || _saving) return;
    final cards = result.cards.where((c) => c.selected).length;
    final lore = result.lore.where((l) => l.selected).length;
    if (cards == 0 && lore == 0) {
      showTavernToast(context, '请至少勾选一张角色卡或一条世界书');
      return;
    }
    setState(() => _saving = true);
    try {
      final outcome = await publishGenerated(result, bookName: result.bookName);
      if (!mounted) return;
      final replaced = outcome.replacedNames.isEmpty
          ? ''
          : '（已覆盖同名：${outcome.replacedNames.join('、')}）';
      showTavernToast(
        context,
        '已入库 ${outcome.characters.length} 张角色卡'
        '${outcome.book == null ? '' : ' + 世界书'}$replaced',
      );
      _gen.clear();
      await _loadJobs();
    } catch (e) {
      if (!mounted) return;
      showTavernToast(context, '入库失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportAll() async {
    final result = _gen.result;
    if (result == null) return;
    final selected = result.cards.where((c) => c.selected).toList();
    if (selected.isEmpty) {
      showTavernToast(context, '请先勾选要导出的角色卡');
      return;
    }
    final book = draftToLorebook(
      result,
      linkedCharacterName: selected.first.name,
    );
    var ok = 0;
    for (final draft in selected) {
      final character = await draftToCharacter(draft, bookName: book.name);
      final bytes = await buildCardPng(character, book: book);
      final uri = await FilePickerPlatform.instance.saveFile(
        fileName: '${character.name}.png',
        bytes: bytes,
        mimeType: 'image/png',
        dialogTitle: '导出角色卡（含世界书）',
      );
      if (uri != null) ok++;
    }
    if (!mounted) return;
    showTavernToast(
      context,
      ok == 0 ? '已取消导出' : '已导出 $ok 张 PNG（角色卡 + 世界书）',
    );
  }

  // ------------------------------------------------------------ 构建

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final busy = _gen.busy;
    final result = _gen.result;

    return DetailPage(
      eyebrow: '角色库',
      title: '小说生成',
      subtitle: busy
          ? '后台生成中 · ${_gen.progress.percent.toStringAsFixed(1)}%'
          : result != null
              ? '预览并入库'
              : '导入小说/文档，生成角色卡与世界书',
      footer: busy
          ? null
          : result != null
              ? Column(
                  children: [
                    GlassPrimaryButton(
                      label: _saving ? '入库中…' : '保存入库',
                      icon: Icons.check_rounded,
                      onTap: _saving ? null : _save,
                    ),
                    const SizedBox(height: 8),
                    GlassPill(
                      label: '导出 PNG（含世界书）',
                      icon: Icons.image_outlined,
                      height: 40,
                      onTap: _exportAll,
                    ),
                  ],
                )
              : GlassPrimaryButton(
                  label: '开始生成',
                  icon: Icons.auto_awesome_rounded,
                  onTap: _start,
                ),
      children: busy
          ? _progressSection(p)
          : result != null
              ? _resultSection(p, result)
              : _configSection(p),
    );
  }

  // ------------------------------------------------------ 配置阶段

  List<Widget> _configSection(AppPalette p) {
    final resumable = _jobs.where((j) => j.resumable).toList();
    return [
      SettingsGroup(
        title: '素材',
        children: [
          SettingRow(
            icon: Icons.description_outlined,
            title: '小说 / 文档',
            subtitle: _filePath.isEmpty
                ? '支持 txt / md / docx / pdf，大文件流式读取'
                : '${(_fileSize / 1024 / 1024).toStringAsFixed(1)} MB',
            value: _fileName.isEmpty ? '未选择' : _fileName,
            iconColor: p.amber,
            onTap: _pickFile,
          ),
          const Hairline(indent: 56),
          SettingRow(
            icon: Icons.image_outlined,
            title: '角色立绘',
            subtitle: '按顺序分配给生成的角色，可留空',
            value: _avatars.isEmpty ? '未选择' : '${_avatars.length} 张',
            iconColor: p.violet,
            onTap: _pickAvatars,
          ),
        ],
      ),
      const SizedBox(height: 12),
      const HintCard(
        text: '几百 MB 的文件不会整本读进内存，也不会整本发给模型：'
            '先本地流式切章与词频统计（不花 token），再挑信息密度最高的片段送 AI。'
            '生成期间请保持应用前台，中断后可续跑。',
      ),
      const SizedBox(height: 14),
      SettingsGroup(
        title: '生成',
        children: [
          SegmentLine(
            title: '扫描模式',
            options: const ['智能采样', '全书精读', '仅开头'],
            index: _mode.index,
            onChanged: (i) => setState(() => _mode = ScanMode.values[i]),
          ),
          if (_mode == ScanMode.smart) ...[
            const Hairline(indent: 14),
            StepperRow(
              title: '抽取块数上限',
              subtitle: '越多越完整，也越慢越贵',
              value: '$_maxBlocks',
              onMinus: () => setState(
                  () => _maxBlocks = (_maxBlocks - 20).clamp(20, 600)),
              onPlus: () => setState(
                  () => _maxBlocks = (_maxBlocks + 20).clamp(20, 600)),
            ),
          ],
          const Hairline(indent: 14),
          StepperRow(
            title: '角色卡数量',
            subtitle: '按戏份取前 N 个人物',
            value: '$_maxCards',
            onMinus: () =>
                setState(() => _maxCards = (_maxCards - 1).clamp(1, 10)),
            onPlus: () =>
                setState(() => _maxCards = (_maxCards + 1).clamp(1, 10)),
          ),
          const Hairline(indent: 14),
          StepperRow(
            title: '世界书条目上限',
            value: '$_maxLore',
            onMinus: () =>
                setState(() => _maxLore = (_maxLore - 10).clamp(5, 200)),
            onPlus: () =>
                setState(() => _maxLore = (_maxLore + 10).clamp(5, 200)),
          ),
          const Hairline(indent: 14),
          StepperRow(
            title: '并发请求',
            subtitle: '过高可能触发服务商限流',
            value: '$_concurrency',
            onMinus: () =>
                setState(() => _concurrency = (_concurrency - 1).clamp(1, 4)),
            onPlus: () =>
                setState(() => _concurrency = (_concurrency + 1).clamp(1, 4)),
          ),
        ],
      ),
      const SizedBox(height: 14),
      SettingsGroup(
        title: 'AI',
        children: [
          SettingRow(
            icon: Icons.hub_outlined,
            title: '服务商',
            subtitle: '仅本次生成使用，不改全局',
            value: _provider.isEmpty
                ? '跟随全局'
                : (kProviderLabels[_provider] ?? _provider),
            iconColor: p.amber,
            onTap: _pickProvider,
          ),
          const Hairline(indent: 56),
          SettingRow(
            icon: Icons.auto_awesome_rounded,
            title: '模型',
            subtitle: '建议用长上下文、擅长中文的模型',
            value: _effectiveModelLabel(),
            iconColor: p.sage,
            onTap: _pickModel,
          ),
        ],
      ),
      const SizedBox(height: 14),
      _extraField(p),
      if (resumable.isNotEmpty) ...[
        const SizedBox(height: 14),
        SettingsGroup(
          title: '继续上次生成',
          children: [
            for (var i = 0; i < resumable.length; i++) ...[
              if (i > 0) const Hairline(indent: 56),
              SettingRow(
                icon: Icons.history_rounded,
                title: resumable[i].fileName,
                subtitle: '已完成 ${resumable[i].doneBlocks}'
                    '/${resumable[i].totalBlocks} 块',
                value: '续跑',
                iconColor: p.amber,
                onTap: () => _gen.resumeJob(resumable[i].id),
              ),
            ],
          ],
        ),
      ],
    ];
  }

  String _effectiveModelLabel() {
    final api = AppStore.instance.apiForProvider(_provider, model: _model);
    final m = api.model.trim();
    return m.isEmpty ? '未配置' : m;
  }

  Widget _extraField(AppPalette p) => Glass(
        radius: 20,
        blur: 20,
        shadow: false,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '附加要求（可选）',
              style: appText(10.5, FontWeight.w500, p.textTertiary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _extra,
              maxLines: 3,
              style: appText(13, FontWeight.w400, p.textPrimary, height: 1.5),
              cursorColor: p.amber,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '例如：只生成女性角色；开场白要日常轻松',
                hintStyle: appText(12.5, FontWeight.w400, p.textTertiary),
              ),
            ),
          ],
        ),
      );

  // ------------------------------------------------------ 进度阶段

  List<Widget> _progressSection(AppPalette p) {
    final pr = _gen.progress;
    final paused = pr.state == GenState.paused;
    return [
      Glass(
        radius: 22,
        blur: 22,
        shadow: false,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  pr.percent.toStringAsFixed(1),
                  style: appText(34, FontWeight.w700, p.amber, letterSpacing: -1),
                ),
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('%',
                      style: appText(14, FontWeight.w600, p.amber)),
                ),
                const Spacer(),
                Text(
                  paused ? '已暂停' : pr.phase.label,
                  style: appText(12, FontWeight.w600, p.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ProgressLine(value: pr.percent / 100, height: 8),
            const SizedBox(height: 10),
            Text(
              pr.currentLabel.isEmpty ? _gen.fileName : pr.currentLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appText(11.5, FontWeight.w400, p.textTertiary),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                MiniStat(
                  value: '${pr.doneBlocks}/${pr.totalBlocks}',
                  label: '已抽取块',
                ),
                const SizedBox(width: 22),
                MiniStat(
                  value: _compact(pr.tokensUsed),
                  label: 'tokens',
                ),
                const SizedBox(width: 22),
                MiniStat(
                  value: pr.etaMs > 0 ? _duration(pr.etaMs) : '估算中',
                  label: '预计剩余',
                ),
              ],
            ),
            if (pr.failedBlocks > 0) ...[
              const SizedBox(height: 10),
              Text(
                '${pr.failedBlocks} 块失败（已跳过，不影响整体）',
                style: appText(11, FontWeight.w500, p.danger),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: GlassPill(
              label: paused ? '继续' : '暂停',
              icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              height: 42,
              onTap: paused ? _gen.resume : _gen.pause,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GlassPill(
              label: '取消',
              icon: Icons.stop_rounded,
              height: 42,
              onTap: _gen.cancel,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      const HintCard(
        text: '任务在后台线程执行，界面不会卡。iOS 退到后台会被系统挂起，'
            '请保持应用前台（已自动防锁屏）。每块结果都已落盘，'
            '被中断后回到本页可「继续上次生成」，已完成的块不会重复消耗。',
      ),
      const SizedBox(height: 14),
      SectionLabel('运行日志'),
      const SizedBox(height: 8),
      Glass(
        radius: 18,
        blur: 18,
        shadow: false,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: SizedBox(
          height: 168,
          child: pr.logs.isEmpty
              ? Center(
                  child: Text('等待输出…',
                      style: appText(11.5, FontWeight.w400, p.textTertiary)),
                )
              : ListView.builder(
                  reverse: true,
                  padding: EdgeInsets.zero,
                  physics: const BouncingScrollPhysics(),
                  itemCount: pr.logs.length,
                  itemBuilder: (_, i) {
                    final line = pr.logs[pr.logs.length - 1 - i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        line,
                        style: appText(
                          10.5,
                          FontWeight.w400,
                          line.startsWith('✗') ? p.danger : p.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    ];
  }

  // ------------------------------------------------------ 结果阶段

  List<Widget> _resultSection(AppPalette p, GenResult result) {
    return [
      Glass(
        radius: 22,
        blur: 22,
        shadow: false,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            MiniStat(value: '${result.cards.length}', label: '角色卡'),
            const SizedBox(width: 24),
            MiniStat(value: '${result.lore.length}', label: '世界书条目'),
            const SizedBox(width: 24),
            MiniStat(value: _compact(result.tokensUsed), label: 'tokens'),
          ],
        ),
      ),
      if (result.failedBlocks.isNotEmpty) ...[
        const SizedBox(height: 10),
        HintCard(
          text: '${result.failedBlocks.length} 块抽取失败已跳过，'
              '设定可能不完整。可重新生成或续跑补齐。',
          icon: Icons.info_outline_rounded,
          color: p.danger,
        ),
      ],
      const SizedBox(height: 14),
      SectionLabel('角色卡'),
      const SizedBox(height: 8),
      for (var i = 0; i < result.cards.length; i++) ...[
        _cardTile(p, result, i),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 6),
      SectionLabel('世界书 · ${result.bookName}'),
      const SizedBox(height: 8),
      for (var i = 0; i < result.lore.length; i++) ...[
        _loreTile(p, result, i),
        const SizedBox(height: 8),
      ],
    ];
  }

  Widget _cardTile(AppPalette p, GenResult result, int index) {
    final card = result.cards[index];
    return Glass(
      radius: 20,
      blur: 20,
      shadow: false,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _check(p, card.selected, () {
                final cards = [...result.cards];
                cards[index] = card.copyWith(selected: !card.selected);
                _gen.updateResult(GenResult(
                  bookName: result.bookName,
                  cards: cards,
                  lore: result.lore,
                  tokensUsed: result.tokensUsed,
                  failedBlocks: result.failedBlocks,
                  scannedBlocks: result.scannedBlocks,
                  totalBlocks: result.totalBlocks,
                ));
              }),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  card.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appText(14.5, FontWeight.w600, p.textPrimary),
                ),
              ),
              GlassPill(
                label: '编辑',
                icon: Icons.edit_outlined,
                height: 30,
                onTap: () => _editCard(result, index),
              ),
            ],
          ),
          if (card.description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              card.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: appText(11.5, FontWeight.w400, p.textSecondary, height: 1.5),
            ),
          ],
          if (card.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final t in card.tags.take(5)) TagBadge(t)],
            ),
          ],
        ],
      ),
    );
  }

  Widget _loreTile(AppPalette p, GenResult result, int index) {
    final entry = result.lore[index];
    return Glass(
      radius: 18,
      blur: 18,
      shadow: false,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _check(p, entry.selected, () {
            final lore = [...result.lore];
            lore[index] = entry.copyWith(selected: !entry.selected);
            _gen.updateResult(GenResult(
              bookName: result.bookName,
              cards: result.cards,
              lore: lore,
              tokensUsed: result.tokensUsed,
              failedBlocks: result.failedBlocks,
              scannedBlocks: result.scannedBlocks,
              totalBlocks: result.totalBlocks,
            ));
          }),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appText(13, FontWeight.w600, p.textPrimary),
                      ),
                    ),
                    if (entry.constant)
                      TagBadge('常驻', color: p.amber),
                  ],
                ),
                if (entry.keys.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    entry.keys.take(6).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appText(10, FontWeight.w400, p.textTertiary),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  entry.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: appText(
                      11, FontWeight.w400, p.textSecondary, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Pressable(
            onTap: () => _editLore(result, index),
            child: Icon(Icons.edit_outlined, size: 16, color: p.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _check(AppPalette p, bool on, VoidCallback onTap) => Pressable(
        onTap: onTap,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: on ? p.amber : Colors.transparent,
            border: Border.all(
              color: on ? p.amber : p.textTertiary.withValues(alpha: .5),
              width: 1.4,
            ),
            borderRadius: BorderRadius.circular(7),
          ),
          child: on
              ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
              : null,
        ),
      );

  Future<void> _editCard(GenResult result, int index) async {
    final card = result.cards[index];
    final name = TextEditingController(text: card.name);
    final desc = TextEditingController(text: card.description);
    final personality = TextEditingController(text: card.personality);
    final scenario = TextEditingController(text: card.scenario);
    final greeting = TextEditingController(text: card.firstMes);
    final saved = await showTavernSheet<bool>(
      context,
      title: '编辑角色卡',
      subtitle: card.name,
      heightFactor: .88,
      child: Column(
        children: [
          _editField('名字', name),
          _editField('角色设定', desc, lines: 6),
          _editField('性格', personality, lines: 3),
          _editField('场景', scenario, lines: 2),
          _editField('开场白', greeting, lines: 6),
          const SizedBox(height: 12),
          GlassPrimaryButton(
            label: '保存修改',
            icon: Icons.check_rounded,
            onTap: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (saved == true) {
      final cards = [...result.cards];
      cards[index] = card.copyWith(
        name: name.text.trim(),
        description: desc.text,
        personality: personality.text,
        scenario: scenario.text,
        firstMes: greeting.text,
      );
      _gen.updateResult(GenResult(
        bookName: result.bookName,
        cards: cards,
        lore: result.lore,
        tokensUsed: result.tokensUsed,
        failedBlocks: result.failedBlocks,
        scannedBlocks: result.scannedBlocks,
        totalBlocks: result.totalBlocks,
      ));
    }
    name.dispose();
    desc.dispose();
    personality.dispose();
    scenario.dispose();
    greeting.dispose();
  }

  Future<void> _editLore(GenResult result, int index) async {
    final entry = result.lore[index];
    final name = TextEditingController(text: entry.name);
    final keys = TextEditingController(text: entry.keys.join(', '));
    final content = TextEditingController(text: entry.content);
    var constant = entry.constant;
    final saved = await showTavernSheet<bool>(
      context,
      title: '编辑世界书条目',
      subtitle: entry.name,
      heightFactor: .74,
      child: StatefulBuilder(
        builder: (context, setSheet) => Column(
          children: [
            _editField('条目名', name),
            _editField('触发关键词（逗号分隔）', keys, lines: 2),
            _editField('正文', content, lines: 6),
            const SizedBox(height: 8),
            SwitchLine(
              title: '常驻条目',
              subtitle: '不依赖关键词，始终注入',
              value: constant,
              onChanged: (v) => setSheet(() => constant = v),
            ),
            const SizedBox(height: 12),
            GlassPrimaryButton(
              label: '保存修改',
              icon: Icons.check_rounded,
              onTap: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      final lore = [...result.lore];
      lore[index] = entry.copyWith(
        name: name.text.trim(),
        keys: keys.text
            .split(RegExp(r'[,，]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        content: content.text,
        constant: constant,
      );
      _gen.updateResult(GenResult(
        bookName: result.bookName,
        cards: result.cards,
        lore: lore,
        tokensUsed: result.tokensUsed,
        failedBlocks: result.failedBlocks,
        scannedBlocks: result.scannedBlocks,
        totalBlocks: result.totalBlocks,
      ));
    }
    name.dispose();
    keys.dispose();
    content.dispose();
  }

  Widget _editField(String label, TextEditingController c, {int lines = 1}) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: appText(10.5, FontWeight.w500, p.textTertiary)),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: p.textPrimary.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: c,
              maxLines: lines,
              style: appText(13, FontWeight.w400, p.textPrimary, height: 1.5),
              cursorColor: p.amber,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  static String _duration(int ms) {
    final s = ms ~/ 1000;
    if (s < 60) return '${s}s';
    final m = s ~/ 60;
    if (m < 60) return '$m 分';
    return '${(m / 60).toStringAsFixed(1)} 时';
  }
}
