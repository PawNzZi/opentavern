import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/store.dart';
import 'design/glass.dart';
import 'design/scaffold.dart';
import 'design/theme.dart';
import 'screens/character.dart';
import 'screens/chat.dart';
import 'screens/chats.dart';
import 'screens/library.dart';
import 'screens/lore.dart';
import 'screens/settings.dart';
import 'screens/sheets.dart';
import 'screens/about.dart';
import 'screens/appearance.dart';
import 'screens/automation.dart';
import 'screens/character_editor.dart';
import 'screens/chat_info.dart';
import 'screens/editors.dart';
import 'screens/connection.dart';
import 'screens/data.dart';
import 'screens/generation.dart';
import 'screens/interaction.dart';
import 'screens/media.dart';
import 'screens/memory.dart';
import 'screens/presets.dart';
import 'screens/prompts.dart';
import 'screens/search.dart';
import 'screens/stats.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStore.instance.init();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  runApp(const TavernApp());
}

class TavernApp extends StatelessWidget {
  const TavernApp({super.key});

  @override
  Widget build(BuildContext context) {
    final params = Uri.base.queryParameters;
    final screen = params['screen'] ?? 'home';
    final light = params['theme'] == 'light';

    return MaterialApp(
      title: '酒馆',
      debugShowCheckedModeBanner: false,
      theme: buildTavernTheme(dark: false),
      darkTheme: buildTavernTheme(dark: true),
      themeMode: light ? ThemeMode.light : ThemeMode.dark,
      scrollBehavior: const _TavernScrollBehavior(),
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        Widget content = child ?? const SizedBox.shrink();
        if (kIsWeb && params['insets'] != '0') {
          final mq = MediaQuery.of(context);
          content = MediaQuery(
            data: mq.copyWith(
              padding: mq.padding.copyWith(top: 59, bottom: 34),
              viewPadding: mq.viewPadding.copyWith(top: 59, bottom: 34),
            ),
            child: content,
          );
          content = Stack(
            children: [
              content,
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _WebStatusBar(dark: dark),
              ),
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 134,
                      height: 5,
                      decoration: BoxDecoration(
                        color: (dark ? Colors.white : Colors.black)
                            .withValues(alpha: dark ? .55 : .28),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark)
              .copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
              ),
          child: content,
        );
      },
      home: _screenFor(screen, params),
    );
  }

  Widget _screenFor(String screen, Map<String, String> params) {
    switch (screen) {
      case 'chat':
        if (AppStore.instance.characters.isEmpty) {
          return const CharacterEditorPage();
        }
        return ChatScreen(
          character: AppStore.instance.characters.first,
          autoDemo: false,
        );
      case 'persona':
        return const PersonaEditorSheet();
      case 'regex':
        return const RegexEditorSheet();
      case 'quickreply':
        return const QuickReplyEditorSheet();
      case 'promptedit':
        return const PromptEditorSheet();
      case 'authornote':
        return const AuthorNoteSheet();
      case 'chatmenu':
        if (AppStore.instance.characters.isEmpty) {
          return const CharacterEditorPage();
        }
        return ChatScreen(
          character: AppStore.instance.characters.first,
          showMessageMenu: true,
        );
      case 'chatinfo':
        if (AppStore.instance.characters.isEmpty) {
          return const CharacterEditorPage();
        }
        final infoCharacter = AppStore.instance.characters.first;
        return ChatInfoSheet(
          session: AppStore.instance.sessionFor(infoCharacter),
          character: infoCharacter,
        );
      case 'character':
        if (AppStore.instance.characters.isEmpty) {
          return const CharacterEditorPage();
        }
        return CharacterScreen(
          character: AppStore.instance.characters.first,
          initialTab: int.tryParse(params['tab'] ?? '0') ?? 0,
        );
      case 'editor':
        return const CharacterEditorPage();
      case 'prompts':
        return const PromptManagerPage();
      case 'presets':
        return const PresetsPage();
      case 'generation':
        return const GenerationPage();
      case 'connection':
        return const ConnectionPage();
      case 'memory':
        return const MemoryPage();
      case 'media':
        return const MediaPage();
      case 'interaction':
        return const InteractionPage();
      case 'automation':
        return const AutomationPage();
      case 'appearance':
        return const AppearancePage();
      case 'data':
        return const DataPage();
      case 'stats':
        return const StatsPage();
      case 'about':
        return const AboutPage();
      case 'search':
        return const SearchPage();
      case 'lore':
        return const LoreScreen();
      case 'connect':
        return const ConnectSheetScreen();
      case 'import':
        return const ImportSheetScreen();
      case 'loreentry':
        return const LoreEntrySheetScreen();
      case 'chats':
        return const RootShell(initialTab: 1);
      case 'settings':
        return const RootShell(initialTab: 2);
      default:
        return const RootShell();
    }
  }
}

class _WebStatusBar extends StatelessWidget {
  const _WebStatusBar({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = dark ? Colors.white : Colors.black;
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 12, 30, 0),
        child: SizedBox(
          height: 30,
          child: Row(
            children: [
              Text(
                '21:41',
                style: appText(13.5, FontWeight.w600, color),
              ),
              const Spacer(),
              Icon(
                Icons.signal_cellular_alt_rounded,
                size: 15,
                color: color,
              ),
              const SizedBox(width: 5),
              Icon(Icons.wifi_rounded, size: 15, color: color),
              const SizedBox(width: 7),
              Container(
                width: 23,
                height: 11,
                padding: const EdgeInsets.all(1.6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: color.withValues(alpha: .55),
                    width: 1,
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 14,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(1.4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TavernScrollBehavior extends MaterialScrollBehavior {
  const _TavernScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  late int _index = widget.initialTab;

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return TavernScaffold(
      bottomNavigation: GlassTabBar(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
        tint: p.isDark ? const Color(0xFF0A0C12) : Colors.white,
        tintStrength: p.isDark ? .58 : .18,
        fill: 1.35,
        tabs: const [
          TabSpec(Icons.auto_awesome_mosaic_rounded, '角色'),
          TabSpec(Icons.forum_rounded, '对话'),
          TabSpec(Icons.tune_rounded, '设置'),
        ],
      ),
      child: IndexedStack(
        index: _index,
        children: [
          LibraryScreen(
            onOpenCharacter: (c) => _push(CharacterScreen(character: c)),
            onOpenChat: (c) => _push(ChatScreen(character: c)),
            onImport: () => _push(const ImportSheetScreen()),
          ),
          ChatsScreen(
            onOpenChat: (chat) => _push(
              ChatScreen(
                character: chat.character,
                sessionId: chat.sessionId,
              ),
            ),
            onSearch: () => _push(const SearchPage()),
          ),
          SettingsScreen(
            onOpenConnect: () => _push(const ConnectionPage()),
          ),
        ],
      ),
    );
  }
}
