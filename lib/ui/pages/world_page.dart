/// 世界书详情：条目列表与增删改。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/tavern_card.dart';
import '../../core/store/tavern_store.dart';
import '../nav.dart';
import '../theme.dart';

const List<String> _positionLabels = <String>[
  '角色前',
  '角色后',
  '作者注上',
  '作者注下',
  '深度注入',
];

class WorldPage extends StatefulWidget {
  const WorldPage({super.key, required this.worldId});

  final String worldId;

  @override
  State<WorldPage> createState() => _WorldPageState();
}

class _WorldPageState extends State<WorldPage> {
  Map<String, dynamic>? _world;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => _world = TavernStore.instance.world(widget.worldId));
  }

  List<dynamic> get _entries {
    final Object? raw = _world?['entries'];
    return raw is List ? raw : <dynamic>[];
  }

  Future<void> _editEntry([Map? entry]) async {
    final Map<String, dynamic> draft = <String, dynamic>{
      'comment': '${entry?['comment'] ?? ''}',
      'keys': (entry?['keys'] is List ? entry!['keys'] as List : <dynamic>[]).join('，'),
      'content': '${entry?['content'] ?? ''}',
      'position': entry?['position'] ?? 0,
      'depth': entry?['depth'] ?? 4,
      'order': entry?['order'] ?? 100,
      'enabled': entry?['enabled'] != false,
      'constant': entry?['constant'] == true,
    };
    final Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext ctx) => _EntryDialog(initial: draft),
    );
    if (result == null) return;
    final Map? world = TavernStore.instance.mutable('worlds', widget.worldId);
    if (world == null) return;
    final List entries = world['entries'] is List ? world['entries'] as List : <dynamic>[];
    final Map<String, dynamic> record = <String, dynamic>{
      'id': '${entry?['id'] ?? 'e${DateTime.now().microsecondsSinceEpoch}'}',
      'comment': '${result['comment'] ?? ''}',
      'keys': (result['keys'] as String)
          .split(RegExp(r'[,，\n]'))
          .map((String item) => item.trim())
          .where((String item) => item.isNotEmpty)
          .toList(growable: false),
      'content': '${result['content'] ?? ''}',
      'position': result['position'],
      'depth': result['depth'],
      'order': result['order'],
      'enabled': result['enabled'],
      'constant': result['constant'],
      'selective': true,
      'role': 0,
    };
    if (entry == null) {
      entries.add(record);
    } else {
      final int index = entries.indexWhere((Object? item) => item is Map && '${item['id']}' == '${entry['id']}');
      if (index >= 0) {
        entries[index] = record;
      } else {
        entries.add(record);
      }
    }
    world['entries'] = entries;
    world['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    await TavernStore.instance.save();
    if (!mounted) return;
    _load();
  }

  Future<void> _deleteEntry(Map entry) async {
    final Map? world = TavernStore.instance.mutable('worlds', widget.worldId);
    if (world == null) return;
    final List entries = world['entries'] as List;
    entries.removeWhere((Object? item) => item is Map && '${item['id']}' == '${entry['id']}');
    await TavernStore.instance.save();
    if (!mounted) return;
    _load();
  }

  Future<void> _rename() async {
    final TextEditingController controller =
        TextEditingController(text: '${_world?['name'] ?? ''}');
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('重命名世界书', style: TavernText.title),
        content: TextField(controller: controller, autofocus: true),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('保存')),
        ],
      ),
    );
    if (ok != true) return;
    final Map? world = TavernStore.instance.mutable('worlds', widget.worldId);
    if (world == null) return;
    world['name'] = controller.text.trim().isEmpty ? '未命名世界书' : controller.text.trim();
    await TavernStore.instance.save();
    if (!mounted) return;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? world = _world;
    if (world == null) {
      return const Scaffold(
        backgroundColor: TavernColors.bg,
        body: Center(child: Text('世界书不存在')),
      );
    }
    return Scaffold(
      backgroundColor: TavernColors.bg,
      body: Column(
        children: <Widget>[
          NavBar(
            title: '${world['name'] ?? ''}',
            actions: <Widget>[
              IconButton(
                onPressed: () => unawaited(_rename()),
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: TavernColors.accent,
              ),
            ],
          ),
          Expanded(
            child: _entries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.book_outlined, size: 40, color: TavernColors.textFaint),
                        const SizedBox(height: 12),
                        const Text('还没有条目', style: TavernText.title),
                        const SizedBox(height: 6),
                        const Text('条目命中关键词时会注入到提示词里。', style: TavernText.caption),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    itemCount: _entries.length,
                    separatorBuilder: (BuildContext _, int _) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final Map entry = _entries[index] as Map;
                      final List<dynamic> keys = entry['keys'] is List ? entry['keys'] as List : <dynamic>[];
                      final int position = entry['position'] is num ? (entry['position'] as num).toInt() : 0;
                      final bool enabled = entry['enabled'] != false;
                      final bool constant = entry['constant'] == true;
                      return GestureDetector(
                        onTap: () => unawaited(_editEntry(entry)),
                        onLongPress: () => unawaited(_deleteEntry(entry)),
                        child: CardBox(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      '${entry['comment'] ?? ''}'.isEmpty
                                          ? (keys.isEmpty ? '未命名条目' : keys.join('、'))
                                          : '${entry['comment']}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TavernText.title,
                                    ),
                                  ),
                                  if (constant)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 6),
                                      child: Text('常驻', style: TavernText.tiny),
                                    ),
                                  if (!enabled)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 6),
                                      child: Text('已停用', style: TavernText.tiny),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${entry['content'] ?? ''}'.replaceAll('\n', ' '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TavernText.secondary,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${_positionLabels[position.clamp(0, 4)]} · 关键词 ${keys.join('、')}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TavernText.tiny,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: FilledButton.tonal(
                onPressed: () => unawaited(_editEntry()),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                child: const Text('新建条目'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryDialog extends StatefulWidget {
  const _EntryDialog({required this.initial});

  final Map<String, dynamic> initial;

  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  late final TextEditingController _comment;
  late final TextEditingController _keys;
  late final TextEditingController _content;
  late final TextEditingController _depth;
  late final TextEditingController _order;
  late int _position;
  late bool _enabled;
  late bool _constant;

  @override
  void initState() {
    super.initState();
    _comment = TextEditingController(text: '${widget.initial['comment'] ?? ''}');
    _keys = TextEditingController(text: '${widget.initial['keys'] ?? ''}');
    _content = TextEditingController(text: '${widget.initial['content'] ?? ''}');
    _depth = TextEditingController(text: '${widget.initial['depth'] ?? 4}');
    _order = TextEditingController(text: '${widget.initial['order'] ?? 100}');
    _position = widget.initial['position'] is num ? (widget.initial['position'] as num).toInt() : 0;
    _enabled = widget.initial['enabled'] != false;
    _constant = widget.initial['constant'] == true;
  }

  @override
  void dispose() {
    _comment.dispose();
    _keys.dispose();
    _content.dispose();
    _depth.dispose();
    _order.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('世界书条目', style: TavernText.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(controller: _comment, decoration: const InputDecoration(labelText: '备注')),
            TextField(controller: _keys, decoration: const InputDecoration(labelText: '关键词（逗号分隔）')),
            TextField(
              controller: _content,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(labelText: '内容'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _position,
              decoration: const InputDecoration(labelText: '注入位置'),
              items: <DropdownMenuItem<int>>[
                for (int i = 0; i < _positionLabels.length; i++)
                  DropdownMenuItem<int>(value: i, child: Text(_positionLabels[i])),
              ],
              onChanged: (int? value) => setState(() => _position = value ?? 0),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _depth,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '深度'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _order,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '顺序'),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用', style: TavernText.secondary),
              value: _enabled,
              onChanged: (bool value) => setState(() => _enabled = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('常驻（不匹配也注入）', style: TavernText.secondary),
              value: _constant,
              onChanged: (bool value) => setState(() => _constant = value),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(<String, dynamic>{
            'comment': _comment.text.trim(),
            'keys': _keys.text,
            'content': _content.text.trim(),
            'position': _position,
            'depth': int.tryParse(_depth.text) ?? 4,
            'order': int.tryParse(_order.text) ?? 100,
            'enabled': _enabled,
            'constant': _constant,
          }),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

/// 供其它页面读取书籍条目（预览用）。
List<TavernWorldEntry> worldEntriesOf(String worldId) {
  final Map<String, dynamic>? world = TavernStore.instance.world(worldId);
  if (world == null) return <TavernWorldEntry>[];
  return TavernWorld.fromJson(world).entries;
}
