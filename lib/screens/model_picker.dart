import 'package:flutter/material.dart';

import '../core/llm.dart';
import '../core/models.dart';
import '../design/scaffold.dart';
import '../design/theme.dart';

/// 弹出模型选择器：按 [api] 拉取该服务商的模型列表，支持本地模糊搜索，
/// 返回选中的模型名（取消返回 null）。
Future<String?> showModelPicker(
  BuildContext context, {
  required APISettings api,
  String current = '',
  String subtitle = '选择模型',
}) {
  return showTavernSheet<String>(
    context,
    title: '选择模型',
    subtitle: subtitle,
    heightFactor: .68,
    child: _ModelPickerBody(api: api, current: current),
  );
}

class _ModelPickerBody extends StatefulWidget {
  const _ModelPickerBody({required this.api, required this.current});

  final APISettings api;
  final String current;

  @override
  State<_ModelPickerBody> createState() => _ModelPickerBodyState();
}

class _ModelPickerBodyState extends State<_ModelPickerBody> {
  final _search = TextEditingController();
  List<String> _models = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final models = await LLMClient().fetchModels(widget.api);
      if (!mounted) return;
      final unique = models.toSet().toList()..sort();
      setState(() {
        _models = unique;
        _loading = false;
        _error = unique.isEmpty ? '服务商没有返回可用模型' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _models = const [];
        _error = e is LLMException ? e.message : '$e';
      });
    }
  }

  List<String> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _models;
    final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    return _models.where((m) {
      final lower = m.toLowerCase();
      return tokens.every((t) => lower.contains(t));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final filtered = _filtered;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .46,
      child: Column(
        children: [
          if (!_loading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: p.textPrimary.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 16, color: p.textTertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      style: appText(13, FontWeight.w400, p.textPrimary),
                      cursorColor: p.amber,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: '搜索模型…',
                        hintStyle:
                            appText(12.5, FontWeight.w400, p.textTertiary),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  if (_search.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _search.clear();
                        setState(() {});
                      },
                      child: Icon(Icons.close_rounded,
                          size: 16, color: p.textTertiary),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '正在获取模型…',
                          style: appText(12, FontWeight.w400, p.textTertiary),
                        ),
                      ],
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cloud_off_rounded,
                                  size: 26, color: p.textTertiary),
                              const SizedBox(height: 10),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: appText(12.5, FontWeight.w400,
                                    p.textSecondary),
                              ),
                              const SizedBox(height: 12),
                              _RetryButton(onTap: _fetch),
                            ],
                          ),
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Text(
                              '没有匹配的模型',
                              style: appText(12, FontWeight.w400,
                                  p.textTertiary),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            physics: const BouncingScrollPhysics(),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final model = filtered[i];
                              final selected = model == widget.current;
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () =>
                                    Navigator.of(context).pop(model),
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(
                                      14, 12, 14, 12),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                          color: p.divider, width: .6),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          model,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: appText(
                                            13.5,
                                            selected
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            selected
                                                ? p.amber
                                                : p.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (selected)
                                        Icon(Icons.check_rounded,
                                            size: 18, color: p.amber),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: p.amber.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '重试',
          style: appText(12.5, FontWeight.w600, p.amber),
        ),
      ),
    );
  }
}
