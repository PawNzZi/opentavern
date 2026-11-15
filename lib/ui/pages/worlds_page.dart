/// 世界书列表：展示所有世界书（含角色卡内嵌导入的）。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/store/tavern_store.dart';
import '../nav.dart';
import '../theme.dart';
import '../toast.dart';
import 'world_page.dart';

class WorldsPage extends StatefulWidget {
  const WorldsPage({super.key});

  @override
  State<WorldsPage> createState() => _WorldsPageState();
}

class _WorldsPageState extends State<WorldsPage> {
  List<Map<String, dynamic>> _worlds = TavernStore.instance.worlds;

  void _refresh() {
    setState(() => _worlds = TavernStore.instance.worlds);
  }

  Future<void> _create() async {
    final TextEditingController controller = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('新建世界书', style: TavernText.title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '世界书名称'),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('创建')),
        ],
      ),
    );
    if (ok != true) return;
    final String name = controller.text.trim().isEmpty ? '未命名世界书' : controller.text.trim();
    final Map<String, dynamic> world = await TavernStore.instance.addWorld(name);
    if (!mounted) return;
    _refresh();
    await pushPage<void>(context, WorldPage(worldId: '${world['id']}'));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: <Widget>[
                const Expanded(child: Text('世界书', style: TavernText.largeTitle)),
                TextButton.icon(
                  onPressed: () => unawaited(_create()),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('新建'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _worlds.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.menu_book_outlined, size: 40, color: TavernColors.textFaint),
                        const SizedBox(height: 12),
                        const Text('还没有世界书', style: TavernText.title),
                        const SizedBox(height: 6),
                        const Text('角色卡里内嵌的世界书会在导入时自动带过来。', style: TavernText.caption),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    itemCount: _worlds.length,
                    separatorBuilder: (BuildContext _, int _) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final Map<String, dynamic> world = _worlds[index];
                      final List<dynamic> entries =
                          world['entries'] is List ? world['entries'] as List : <dynamic>[];
                      return GestureDetector(
                        onTap: () => unawaited(pushPage<void>(
                          context,
                          WorldPage(worldId: '${world['id']}'),
                        ).then((_) => _refresh())),
                        child: CardBox(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text('${world['name'] ?? ''}', style: TavernText.title),
                                    const SizedBox(height: 3),
                                    Text('${entries.length} 条目', style: TavernText.caption),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, size: 18, color: TavernColors.textFaint),
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

/// 删除世界书（供其它页面复用）。
Future<void> confirmDeleteWorld(BuildContext context, String worldId) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: const Text('删除世界书？', style: TavernText.title),
      content: const Text('其中的条目会一起删除。', style: TavernText.secondary),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('删除', style: TextStyle(color: TavernColors.danger)),
        ),
      ],
    ),
  );
  if (ok != true) return;
  await TavernStore.instance.deleteWorld(worldId);
  if (context.mounted) {
    showToast(context, '世界书已删除');
  }
}
