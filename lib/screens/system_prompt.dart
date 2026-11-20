import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import '../core/prompt.dart';
import '../core/store.dart';
import '../data/demo.dart';
import '../design/glass.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';
import '../design/toast.dart';
import 'prompt_preview.dart';

class SystemPromptPage extends StatelessWidget {
  const SystemPromptPage({
    super.key,
    required this.character,
    required this.session,
  });

  final DemoCharacter character;
  final ChatSession session;

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) showTavernToast(context, 'System Prompt 已复制');
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final built = PromptBuilder.build(
      character: character,
      session: session,
      settings: AppStore.instance.settings,
    );
    final system = built.messages
        .where((m) => m['role'] == 'system')
        .map((m) => m['content']?.toString() ?? '')
        .where((text) => text.trim().isNotEmpty)
        .join('\n\n');
    return DetailPage(
      eyebrow: 'SYSTEM PROMPT',
      title: 'System Prompt',
      subtitle: '${character.name} · 约 ${estimateTokens(system)} tokens',
      children: [
        const SizedBox(height: 12),
        // 用 SelectionArea + Text 代替 SelectableText：文本可以长按 / 拖拽选中
        // 复制，但不会吞掉竖向拖动，父级 ListView 能正常上下滚动。
        Glass(
          radius: 22,
          blur: 22,
          padding: const EdgeInsets.all(14),
          child: SelectionArea(
            child: Text(
              system.isEmpty ? '（空）' : system,
              style: appText(12, FontWeight.w400, p.textSecondary, height: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            GlassPill(
              label: '复制',
              icon: Icons.copy_rounded,
              height: 34,
              onTap: () => _copy(context, system),
            ),
            GlassPill(
              label: '查看完整构建顺序',
              icon: Icons.account_tree_outlined,
              height: 34,
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const PromptPreviewPage()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
