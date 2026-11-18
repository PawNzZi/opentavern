import 'package:flutter/material.dart';

import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';

class MemoryPage extends StatelessWidget {
  const MemoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DetailPage(
      eyebrow: 'MEMORY & KNOWLEDGE',
      title: '记忆与知识',
      subtitle: '让角色记得更久，也让你上传的资料被看见。',
      children: [
        const SizedBox(height: 18),
        Glass(
          radius: 24,
          blur: 26,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      color: p.violet.withValues(alpha: .16),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 20,
                      color: p.violet,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '对话摘要',
                          style: appText(15, FontWeight.w600, p.textPrimary),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '已总结 12 段 · 最近更新 21:40',
                          style: appText(
                            10.5,
                            FontWeight.w400,
                            p.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const TavernSwitch(value: true),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '“Seraphina 在雨夜接待了旅人，提到王都的雨总在预言之后到来。她似乎知道旅人带来的坏消息是什么。”',
                style: appText(
                  12,
                  FontWeight.w400,
                  p.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const GlassPill(
                    label: '立即总结',
                    icon: Icons.refresh_rounded,
                    height: 34,
                  ),
                  const SizedBox(width: 8),
                  const GlassPill(
                    label: '查看全部',
                    icon: Icons.list_alt_rounded,
                    height: 34,
                  ),
                  const Spacer(),
                  Text(
                    '每 10 条',
                    style: appText(10.5, FontWeight.w500, p.textTertiary),
                  ),
                ],
              ),
            ],
          ),
        ),
        SettingsGroup(
          title: '摘要',
          children: const [
            SliderLine(
              title: '自动总结间隔',
              value: 10,
              min: 2,
              max: 50,
              divisions: 48,
              display: '每 10 条',
            ),
            SegmentLine(
              title: '注入位置',
              options: ['提示词内', '作者笔记上', '深度'],
              index: 2,
            ),
            StepperRow(
              title: '注入深度',
              subtitle: '数字越小越靠近最新消息',
              value: '2',
            ),
            SwitchLine(
              title: '总结后压缩历史',
              subtitle: '用摘要替代更早的消息，节省上下文',
              value: true,
            ),
          ],
        ),
        SettingsGroup(
          title: '向量记忆',
          footnote: '对历史消息做 Embedding，每轮按语义召回最相关的片段。',
          children: [
            SettingRow(
              icon: Icons.hub_outlined,
              title: '向量源',
              value: 'OpenAI',
              iconColor: p.amber,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.memory_rounded,
              title: '模型',
              value: 'text-embedding-3-small',
              iconColor: p.violet,
              onTap: () {},
            ),
            const Hairline(indent: 56),
            const SliderLine(
              title: '召回数量',
              value: 4,
              min: 1,
              max: 12,
              divisions: 11,
              display: 'Top 4',
            ),
            const SliderLine(
              title: '相似度阈值',
              value: .72,
              display: '0.72',
            ),
            SettingRow(
              icon: Icons.build_circle_outlined,
              title: '重建索引',
              value: '最近 24 段',
              iconColor: p.sage,
              onTap: () {},
            ),
          ],
        ),
        SettingsGroup(
          title: 'Data Bank（聊天附件）',
          trailing: Text(
            '3 个文件 · 4.2 MB',
            style: appText(10.5, FontWeight.w400, p.textTertiary),
          ),
          children: const [
            _AttachmentRow(
              name: 'Eldoria 设定集.pdf',
              meta: '1.8 MB · 128 个片段',
              icon: Icons.picture_as_pdf_rounded,
            ),
            Hairline(indent: 56),
            _AttachmentRow(
              name: '王都人物关系.txt',
              meta: '24 KB · 12 个片段',
              icon: Icons.description_rounded,
            ),
            Hairline(indent: 56),
            _AttachmentRow(
              name: '星象笔记.md',
              meta: '8 KB · 6 个片段',
              icon: Icons.code_rounded,
            ),
            Hairline(indent: 56),
            SettingRow(
              icon: Icons.add_rounded,
              title: '添加文件',
              value: 'PDF / TXT / DOCX',
              iconColor: Color(0xFFF0B36A),
              onTap: null,
            ),
          ],
        ),
        SettingsGroup(
          title: '上下文策略',
          children: const [
            SegmentLine(
              title: '超限处理',
              options: ['丢最旧', '摘要', '向量'],
              index: 1,
            ),
            StepperRow(
              title: '保留最近消息',
              subtitle: '始终不参与压缩',
              value: '40 条',
            ),
          ],
        ),
        const SizedBox(height: 18),
        const HintCard(
          text: '摘要保「剧情脉络」，向量保「细节事实」，Data Bank 保「外部资料」。三者可以同时开启，但会增加每轮请求的 token。',
          color: Color(0xFF8FD0BE),
        ),
      ],
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({
    required this.name,
    required this.meta,
    required this.icon,
  });

  final String name;
  final String meta;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: p.textTertiary.withValues(alpha: .12),
            ),
            child: Icon(icon, size: 16, color: p.textSecondary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appText(13, FontWeight.w500, p.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: appText(9.5, FontWeight.w400, p.textTertiary),
                ),
              ],
            ),
          ),
          Icon(
            Icons.more_horiz_rounded,
            size: 17,
            color: p.textTertiary,
          ),
        ],
      ),
    );
  }
}
