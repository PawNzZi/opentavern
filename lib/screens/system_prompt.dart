import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/prompt.dart';
import '../core/store.dart';
import '../data/demo.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';
import 'prompt_preview.dart';

class SystemPromptPage extends StatelessWidget {
  const SystemPromptPage({
    super.key,
    required this.character,
    required this.session,
  });

  final DemoCharacter character;
  final ChatSession session;

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
        .join('\n\n');
    return DetailPage(
      eyebrow: 'SYSTEM PROMPT',
      title: 'System Prompt',
      subtitle: '${character.name} · 约 ${estimateTokens(system)} tokens',
      children: [
        const SizedBox(height: 12),
        Glass(
          radius: 22,
          blur: 22,
          padding: const EdgeInsets.all(14),
          child: SelectableText(
            system.isEmpty ? '（空）' : system,
            style: appText(12, FontWeight.w400, p.textSecondary, height: 1.6),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: GlassPill(
            label: '查看完整构建顺序',
            icon: Icons.account_tree_outlined,
            height: 34,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PromptPreviewPage()),
            ),
          ),
        ),
      ],
    );
  }
}
