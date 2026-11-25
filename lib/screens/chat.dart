import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat/chat_controller.dart';
import '../core/docx_text.dart';
import '../core/macros.dart';
import '../core/models.dart';
import '../core/pdf_text.dart';
import '../core/regex.dart';
import '../core/statusbar.dart';
import '../core/store.dart';
import '../data/demo.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/theme.dart';
import '../design/toast.dart';
import 'chat_info.dart';
import 'status_bar.dart';

String _renderDisplayText(ChatMessage message, String characterName) {
  if (message.text.isEmpty) return message.text;
  // 聊天气泡以原文存储，渲染时才展开身份宏：{{user}} / {{char}} 不会在
  // 界面上露出占位符，同时也不会像 prompt 那样重掷 {{random}} / {{time}}。
  final settings = AppStore.instance.settings;
  final userName = settings.userName.trim().isNotEmpty
      ? settings.userName.trim()
      : settings.personaName.trim().isNotEmpty
          ? settings.personaName.trim()
          : 'User';
  // 状态栏单独渲染：正文里若带状态块，显示时剥离，只留内容（含卡自带规则）。
  final cleaned = StatusBar.strip(
    message.text,
    cardPatterns: StatusBar.patternsForCharacterName(characterName),
  );
  final expanded = MacroEngine.expandIdentity(
    cleaned,
    charName: characterName,
    userName: userName,
  );
  return applyRegexScripts(
    expanded,
    AppStore.instance.regexScripts,
    stage: 'display',
    characterName: characterName,
  );
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.character,
    this.standalone = true,
    this.showMessageMenu = false,
    this.autoDemo = false,
    this.sessionId,
    this.newSession = false,
    this.initialGreeting,
  });

  final DemoCharacter character;
  final bool standalone;
  final bool showMessageMenu;
  final bool autoDemo;
  final String? sessionId;
  final bool newSession;
  final String? initialGreeting;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatController _chat;
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();
  bool _hasText = false;
  final _pending = <ChatAttachment>[];
  late final Map<String, num> _statusRanges;

  @override
  void initState() {
    super.initState();
    final session = widget.sessionId != null
        ? AppStore.instance.sessionById(widget.sessionId)
        : widget.newSession
            ? AppStore.instance.createSession(
                widget.character,
                greeting: widget.initialGreeting,
              )
            : null;
    _chat = ChatController(character: widget.character, session: session);
    _chat.addListener(_onChatChanged);
    AppStore.instance.addListener(_onStoreChanged);
    final rules = StatusBar.findRulesContent(widget.character);
    _statusRanges = rules == null ? const {} : StatusBar.parseRanges(rules);
    if (widget.autoDemo) {
      Timer(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        _chat.send('如果我说，我就是那个坏消息呢？');
      });
    }
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  void _onChatChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _chat.removeListener(_onChatChanged);
    AppStore.instance.removeListener(_onStoreChanged);
    _chat.dispose();
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// 在光标处插入成对符号（如 “” / （）），并把光标放到两者中间，方便直接输入。
  void _insertPair(String open, String close) {
    final text = _input.text;
    final sel = _input.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final newText = text.replaceRange(start, end, '$open$close');
    final caret = start + open.length;
    _input.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: caret),
      composing: TextRange.empty,
    );
    setState(() => _hasText = newText.trim().isNotEmpty);
    _inputFocus.requestFocus();
  }

  void _send() {
    final text = _input.text;
    if ((text.trim().isEmpty && _pending.isEmpty) || _chat.isGenerating) return;
    final attachments = [..._pending];
    _input.clear();
    setState(() {
      _hasText = false;
      _pending.clear();
    });
    HapticFeedback.lightImpact();
    _chat.send(text, attachments: attachments);
  }

  void _openInfo() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ChatInfoSheet(
          session: _chat.session,
          character: widget.character,
          onSummarize: _chat.summarizeNow,
        ),
      ),
    );
  }

  Future<void> _pickFile(BuildContext sheetContext) async {
    final file = await FilePickerPlatform.instance.pickFile();
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final name = file.name;
    final ext = name.split('.').last.toLowerCase();
    const textExts = {'txt', 'md', 'markdown', 'json', 'csv', 'yaml', 'yml', 'log'};
    String? text;
    if (ext == 'docx') {
      text = extractDocxText(bytes);
      if (text == null) {
        _toast('无法读取 DOCX 文本');
        return;
      }
    } else if (ext == 'pdf') {
      text = extractPdfText(bytes);
      if (text == null) {
        _toast('无法读取 PDF 文本（可能是扫描件）');
        return;
      }
    } else if (textExts.contains(ext)) {
      text = utf8.decode(bytes, allowMalformed: true).trim();
    } else {
      _toast('目前支持 TXT / MD / JSON / CSV / DOCX / PDF');
      return;
    }
    var content = text;
    if (content.length > 20000) content = content.substring(0, 20000);
    if (!mounted) return;
    setState(() {
      _hasText = true;
      _pending.add(
        ChatAttachment(
          id: 'att-${DateTime.now().microsecondsSinceEpoch}',
          name: name,
          mime: 'text/plain',
          text: content,
        ),
      );
    });
  }

  Future<void> _pickImage(BuildContext sheetContext) async {
    final file = await FilePickerPlatform.instance.pickFile();
    if (file == null) return;
    final bytes = await file.readAsBytes();
    String encoded;
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 1024,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      encoded = data == null
          ? base64Encode(bytes)
          : base64Encode(data.buffer.asUint8List());
    } catch (_) {
      encoded = base64Encode(bytes);
    }
    if (!mounted) return;
    setState(() {
      _hasText = true;
      _pending.add(
        ChatAttachment(
          id: 'att-${DateTime.now().microsecondsSinceEpoch}',
          name: file.name,
          mime: 'image/png',
          base64: encoded,
        ),
      );
    });
  }

  void _openAttachments() {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭添加内容',
      barrierColor: Colors.black.withValues(alpha: .46),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, _, _) => _AttachmentMenu(
        onImage: () {
          Navigator.of(dialogContext).pop();
          _pickImage(context);
        },
        onFile: () {
          Navigator.of(dialogContext).pop();
          _pickFile(context);
        },
      ),
    );
  }

  void _toast(String text) {
    showTavernToast(context, text);
  }

  void _showMessageMenu(ChatMessage message) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭消息操作',
      barrierColor: Colors.black.withValues(alpha: .46),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, _) => _MessageMenu(
        name: widget.character.name,
        message: message,
        onAction: (action) {
          Navigator.of(dialogContext).pop();
          _handleMenuAction(action, message);
        },
      ),
      transitionBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, .06),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  void _handleMenuAction(String action, ChatMessage message) {
    switch (action) {
      case '复制':
        Clipboard.setData(
          ClipboardData(
            text: _renderDisplayText(message, widget.character.name),
          ),
        );
        _toast('已复制');
      case '编辑':
        _editMessage(message);
      case '隐藏':
        _chat.toggleHidden(message);
        _toast(message.hidden ? '已隐藏，不进入上下文' : '已恢复显示');
      case '删除':
        _chat.delete(message);
        _toast('已删除');
      case '书签':
        _chat.toggleBookmark(message);
        _toast(message.bookmarked ? '已添加书签' : '已移除书签');
      case '分支':
        final branch = _chat.branchAt(message);
        _toast(branch == null ? '无法创建分支' : '已创建分支：${branch.title}');
      case '从书签继续':
        _continueFromBookmark(message);
      case '删除后续':
        _confirmDeleteAfter(message);
      case '从此重写':
        _chat.regenerateFrom(message);
        _toast('将从这条消息重新生成');
      case '查看推理':
        _showReasoning(message);
    }
  }

  /// Branches the session at [message] and opens the new branch chat.
  void _continueFromBookmark(ChatMessage message) {
    if (!message.bookmarked) {
      _toast('该消息还不是书签');
      return;
    }
    final branch = _chat.branchAt(message);
    if (branch == null) {
      _toast('无法创建分支');
      return;
    }
    _toast('已创建分支：${branch.title}');
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => ChatScreen(
          character: widget.character,
          sessionId: branch.id,
        ),
      ),
    );
  }

  /// Shows the model reasoning behind [message], or explains that there is none.
  void _showReasoning(ChatMessage message) {
    final reasoning = message.reasoning?.trim() ?? '';
    if (reasoning.isEmpty) {
      _toast('没有推理内容');
      return;
    }
    final p = AppPalette.of(context);
    showTavernSheet<void>(
      context,
      title: '推理过程',
      subtitle: '${widget.character.name} · ${message.time ?? '刚刚'}',
      heightFactor: .72,
      child: Glass(
        radius: 18,
        blur: 18,
        shadow: false,
        padding: const EdgeInsets.all(14),
        child: SelectableText(
          reasoning,
          style: appText(13, FontWeight.w400, p.textSecondary, height: 1.6),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAfter(ChatMessage message) async {
    final index = _chat.messages.indexOf(message);
    final count = _chat.messages.length - index - 1;
    if (index < 0 || count <= 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除后续消息'),
        content: Text('将删除这条消息之后的 $count 条消息，不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      _chat.deleteAfter(message);
      _toast('已删除后续消息');
    }
  }

  Future<void> _askAfterEdit(ChatMessage message) async {
    final index = _chat.messages.indexOf(message);
    final later = _chat.messages.length - index - 1;
    if (later <= 0) return;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑后如何处理后续消息？'),
        content: Text('这条消息之后还有 $later 条消息。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'keep'),
            child: const Text('保留'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: const Text('删除后续'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'branch'),
            child: const Text('另存分支'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'delete':
        _chat.deleteAfter(message);
        _toast('已删除后续消息');
      case 'branch':
        final branch = _chat.branchAt(message);
        _toast(branch == null ? '无法创建分支' : '已保存分支：${branch.title}');
      default:
        break;
    }
  }

  Future<void> _editMessage(ChatMessage message) async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .46),
      builder: (_) => _EditMessageSheet(initial: message.text),
    );
    if (text == null) return;
    final wasLast = _chat.messages.isNotEmpty &&
        _chat.messages.last.id == message.id;
    _chat.edit(message, text);
    _toast('已保存');
    if (!wasLast) await _askAfterEdit(message);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final c = widget.character;
    return AnimatedBuilder(
      animation: _chat,
      builder: (context, _) {
        final quick = AppStore.instance.activeQuickSet;
        final typing = _chat.isGenerating &&
            (_chat.streamingMessage?.text.isEmpty ?? false);
        final items = <Widget>[];
        if (typing) {
          items.add(_TypingRow(character: c));
          items.add(const SizedBox(height: 14));
        }
        for (var i = _chat.messages.length - 1; i >= 0; i--) {
          final message = _chat.messages[i];
          final isLast = i == _chat.messages.length - 1;
          if (message.text.isEmpty &&
              _chat.streamingMessage?.id == message.id) {
            continue;
          }
          items.add(
            _MessageEntrance(
              key: ValueKey(message.id),
              child: message.isUser
                  ? _UserMessage(
                      message: message,
                      characterName: c.name,
                      onLongPress: () => _showMessageMenu(message),
                    )
                  : _CharacterMessage(
                      message: message,
                      character: c,
                      isLast: isLast,
                      streaming: _chat.streamingMessage == message,
                      onLongPress: () => _showMessageMenu(message),
                      onReasoning: () => _showReasoning(message),
                      onSwipe: _chat.swipe,
                      onContinue: _chat.continueLast,
                      onRegenerate: _chat.regenerate,
                      onSpeak: () => _toast('正在朗读…'),
                    ),
            ),
          );
          items.add(const SizedBox(height: 14));
        }
        items.add(
          Row(
            children: [
              Expanded(child: Container(height: .6, color: p.divider)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '今天 · ${DateTime.now().month} 月 ${DateTime.now().day} 日',
                  style: appText(
                    10,
                    FontWeight.w500,
                    p.textTertiary,
                    letterSpacing: .4,
                  ),
                ),
              ),
              Expanded(child: Container(height: .6, color: p.divider)),
            ],
          ),
        );

        return TavernScaffold(
          intensity: 1.15,
          resizeToAvoidBottomInset: true,
          child: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                      child: _ChatTopBar(
                        character: c,
                        generating: _chat.isGenerating,
                        onMore: _openInfo,
                      ),
                    ),
                    if (_chat.session.statData.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                        child: StatusBarPanel(
                          data: _chat.session.statData,
                          ranges: _statusRanges,
                        ),
                      ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => FocusScope.of(context).unfocus(),
                        child: ListView(
                          reverse: true,
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          physics: const BouncingScrollPhysics(),
                          children: items,
                        ),
                      ),
                    ),
                    if (_pending.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: SizedBox(
                          height: 60,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _pending.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final att = _pending[i];
                              return Stack(
                                children: [
                                  if (!att.isImage)
                                    Container(
                                      width: 150,
                                      height: 60,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: p.textPrimary.withValues(alpha: .06),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.description_outlined, size: 18, color: p.amber),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              att.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: appText(10.5, FontWeight.w500, p.textPrimary),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.memory(
                                        base64Decode(att.base64),
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: GestureDetector(
                                      onTap: () => setState(() => _pending.removeAt(i)),
                                      child: Container(
                                        width: 18,
                                        height: 18,
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    if (quick != null && quick.replies.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: SizedBox(
                          height: 34,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: quick.replies.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 7),
                            itemBuilder: (context, i) {
                              final reply = quick.replies[i];
                              return GlassPill(
                                label: reply.label,
                                height: 32,
                                onTap: () {
                                  if (_chat.isGenerating) return;
                                  FocusScope.of(context).unfocus();
                                  _input.text = reply.message;
                                  setState(() => _hasText = true);
                                  _send();
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: Row(
                        children: [
                          GlassPill(
                            label: '“” 发言',
                            icon: Icons.format_quote_rounded,
                            height: 30,
                            onTap: () => _insertPair('“', '”'),
                          ),
                          const SizedBox(width: 7),
                          GlassPill(
                            label: '（） 环境',
                            icon: Icons.theater_comedy_outlined,
                            height: 30,
                            onTap: () => _insertPair('（', '）'),
                          ),
                        ],
                      ),
                    ),
                    _Composer(
                      character: c,
                      controller: _input,
                      focusNode: _inputFocus,
                      hasText: _hasText,
                      generating: _chat.isGenerating,
                      onChanged: (value) {
                        final has = value.trim().isNotEmpty;
                        if (has != _hasText) {
                          setState(() => _hasText = has);
                        }
                      },
                      onSend: _send,
                      onStop: _chat.stop,
                      onAttach: _openAttachments,
                      onVoice: () => _toast('按住说话'),
                    ),
                  ],
                ),
              ),
              if (widget.showMessageMenu && _chat.messages.isNotEmpty)
                _StaticMessageMenu(
                  name: c.name,
                  message: _chat.messages.last,
                  onClose: () {},
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageEntrance extends StatelessWidget {
  const _MessageEntrance({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _ChatTopBar extends StatelessWidget {
  const _ChatTopBar({
    required this.character,
    required this.generating,
    required this.onMore,
  });

  final DemoCharacter character;
  final bool generating;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Glass(
      radius: 24,
      blur: 28,
      padding: const EdgeInsets.fromLTRB(7, 7, 9, 7),
      child: Row(
        children: [
          GlassCircleButton(
            icon: Icons.arrow_back_ios_new_rounded,
            size: 38,
            iconSize: 15,
            blur: 0,
            onTap: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            height: 36,
            child: Portrait(
              initial: character.initial,
              colors: character.colors,
              avatarBase64: character.avatarBase64,
              radius: 12,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  character.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appText(
                    14.5,
                    FontWeight.w600,
                    p.textPrimary,
                    letterSpacing: -.2,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: generating
                            ? p.amber
                            : (AppStore.instance.settings.api.configured
                                ? p.sage
                                : p.danger),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      generating
                          ? '正在生成…'
                          : (AppStore.instance.settings.api.configured
                              ? '在线'
                              : '离线'),
                      style: appText(10, FontWeight.w500, p.amber),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Glass(
            radius: 12,
            blur: 16,
            shadow: false,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 11, color: p.amber),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 112),
                  child: Text(
                    AppStore.instance.settings.api.model.trim().isEmpty
                        ? '未配置模型'
                        : AppStore.instance.settings.api.model,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appText(10, FontWeight.w600, p.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          GlassCircleButton(
            icon: Icons.more_horiz_rounded,
            size: 38,
            blur: 0,
            onTap: onMore,
          ),
        ],
      ),
    );
  }
}

class _CharacterMessage extends StatefulWidget {
  const _CharacterMessage({
    required this.message,
    required this.character,
    required this.isLast,
    required this.streaming,
    required this.onLongPress,
    required this.onReasoning,
    required this.onSwipe,
    required this.onContinue,
    required this.onRegenerate,
    required this.onSpeak,
  });

  final ChatMessage message;
  final DemoCharacter character;
  final bool isLast;
  final bool streaming;
  final VoidCallback onLongPress;
  final VoidCallback onReasoning;
  final ValueChanged<int> onSwipe;
  final VoidCallback onContinue;
  final VoidCallback onRegenerate;
  final VoidCallback onSpeak;

  @override
  State<_CharacterMessage> createState() => _CharacterMessageState();
}

class _CharacterMessageState extends State<_CharacterMessage> {
  double _drag = 0;

  String get _displayText =>
      _renderDisplayText(widget.message, widget.character.name);

  bool get _canSwipe =>
      widget.isLast && !widget.streaming && widget.message.hasSwipes;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final settings = AppStore.instance.settings;
    final message = widget.message;
    final meta = _messageMetaLine(message);
    return Opacity(
      opacity: message.hidden ? .38 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (settings.showAvatar) ...[
                SizedBox(
                  width: 30,
                  height: 26,
                  child: Portrait(
                    initial: widget.character.initial,
                    colors: widget.character.colors,
                    avatarBase64: widget.character.avatarBase64,
                    radius: 10,
                  ),
                ),
                const SizedBox(width: 9),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.attachments.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: _AttachmentStrip(
                          attachments: message.attachments,
                        ),
                      ),
                    if (message.reasoning != null) ...[
                      Pressable(
                        onTap: widget.onReasoning,
                        child: Glass(
                          radius: 12,
                          blur: 18,
                          shadow: false,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                size: 11,
                                color: p.amber,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '思考了 8 秒',
                                style: appText(
                                  10,
                                  FontWeight.w500,
                                  p.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(
                                Icons.expand_more_rounded,
                                size: 12,
                                color: p.textTertiary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onLongPress: widget.onLongPress,
                      onHorizontalDragUpdate: _canSwipe
                          ? (details) {
                              setState(() {
                                _drag = (_drag + details.delta.dx).clamp(
                                  -70,
                                  70,
                                );
                              });
                            }
                          : null,
                      onHorizontalDragEnd: _canSwipe
                          ? (details) {
                              final velocity = details.primaryVelocity ?? 0;
                              if (_drag < -36 || velocity < -250) {
                                HapticFeedback.selectionClick();
                                widget.onSwipe(1);
                              } else if (_drag > 36 || velocity > 250) {
                                HapticFeedback.selectionClick();
                                widget.onSwipe(-1);
                              }
                              setState(() => _drag = 0);
                            }
                          : null,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_drag.abs() > 8)
                            Opacity(
                              opacity: (_drag.abs() / 70).clamp(0, .8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(
                                    Icons.chevron_left_rounded,
                                    size: 18,
                                    color: p.amber,
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: p.amber,
                                  ),
                                ],
                              ),
                            ),
                          Transform.translate(
                            offset: Offset(_drag, 0),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.sizeOf(context).width * .74,
                              ),
                              child: Glass(
                                radius: 20,
                                blur: 24,
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  11,
                                  14,
                                  12,
                                ),
                                child: AnimatedSize(
                                  duration: const Duration(milliseconds: 90),
                                  alignment: Alignment.centerLeft,
                                  clipBehavior: Clip.none,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 220),
                                    transitionBuilder: (child, animation) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(.04, 0),
                                            end: Offset.zero,
                                          ).animate(animation),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: KeyedSubtree(
                                      key: ValueKey(message.swipeIndex),
                                      child: _RichMessage(
                                        text: _displayText,
                                        color: p.textPrimary,
                                        italicColor: p.textSecondary,
                                        dialogueColor: p.amber,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (settings.showTimestamp || message.bookmarked) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          if (settings.showTimestamp)
                            Text(
                              message.time ?? '',
                              style: appText(
                                8.5,
                                FontWeight.w400,
                                p.textTertiary,
                              ),
                            ),
                          if (message.bookmarked) ...[
                            if (settings.showTimestamp) const SizedBox(width: 5),
                            Icon(
                              Icons.bookmark_rounded,
                              size: 10,
                              color: p.amber,
                            ),
                          ],
                        ],
                      ),
                    ],
                    if (meta != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appText(
                          8.5,
                          FontWeight.w400,
                          p.textTertiary.withValues(alpha: .9),
                          letterSpacing: .1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (widget.isLast && !widget.streaming) ...[
            const SizedBox(height: 2),
            Padding(
              padding: EdgeInsets.only(left: settings.showAvatar ? 39 : 0),
              child: Row(
                children: [
                  Glass(
                    radius: 13,
                    blur: 18,
                    shadow: false,
                    padding: EdgeInsets.zero,
                    child: SizedBox(
                      height: 26,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Pressable(
                            onTap: () => widget.onSwipe(-1),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(5, 0, 2, 0),
                              child: Icon(
                                Icons.chevron_left_rounded,
                                size: 12,
                                color: p.textSecondary,
                              ),
                            ),
                          ),
                          Text(
                            '${message.swipeIndex + 1} / ${message.swipes.length}',
                            style: appText(
                              8.5,
                              FontWeight.w600,
                              p.textSecondary,
                            ),
                          ),
                          Pressable(
                            onTap: () => widget.onSwipe(1),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(2, 0, 5, 0),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                size: 12,
                                color: p.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GlassPill(
                    label: '继续',
                    icon: Icons.play_arrow_rounded,
                    height: 26,
                    onTap: widget.onContinue,
                  ),
                  const SizedBox(width: 6),
                  GlassPill(
                    label: '重写',
                    icon: Icons.refresh_rounded,
                    height: 26,
                    onTap: widget.onRegenerate,
                  ),
                  const SizedBox(width: 6),
                  GlassCircleButton(
                    icon: Icons.more_horiz_rounded,
                    size: 26,
                    iconSize: 12,
                    blur: 0,
                    onTap: widget.onLongPress,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UserMessage extends StatelessWidget {
  const _UserMessage({
    required this.message,
    required this.characterName,
    this.onLongPress,
  });

  final ChatMessage message;
  final String characterName;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final settings = AppStore.instance.settings;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onLongPress,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (message.attachments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: _AttachmentStrip(attachments: message.attachments),
          ),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * .76,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(15, 11, 15, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [p.userBubbleStart, p.userBubbleEnd],
              ),
              boxShadow: [
                BoxShadow(
                  color: p.amber.withValues(alpha: .18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: _RichMessage(
              text: _renderDisplayText(message, characterName),
              color: p.onUserBubble,
              italicColor: p.onUserBubble.withValues(alpha: .72),
              dialogueColor: const Color(0xFF1E3A8A),
            ),
          ),
        ),
        if (settings.showTimestamp || message.bookmarked) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.bookmarked) ...[
                Icon(Icons.bookmark_rounded, size: 10, color: p.amber),
                if (settings.showTimestamp) const SizedBox(width: 4),
              ],
              if (settings.showTimestamp)
                Text(
                  message.time ?? '',
                  style: appText(9.5, FontWeight.w400, p.textTertiary),
                ),
            ],
          ),
        ],
      ],
      ),
    );
  }
}

class _RichMessage extends StatelessWidget {
  const _RichMessage({
    required this.text,
    required this.color,
    required this.italicColor,
    this.dialogueColor,
  });

  final String text;
  final Color color;
  final Color italicColor;

  /// 对话高亮色：被 “”「」『』"" 包裹的「说的话」用这个颜色显示。
  final Color? dialogueColor;

  static final _dialogue = RegExp(
    '\u201c[^\u201d]*\u201d|\u300c[^\u300d]*\u300d|\u300e[^\u300f]*\u300f|"[^"]*"',
  );

  List<TextSpan> _italicSpans(String src, TextStyle italic) {
    final spans = <TextSpan>[];
    var cursor = 0;
    while (cursor < src.length) {
      final open = src.indexOf('*', cursor);
      if (open == -1) {
        spans.add(TextSpan(text: src.substring(cursor)));
        break;
      }
      if (open > cursor) {
        spans.add(TextSpan(text: src.substring(cursor, open)));
      }
      final close = src.indexOf('*', open + 1);
      if (close == -1) {
        spans.add(TextSpan(text: src.substring(open)));
        break;
      }
      spans.add(
        TextSpan(text: src.substring(open + 1, close), style: italic),
      );
      cursor = close + 1;
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = AppStore.instance.settings.chatFontSize;
    final base = appText(fontSize, FontWeight.w400, color, height: 1.5);
    final italic = base.copyWith(color: italicColor);
    final dc = dialogueColor;
    final spans = <TextSpan>[];
    if (dc == null) {
      spans.addAll(_italicSpans(text, italic));
    } else {
      final dialogueStyle = base.copyWith(
        color: dc,
        fontWeight: FontWeight.w600,
      );
      var cursor = 0;
      for (final m in _dialogue.allMatches(text)) {
        if (m.start > cursor) {
          spans.addAll(_italicSpans(text.substring(cursor, m.start), italic));
        }
        spans.add(TextSpan(text: m.group(0), style: dialogueStyle));
        cursor = m.end;
      }
      if (cursor < text.length) {
        spans.addAll(_italicSpans(text.substring(cursor), italic));
      }
    }
    return Text.rich(
      TextSpan(style: base, children: spans),
      textDirection: TextDirection.ltr,
    );
  }
}

class _TypingRow extends StatelessWidget {
  const _TypingRow({required this.character});

  final DemoCharacter character;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 30,
          height: 30,
          child: Portrait(
            initial: character.initial,
            colors: character.colors,
            avatarBase64: character.avatarBase64,
            radius: 10,
          ),
        ),
        const SizedBox(width: 9),
        Glass(
          radius: 18,
          blur: 20,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: const _TypingDots(),
        ),
      ],
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_c.value + i * .16) % 1;
            final alpha = .25 + .65 * (1 - (t * 2 - 1).abs());
            return Container(
              width: 5,
              height: 5,
              margin: EdgeInsets.only(right: i == 2 ? 0 : 5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.textSecondary.withValues(alpha: alpha),
              ),
            );
          }),
        );
      },
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.character,
    required this.controller,
    required this.hasText,
    required this.generating,
    required this.onChanged,
    required this.onSend,
    required this.onStop,
    required this.onAttach,
    required this.onVoice,
    this.focusNode,
  });

  final DemoCharacter character;
  final TextEditingController controller;
  final bool hasText;
  final bool generating;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onAttach;
  final VoidCallback onVoice;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final active = hasText || generating;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Glass(
        radius: 30,
        blur: 30,
        padding: const EdgeInsets.all(6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            GlassCircleButton(
              icon: Icons.add_rounded,
              size: 40,
              iconSize: 19,
              blur: 0,
              onTap: onAttach,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 7,
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  maxLines: 4,
                  minLines: 1,
                  onChanged: onChanged,
                  onSubmitted: (_) => onSend(),
                  textInputAction: TextInputAction.send,
                  cursorColor: p.amber,
                  style: appText(14.5, FontWeight.w400, p.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: '说点什么…',
                    hintStyle: appText(
                      14.5,
                      FontWeight.w400,
                      p.textTertiary,
                    ),
                  ),
                ),
              ),
            ),
            Pressable(
              onTap: generating ? onStop : (hasText ? onSend : null),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: generating || hasText
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [p.userBubbleStart, p.userBubbleEnd],
                        )
                      : null,
                  color: generating || hasText
                      ? null
                      : p.textTertiary.withValues(alpha: .14),
                  border: generating
                      ? Border.all(
                          color: p.amber.withValues(alpha: .7),
                          width: 1.2,
                        )
                      : null,
                  boxShadow: hasText || generating
                      ? [
                          BoxShadow(
                            color: p.amber.withValues(alpha: .25),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Icon(
                    generating
                        ? Icons.stop_rounded
                        : Icons.arrow_upward_rounded,
                    key: ValueKey(active),
                    size: 19,
                    color: generating || hasText
                        ? p.onUserBubble
                        : p.textTertiary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentMenu extends StatelessWidget {
  const _AttachmentMenu({required this.onImage, required this.onFile});

  final VoidCallback onImage;
  final VoidCallback onFile;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Glass(
            radius: 26,
            blur: 34,
            fill: 1.25,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: p.amber.withValues(alpha: .16),
                      ),
                      child: Icon(
                        Icons.attach_file_rounded,
                        size: 15,
                        color: p.amber,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      '添加内容',
                      style: appText(12, FontWeight.w500, p.textSecondary),
                    ),
                    const Spacer(),
                    GlassCircleButton(
                      icon: Icons.close_rounded,
                      size: 28,
                      iconSize: 13,
                      blur: 0,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.count(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 2.2,
                  children: [
                    Pressable(
                      onTap: onImage,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_outlined, size: 19, color: p.amber),
                          const SizedBox(height: 5),
                          Text(
                            '图片',
                            style: appText(10.5, FontWeight.w500, p.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Pressable(
                      onTap: onFile,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.attach_file_rounded,
                            size: 19,
                            color: p.sage,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '文件',
                            style: appText(10.5, FontWeight.w500, p.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageMenu extends StatelessWidget {
  const _MessageMenu({
    required this.name,
    required this.message,
    required this.onAction,
  });

  final String name;
  final ChatMessage message;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final items = <(IconData, String, Color)>[
      (Icons.copy_rounded, '复制', p.textPrimary),
      (Icons.edit_outlined, '编辑', p.textPrimary),
      (Icons.visibility_off_outlined, '隐藏', p.textPrimary),
      (Icons.delete_outline_rounded, '删除', p.danger),
      (Icons.bookmark_add_outlined, '书签', p.textPrimary),
      if (message.bookmarked)
        (Icons.bookmark_added_rounded, '从书签继续', p.amber),
      (Icons.call_split_rounded, '分支', p.textPrimary),
      (Icons.restart_alt_rounded, '从此重写', p.amber),
      (Icons.playlist_remove_rounded, '删除后续', p.danger),
      (Icons.auto_awesome_rounded, '查看推理', p.amber),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Glass(
            radius: 26,
            blur: 34,
            fill: 1.25,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: p.amber.withValues(alpha: .16),
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 15,
                        color: p.amber,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      '$name · ${message.time ?? ""}',
                      style: appText(12, FontWeight.w500, p.textSecondary),
                    ),
                    const Spacer(),
                    GlassCircleButton(
                      icon: Icons.close_rounded,
                      size: 28,
                      iconSize: 13,
                      blur: 0,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.count(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  childAspectRatio: 1.55,
                  children: [
                    for (final item in items)
                      Pressable(
                        onTap: () => onAction(item.$2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(item.$1, size: 19, color: item.$3),
                            const SizedBox(height: 5),
                            Text(
                              item.$2,
                              style: appText(10.5, FontWeight.w500, item.$3),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StaticMessageMenu extends StatelessWidget {
  const _StaticMessageMenu({
    required this.name,
    required this.message,
    required this.onClose,
  });

  final String name;
  final ChatMessage message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(color: Colors.black.withValues(alpha: .35)),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _MessageMenu(name: name, message: message, onAction: (_) {}),
        ),
      ],
    );
  }
}

class _AttachmentStrip extends StatelessWidget {
  const _AttachmentStrip({required this.attachments});

  final List<ChatAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final item in attachments)
          if (!item.isImage)
            Container(
              constraints: const BoxConstraints(maxWidth: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.black.withValues(alpha: .28),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.description_outlined, size: 16, color: Colors.white70),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            )
          else
            GestureDetector(
              onTap: () => _showImage(context, item.base64),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(item.base64),
                  width: 92,
                  height: 92,
                  fit: BoxFit.cover,
                ),
              ),
            ),
      ],
    );
  }
}

void _showImage(BuildContext context, String data) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: Image.memory(base64Decode(data), fit: BoxFit.contain),
          ),
        ),
      ),
    ),
  );
}

/// Compact assistant metadata: `model · prompt+completion tokens · duration`.
///
/// Old messages (and user messages) have no metadata, so this returns null and
/// the line is omitted instead of rendering placeholders.
String? _messageMetaLine(ChatMessage message) {
  if (message.isUser) return null;
  final parts = <String>[];
  final model = message.model?.trim() ?? '';
  if (model.isNotEmpty) parts.add(model);
  final prompt = message.promptTokens;
  final completion = message.completionTokens;
  if (prompt != null && completion != null) {
    parts.add('$prompt+$completion tok');
  } else if (prompt != null || completion != null) {
    parts.add('${prompt ?? completion} tok');
  }
  final duration = message.durationMs;
  if (duration != null) {
    parts.add(
      duration >= 1000
          ? '${(duration / 1000).toStringAsFixed(duration >= 10000 ? 0 : 1)}s'
          : '${duration}ms',
    );
  }
  return parts.isEmpty ? null : parts.join(' · ');
}

class _EditMessageSheet extends StatefulWidget {
  const _EditMessageSheet({required this.initial});

  final String initial;

  @override
  State<_EditMessageSheet> createState() => _EditMessageSheetState();
}

class _EditMessageSheetState extends State<_EditMessageSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final available = media.size.height - keyboard - media.padding.top;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: available * .86),
          child: SheetPanel(
            title: '编辑消息',
            subtitle: '修改后会询问如何处理后续消息。',
            bottomSafeArea: keyboard > 0 ? 0 : media.padding.bottom,
            onClose: () => Navigator.of(context).pop(),
            onGrabberDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 280) {
                Navigator.of(context).pop();
              }
            },
            footer: GlassPrimaryButton(
              label: '保存修改',
              icon: Icons.check_rounded,
              onTap: () => Navigator.of(context).pop(_controller.text),
            ),
            child: Glass(
              radius: 18,
              blur: 18,
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _controller,
                maxLines: 10,
                minLines: 5,
                autofocus: true,
                style: appText(14, FontWeight.w400, p.textPrimary, height: 1.5),
                cursorColor: p.amber,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: '输入消息内容',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
