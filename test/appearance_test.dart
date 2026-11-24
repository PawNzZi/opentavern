import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/design/theme.dart';

void main() {
  test('appearance defaults are dark / amber / 15 with avatar and time on', () {
    const s = AppSettings();
    expect(s.themeMode, 'dark');
    expect(s.accent, 'amber');
    expect(s.chatFontSize, 15);
    expect(s.showAvatar, true);
    expect(s.showTimestamp, true);
  });

  test('appearance settings round-trip through JSON', () {
    const s = AppSettings();
    final updated = s.copyWith(
      themeMode: 'light',
      accent: 'sage',
      chatFontSize: 18,
      showAvatar: false,
      showTimestamp: false,
    );
    final back = AppSettings.fromJson(updated.toJson());
    expect(back.themeMode, 'light');
    expect(back.accent, 'sage');
    expect(back.chatFontSize, 18);
    expect(back.showAvatar, false);
    expect(back.showTimestamp, false);
  });

  test('fromJson normalizes invalid theme/accent and clamps font size', () {
    final s = AppSettings.fromJson({
      'themeMode': 'neon',
      'accent': 'gold',
      'chatFontSize': 99,
    });
    expect(s.themeMode, 'dark');
    expect(s.accent, 'amber');
    expect(s.chatFontSize, 20);

    final low = AppSettings.fromJson({'chatFontSize': 3});
    expect(low.chatFontSize, 12);
  });

  test('legacy settings without appearance keys keep defaults', () {
    final s = AppSettings.fromJson({'personaName': '旅人'});
    expect(s.themeMode, 'dark');
    expect(s.accent, 'amber');
    expect(s.chatFontSize, 15);
    expect(s.showAvatar, true);
    expect(s.showTimestamp, true);
  });

  test('applyAccent keeps amber unchanged and recolors other accents', () {
    expect(applyAccent(AppPalette.dark, 'amber'), same(AppPalette.dark));
    expect(applyAccent(AppPalette.light, 'amber'), same(AppPalette.light));

    final rose = applyAccent(AppPalette.dark, 'rose');
    expect(rose.amber, isNot(AppPalette.dark.amber));
    expect(rose.userBubbleStart, isNot(AppPalette.dark.userBubbleStart));
    // Non-accent surfaces stay put.
    expect(rose.canvasTop, AppPalette.dark.canvasTop);
    expect(rose.textPrimary, AppPalette.dark.textPrimary);

    final sage = applyAccent(AppPalette.dark, 'sage');
    final violet = applyAccent(AppPalette.dark, 'violet');
    expect(sage.amber, isNot(rose.amber));
    expect(violet.amber, isNot(sage.amber));
  });
}
