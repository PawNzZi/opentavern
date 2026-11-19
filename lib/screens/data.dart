import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/store.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';
import '../design/toast.dart';

class DataPage extends StatelessWidget {
  const DataPage({super.key});

  Future<void> _export(BuildContext context) async {
    final data = AppStore.instance.exportBackup();
    await Clipboard.setData(ClipboardData(text: data));
    if (!context.mounted) return;
    showTavernToast(context, '备份已复制到剪贴板');
  }

  Future<void> _import(BuildContext context) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null || data.text!.trim().isEmpty) {
      if (context.mounted) showTavernToast(context, '剪贴板里没有备份数据');
      return;
    }
    final ok = await AppStore.instance.importBackup(data.text!);
    if (!context.mounted) return;
    showTavernToast(context, ok ? '备份已恢复' : '备份格式不正确');
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final store = AppStore.instance;
    final backup = store.exportBackup();
    final kb = (backup.length / 1024).toStringAsFixed(1);
    return DetailPage(
      eyebrow: 'DATA & BACKUP',
      title: '数据与备份',
      subtitle: '所有数据都在本机；可完整导出与恢复。',
      children: [
        const SizedBox(height: 18),
        Glass(
          radius: 24,
          blur: 24,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '本地数据',
                    style: appText(14, FontWeight.w500, p.textPrimary),
                  ),
                  const Spacer(),
                  Text(
                    '$kb KB',
                    style: appText(15, FontWeight.w700, p.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 46,
                        child: ColoredBox(color: p.amber),
                      ),
                      Expanded(
                        flex: 24,
                        child: ColoredBox(
                          color: p.violet.withValues(alpha: .8),
                        ),
                      ),
                      Expanded(
                        flex: 18,
                        child: ColoredBox(
                          color: p.sage.withValues(alpha: .8),
                        ),
                      ),
                      Expanded(
                        flex: 12,
                        child: ColoredBox(
                          color: p.rose.withValues(alpha: .7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  _Legend(
                    color: p.amber,
                    label: '角色 ${store.characters.length}',
                  ),
                  _Legend(
                    color: p.violet,
                    label: '会话 ${store.sessions.length}',
                  ),
                  _Legend(
                    color: p.sage,
                    label: '世界书 ${store.lorebooks.length}',
                  ),
                  _Legend(
                    color: p.rose,
                    label: '预设 ${store.presets.length}',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SettingsGroup(
          title: '备份',
          children: [
            SettingRow(
              icon: Icons.upload_file_rounded,
              title: '导出完整备份',
              subtitle: '复制为 JSON，包含角色、聊天、世界书、预设与设置',
              value: '$kb KB',
              iconColor: p.amber,
              onTap: () => _export(context),
            ),
            const Hairline(indent: 56),
            SettingRow(
              icon: Icons.download_rounded,
              title: '从剪贴板恢复',
              subtitle: '会覆盖当前本地数据',
              value: 'JSON',
              iconColor: p.sage,
              onTap: () => _import(context),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SettingsGroup(
          title: '存储位置',
          children: const [
            SettingRow(
              icon: Icons.folder_outlined,
              title: '应用文档目录 / tavern',
              subtitle: 'characters.json · chats.json · settings.json',
              value: '本机',
              iconColor: Color(0xFFA9A0E8),
              onTap: null,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '备份是明文 JSON，只应在自己的设备之间传递。',
          style: appText(10.5, FontWeight.w400, p.textTertiary, height: 1.5),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: appText(10, FontWeight.w400, p.textTertiary)),
      ],
    );
  }
}
