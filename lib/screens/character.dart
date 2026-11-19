import 'package:flutter/material.dart';

import '../data/demo.dart';
import '../design/glass.dart';
import '../design/routes.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';
import '../design/toast.dart';
import 'character_editor.dart';
import 'chat.dart';

class CharacterScreen extends StatefulWidget {
  const CharacterScreen({
    super.key,
    required this.character,
    this.initialTab = 0,
  });

  final DemoCharacter character;
  final int initialTab;

  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  late int _tab = widget.initialTab;
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: widget.initialTab > 0 ? 520 : 0,
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final c = widget.character;
    final width = MediaQuery.sizeOf(context).width;
    return TavernScaffold(
      intensity: 1.2,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 410,
            child: Portrait(
              initial: c.initial,
              colors: c.colors,
              radius: 0,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 420,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      p.canvasTop.withValues(alpha: .15),
                      p.canvasTop.withValues(alpha: .86),
                      p.canvasTop,
                    ],
                    stops: const [0, .45, .82, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 150,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      p.canvasTop.withValues(alpha: .78),
                      p.canvasTop.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 292, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CHARACTER · V${c.version}',
                    style: appText(
                      10,
                      FontWeight.w600,
                      p.amber,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    c.name,
                    style: appText(
                      40,
                      FontWeight.w700,
                      p.textPrimary,
                      letterSpacing: -1.6,
                      height: 1.02,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'by ${c.creator} · ${c.title}',
                    style: appText(13, FontWeight.w400, p.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final t in c.tags) GlassPill(label: t, height: 30),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _Stats(character: c),
                  const SizedBox(height: 16),
                  GlassPrimaryButton(
                    label: '开始新对话',
                    icon: Icons.chat_bubble_outline_rounded,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(character: c),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Glass(
                          radius: 22,
                          blur: 20,
                          shadow: false,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          onTap: () {},
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history_rounded,
                                size: 15,
                                color: p.textSecondary,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                '继续上次对话',
                                style: appText(
                                  13,
                                  FontWeight.w500,
                                  p.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GlassCircleButton(
                        icon: Icons.edit_outlined,
                        size: 44,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CharacterEditorPage(
                                character: c,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DetailTabs(
                    index: _tab,
                    onChanged: (i) {
                      setState(() => _tab = i);
                      if (_scroll.hasClients) {
                        _scroll.animateTo(
                          520,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 6),
                  _tabContent(context, c, width),
                  const SizedBox(height: 28),
                  Center(
                    child: Text(
                      '导入于 2026 年 11 月 · ${c.tokens} tokens',
                      style: appText(10.5, FontWeight.w400, p.textTertiary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: SizedBox(
                      width: width * .3,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: p.textTertiary.withValues(alpha: .5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Row(
                children: [
                  GlassCircleButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    size: 40,
                    iconSize: 15,
                    onTap: () => Navigator.maybePop(context),
                  ),
                  const Spacer(),
                  GlassCircleButton(
                    icon: Icons.star_rounded,
                    size: 40,
                    iconSize: 18,
                    iconColor: p.amber,
                    tint: p.amber,
                    onTap: () => showTavernToast(context, '已收藏 ${c.name}'),
                  ),
                  const SizedBox(width: 8),
                  GlassCircleButton(
                    icon: Icons.more_horiz_rounded,
                    size: 40,
                    onTap: () => _showMore(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMore(BuildContext context) {
    final p = AppPalette.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .35),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Glass(
            radius: 26,
            blur: 34,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SettingRow(
                  icon: Icons.edit_outlined,
                  title: '编辑角色',
                  iconColor: p.amber,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    openGlassPage(
                      context,
                      CharacterEditorPage(character: widget.character),
                    );
                  },
                ),
                const Hairline(indent: 56),
                SettingRow(
                  icon: Icons.copy_rounded,
                  title: '复制角色',
                  iconColor: p.sage,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    showTavernToast(context, '已复制角色');
                  },
                ),
                const Hairline(indent: 56),
                SettingRow(
                  icon: Icons.ios_share_rounded,
                  title: '导出角色卡',
                  iconColor: p.violet,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    showTavernToast(context, '已导出 PNG');
                  },
                ),
                const Hairline(indent: 56),
                SettingRow(
                  icon: Icons.delete_outline_rounded,
                  title: '删除角色',
                  iconColor: p.danger,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    showTavernToast(context, '删除需要二次确认');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabContent(BuildContext context, DemoCharacter c, double width) {
    final p = AppPalette.of(context);
    switch (_tab) {
      case 1:
        return Column(
          key: const ValueKey(1),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('绑定的世界书'),
            Glass(
              radius: 22,
              blur: 22,
              padding: const EdgeInsets.all(13),
              onTap: () {},
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      gradient: LinearGradient(
                        colors: [
                          p.amber.withValues(alpha: .85),
                          p.rose.withValues(alpha: .5),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.auto_stories_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.lorebook,
                          style: appText(14, FontWeight.w600, p.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '24 条 · 更新于 2 天前 · 12.4k tokens',
                          style: appText(9.5, FontWeight.w400, p.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 17,
                    color: p.textTertiary,
                  ),
                ],
              ),
            ),
            SettingsGroup(
              title: '常驻条目',
              children: const [
                _LoreEntryRow(name: '王都的雨', keys: '王都 · 雨 · 预言'),
                Hairline(indent: 12),
                _LoreEntryRow(name: '星图与占星院', keys: '星图 · 占星 · 塔顶'),
                Hairline(indent: 12),
                _LoreEntryRow(name: '王都人物志', keys: '国王 · 公爵 · 使节'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                GlassPill(
                  label: '打开世界书',
                  icon: Icons.menu_book_rounded,
                  height: 36,
                ),
                SizedBox(width: 8),
                GlassPill(
                  label: '更换绑定',
                  icon: Icons.swap_horiz_rounded,
                  height: 36,
                ),
              ],
            ),
          ],
        );
      case 2:
        return Column(
          key: const ValueKey(2),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsGroup(
              title: '提示词与预设',
              children: [
                SettingRow(
                  icon: Icons.layers_outlined,
                  title: '默认预设',
                  value: c.preset,
                  iconColor: p.violet,
                  onTap: () {},
                ),
                const Hairline(indent: 56),
                SettingRow(
                  icon: Icons.subject_rounded,
                  title: '主提示词覆盖',
                  value: '已设置',
                  iconColor: p.amber,
                  onTap: () {},
                ),
                const Hairline(indent: 56),
                SettingRow(
                  icon: Icons.gavel_rounded,
                  title: 'Post-History Instructions',
                  value: '已设置',
                  iconColor: p.rose,
                  onTap: () {},
                ),
                const Hairline(indent: 56),
                SettingRow(
                  icon: Icons.vertical_align_bottom_rounded,
                  title: '@Depth 注入',
                  value: '深度 4 · 系统',
                  iconColor: p.sage,
                  onTap: () {},
                ),
              ],
            ),
            SettingsGroup(
              title: '角色正则',
              children: const [
                SettingRow(
                  icon: Icons.find_replace_rounded,
                  title: '名字修正',
                  value: '2 条脚本',
                  iconColor: Color(0xFFA9A0E8),
                  onTap: null,
                ),
                Hairline(indent: 56),
                SettingRow(
                  icon: Icons.add_rounded,
                  title: '添加角色正则',
                  value: '仅对当前角色生效',
                  iconColor: Color(0xFFF0B36A),
                  onTap: null,
                ),
              ],
            ),
          ],
        );
      case 3:
        return Column(
          key: const ValueKey(3),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Token 分布'),
            Glass(
              radius: 22,
              blur: 22,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                children: const [
                  _TokenBar(label: '描述', value: 186, ratio: .52, color: Color(0xFFF0B36A)),
                  SizedBox(height: 12),
                  _TokenBar(label: '示例对话', value: 640, ratio: .9, color: Color(0xFFA9A0E8)),
                  SizedBox(height: 12),
                  _TokenBar(label: '性格 + 场景', value: 116, ratio: .32, color: Color(0xFF8FD0BE)),
                  SizedBox(height: 12),
                  _TokenBar(label: '开场白', value: 64, ratio: .18, color: Color(0xFFEE9AA8)),
                ],
              ),
            ),
            SettingsGroup(
              title: '管理',
              children: [
                SettingRow(
                  icon: Icons.edit_outlined,
                  title: '编辑角色',
                  value: '全部字段',
                  iconColor: p.amber,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CharacterEditorPage(character: c),
                      ),
                    );
                  },
                ),
                const Hairline(indent: 56),
                SettingRow(
                  icon: Icons.copy_rounded,
                  title: '复制角色',
                  value: '含聊天目录',
                  iconColor: p.sage,
                  onTap: () {},
                ),
                const Hairline(indent: 56),
                SettingRow(
                  icon: Icons.ios_share_rounded,
                  title: '导出角色卡',
                  value: 'PNG / JSON',
                  iconColor: p.violet,
                  onTap: () {},
                ),
                const Hairline(indent: 56),
                SettingRow(
                  icon: Icons.delete_outline_rounded,
                  title: '删除角色',
                  value: '可选删除聊天',
                  iconColor: p.danger,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 8),
            Glass(
              radius: 20,
              blur: 20,
              shadow: false,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                children: [
                  _MetaRow(label: '创建者', value: c.creator),
                  const SizedBox(height: 7),
                  _MetaRow(label: '版本', value: 'v${c.version}'),
                  const SizedBox(height: 7),
                  _MetaRow(label: '创建时间', value: '2026-11-02'),
                  const SizedBox(height: 7),
                  _MetaRow(label: '文件', value: 'Seraphina.png · 1.2 MB'),
                ],
              ),
            ),
          ],
        );
      default:
        return Column(
          key: const ValueKey(0),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('角色设定'),
            Text(
              c.description,
              style: appText(
                14.5,
                FontWeight.w400,
                p.textSecondary,
                height: 1.65,
              ),
            ),
            const SectionLabel('开场白'),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: p.amber.withValues(alpha: .7),
                      width: 2,
                    ),
                  ),
                  color: Colors.white.withValues(alpha: p.isDark ? .03 : .25),
                ),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
                child: Text(
                  c.greeting,
                  style: appText(
                    14,
                    FontWeight.w400,
                    p.textPrimary,
                    height: 1.55,
                    style: FontStyle.italic,
                  ),
                ),
              ),
            ),
            const SectionLabel('已绑定'),
            Glass(
              radius: 22,
              blur: 24,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  SettingRow(
                    icon: Icons.auto_stories_rounded,
                    title: '世界书',
                    value: c.lorebook,
                    iconColor: p.sage,
                    onTap: () {},
                  ),
                  const Hairline(indent: 56),
                  SettingRow(
                    icon: Icons.tune_rounded,
                    title: '预设',
                    value: c.preset,
                    iconColor: p.violet,
                    onTap: () {},
                  ),
                  const Hairline(indent: 56),
                  SettingRow(
                    icon: Icons.record_voice_over_rounded,
                    title: '语音',
                    value: 'Aurora · ElevenLabs',
                    iconColor: p.rose,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        );
    }
  }
}

class _DetailTabs extends StatelessWidget {
  const _DetailTabs({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    const labels = ['概览', '世界书', '预设', '高级'];
    return Glass(
      radius: 15,
      blur: 18,
      shadow: false,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    color: i == index
                        ? p.amber.withValues(alpha: .18)
                        : Colors.transparent,
                    border: i == index
                        ? Border.all(
                            color: p.amber.withValues(alpha: .28),
                            width: .8,
                          )
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: appText(
                      12,
                      i == index ? FontWeight.w600 : FontWeight.w400,
                      i == index ? p.amber : p.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.character});

  final DemoCharacter character;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget cell(String value, String label) {
      return Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: appText(17, FontWeight.w600, p.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: appText(10, FontWeight.w400, p.textTertiary),
            ),
          ],
        ),
      );
    }

    return Glass(
      radius: 22,
      blur: 24,
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          cell('${character.chats}', '段对话'),
          Container(width: .6, height: 24, color: p.divider),
          cell(character.tokens, 'tokens'),
          Container(width: .6, height: 24, color: p.divider),
          cell('${character.tags.length}', '个标签'),
        ],
      ),
    );
  }
}

class _LoreEntryRow extends StatelessWidget {
  const _LoreEntryRow({required this.name, required this.keys});

  final String name;
  final String keys;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: p.sage.withValues(alpha: .14),
            ),
            child: Icon(
              Icons.bolt_rounded,
              size: 14,
              color: p.sage,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: appText(12.5, FontWeight.w500, p.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  keys,
                  style: appText(9, FontWeight.w400, p.textTertiary),
                ),
              ],
            ),
          ),
          const TagBadge('常驻', color: Color(0xFF8FD0BE)),
        ],
      ),
    );
  }
}

class _TokenBar extends StatelessWidget {
  const _TokenBar({
    required this.label,
    required this.value,
    required this.ratio,
    required this.color,
  });

  final String label;
  final int value;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: appText(10, FontWeight.w400, p.textSecondary),
          ),
        ),
        Expanded(
          child: ProgressLine(value: ratio, height: 5, color: color),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 34,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: appText(10, FontWeight.w600, p.textTertiary),
          ),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      children: [
        Text(
          label,
          style: appText(10.5, FontWeight.w400, p.textTertiary),
        ),
        const Spacer(),
        Text(
          value,
          style: appText(10.5, FontWeight.w500, p.textSecondary),
        ),
      ],
    );
  }
}
