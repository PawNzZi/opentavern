import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat/chat_controller.dart';
import '../core/docx_text.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../data/demo.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/theme.dart';
import '../design/toast.dart';
import 'chat_info.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.character,
    this.standalone = true,
    this.showMessageMenu = false,
    this.autoDemo = false,
    this.sessionId,
    this.newSession = false,
  });

  final DemoCharacter character;
  final bool standalone;
  final bool showMessageMenu;
  final bool autoDemo;
  final String? sessionId;
  final bool newSession;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatController _chat;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _hasText = false;
  final _pending = <ChatAttachment>[];

  @override
  void initState() {
    super.initState();
    final session = widget.sessionId != null
        ? AppStore.instance.sessionById(widget.sessionId)
        : widget.newSession
            ? AppStore.instance.createSession(widget.character)
            : null;
    _chat = ChatController(character: widget.character, session: session);
    _chat.addListener(_onChatChanged);
    if (widget.autoDemo) {
      Timer(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        _chat.send('如果我说，我就是那个坏消息呢？');
      });
    }
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
    _chat.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
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
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, animation, __) => ChatInfoSheet(
          session: _chat.session,
          character: widget.character,
          onSummarize: _chat.summarizeNow,
        ),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, .04),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      ),
    );
  }

  Future<void> _pickFile(BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
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
    } else if (textExts.contains(ext)) {
      text = utf8.decode(bytes, allowMalformed: true).trim();
    } else {
      _toast('目前支持 TXT / MD / JSON / CSV / DOCX');
      return;
    }
    var content = text!;
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
    Navigator.of(sheetContext).pop();
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .35),
      builder: (context) {
        final p = AppPalette.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Glass(
              radius: 26,
              blur: 34,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '添加内容',
                    style: appText(15, FontWeight.w600, p.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _AttachAction(
                        icon: Icons.photo_outlined,
                        label: '图片',
                        color: p.amber,
                        onTap: () => _pickImage(context),
                      ),
                      _AttachAction(
                        icon: Icons.attach_file_rounded,
                        label: '文件',
                        color: p.sage,
                        onTap: () => _pickFile(context),
                      ),
                      _AttachAction(
                        icon: Icons.photo_camera_outlined,
                        label: '拍照',
                        color: p.violet,
                        onTap: () => _toast('已打开相机'),
                      ),
                      _AttachAction(
                        icon: Icons.brush_rounded,
                        label: '绘图',
                        color: p.rose,
                        onTap: () => _toast('图像生成已就绪'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _toast(String text) {
    showTavernToast(context, text);
  }

  void _showMessageMenu(ChatMessage message) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'message-menu',
      barrierColor: Colors.black.withValues(alpha: .38),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, __) => _MessageMenu(
        message: message,
        onAction: (action) {
          Navigator.of(dialogContext).pop();
          _handleMenuAction(action, message);
        },
      ),
      transitionBuilder: (context, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: .96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  void _handleMenuAction(String action, ChatMessage message) {
    switch (action) {
      case '复制':
        Clipboard.setData(ClipboardData(text: message.text));
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
      case '朗读':
        _toast('正在朗读…');
      case '翻译':
        _toast('已翻译为中文');
      case '删除后续':
        _confirmDeleteAfter(message);
      case '从此重写':
        _chat.regenerateFrom(message);
        _toast('将从这条消息重新生成');
      case '查看推理':
        _toast('展开推理内容');
    }
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

  void _editMessage(ChatMessage message) {
    final controller = TextEditingController(text: message.text);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .38),
      builder: (context) {
        final p = AppPalette.of(context);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Glass(
                radius: 26,
                blur: 36,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '编辑消息',
                      style: appText(16, FontWeight.w600, p.textPrimary),
                    ),
                    const SizedBox(height: 10),
                    Glass(
                      radius: 16,
                      blur: 18,
                      shadow: false,
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: controller,
                        maxLines: 6,
                        minLines: 3,
                        style: appText(14, FontWeight.w400, p.textPrimary),
                        cursorColor: p.amber,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: '输入消息内容',
                          hintStyle: appText(
                            14,
                            FontWeight.w400,
                            p.textTertiary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassPrimaryButton(
                      label: '保存修改',
                      height: 48,
                      onTap: () {
                        final wasLast = _chat.messages.isNotEmpty &&
                            _chat.messages.last.id == message.id;
                        _chat.edit(message, controller.text);
                        Navigator.of(context).pop();
                        _toast('已保存');
                        if (!wasLast) _askAfterEdit(message);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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
                      onLongPress: () => _showMessageMenu(message),
                    )
                  : _CharacterMessage(
                      message: message,
                      character: c,
                      isLast: isLast,
                      streaming: _chat.streamingMessage == message,
                      onLongPress: () => _showMessageMenu(message),
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
                  '今天 · 11 月 18 日',
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
                    Expanded(
                      child: ListView(
                        reverse: true,
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        physics: const BouncingScrollPhysics(),
                        children: items,
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
                                  _input.text = reply.message;
                                  setState(() => _hasText = true);
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    _Composer(
                      character: c,
                      controller: _input,
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
                        color: p.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      generating ? '正在生成…' : '在线',
                      style: appText(10, FontWeight.w500, p.amber),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Glass(
            radius: 13,
            blur: 16,
            shadow: false,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 11, color: p.amber),
                const SizedBox(width: 5),
                Text(
                  'Sonnet 4.5',
                  style: appText(10, FontWeight.w600, p.textSecondary),
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

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.message,
    required this.character,
    required this.isLastCharacter,
  });

  final ChatMessage message;
  final DemoCharacter character;
  final bool isLastCharacter;

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return _UserMessage(message: message);
    }
    return _CharacterMessage(
      message: message,
      character: character,
      isLast: isLastCharacter,
      streaming: false,
      onLongPress: () {},
      onSwipe: (_) {},
      onContinue: () {},
      onRegenerate: () {},
      onSpeak: () {},
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
  final ValueChanged<int> onSwipe;
  final VoidCallback onContinue;
  final VoidCallback onRegenerate;
  final VoidCallback onSpeak;

  @override
  State<_CharacterMessage> createState() => _CharacterMessageState();
}

class _CharacterMessageState extends State<_CharacterMessage> {
  double _drag = 0;

  bool get _canSwipe =>
      widget.isLast && !widget.streaming && widget.message.hasSwipes;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final message = widget.message;
    return Opacity(
      opacity: message.hidden ? .38 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 30,
                height: 30,
                child: Portrait(
                  initial: widget.character.initial,
                  colors: widget.character.colors,
                  avatarBase64: widget.character.avatarBase64,
                  radius: 10,
                ),
              ),
              const SizedBox(width: 9),
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
                      Glass(
                        radius: 13,
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
                                        text: message.text,
                                        color: p.textPrimary,
                                        italicColor: p.textSecondary,
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
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          message.time ?? '',
                          style: appText(
                            9.5,
                            FontWeight.w400,
                            p.textTertiary,
                          ),
                        ),
                        if (message.bookmarked) ...[
                          const SizedBox(width: 5),
                          Icon(
                            Icons.bookmark_rounded,
                            size: 10,
                            color: p.amber,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.isLast && !widget.streaming) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 39),
              child: Row(
                children: [
                  Glass(
                    radius: 15,
                    blur: 18,
                    shadow: false,
                    padding: EdgeInsets.zero,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Pressable(
                          onTap: () => widget.onSwipe(-1),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
                            child: Icon(
                              Icons.chevron_left_rounded,
                              size: 14,
                              color: p.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          '${message.swipeIndex + 1} / ${message.swipes.length}',
                          style: appText(
                            10,
                            FontWeight.w600,
                            p.textSecondary,
                          ),
                        ),
                        Pressable(
                          onTap: () => widget.onSwipe(1),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              size: 14,
                              color: p.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GlassPill(
                    label: '继续',
                    icon: Icons.play_arrow_rounded,
                    height: 34,
                    onTap: widget.onContinue,
                  ),
                  const SizedBox(width: 6),
                  GlassPill(
                    label: '重写',
                    icon: Icons.refresh_rounded,
                    height: 34,
                    onTap: widget.onRegenerate,
                  ),
                  const SizedBox(width: 6),
                  GlassCircleButton(
                    icon: Icons.more_horiz_rounded,
                    size: 36,
                    iconSize: 16,
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
  const _UserMessage({required this.message, this.onLongPress});

  final ChatMessage message;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
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
            child: Text(
              message.text,
              style: appText(
                15,
                FontWeight.w500,
                p.onUserBubble,
                height: 1.45,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.bookmarked) ...[
              Icon(Icons.bookmark_rounded, size: 10, color: p.amber),
              const SizedBox(width: 4),
            ],
            Text(
              message.time ?? '',
              style: appText(9.5, FontWeight.w400, p.textTertiary),
            ),
          ],
        ),
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
  });

  final String text;
  final Color color;
  final Color italicColor;

  @override
  Widget build(BuildContext context) {
    final base = appText(15, FontWeight.w400, color, height: 1.5);
    final italic = base.copyWith(color: italicColor);
    final spans = <TextSpan>[];
    var cursor = 0;
    while (cursor < text.length) {
      final open = text.indexOf('*', cursor);
      if (open == -1) {
        spans.add(TextSpan(text: text.substring(cursor)));
        break;
      }
      if (open > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, open)));
      }
      final close = text.indexOf('*', open + 1);
      if (close == -1) {
        spans.add(TextSpan(text: text.substring(open)));
        break;
      }
      spans.add(
        TextSpan(
          text: text.substring(open + 1, close),
          style: italic,
        ),
      );
      cursor = close + 1;
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
                    hintText: '对 ${character.name} 说点什么…',
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
              onTap: onVoice,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10, right: 8),
                child: Icon(
                  Icons.graphic_eq_rounded,
                  size: 19,
                  color: p.textTertiary,
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

class _AttachAction extends StatelessWidget {
  const _AttachAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: color.withValues(alpha: .16),
              ),
              child: Icon(icon, size: 21, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: appText(10.5, FontWeight.w500, p.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageMenu extends StatelessWidget {
  const _MessageMenu({required this.message, required this.onAction});

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
      (Icons.call_split_rounded, '分支', p.textPrimary),
      (Icons.restart_alt_rounded, '从此重写', p.amber),
      (Icons.playlist_remove_rounded, '删除后续', p.danger),
      (Icons.volume_up_rounded, '朗读', p.textPrimary),
      (Icons.translate_rounded, '翻译', p.textPrimary),
      (Icons.auto_awesome_rounded, '查看推理', p.amber),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
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
                      'Seraphina · ${message.time ?? ""}',
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
  const _StaticMessageMenu({required this.message, required this.onClose});

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
          child: _MessageMenu(message: message, onAction: (_) {}),
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
