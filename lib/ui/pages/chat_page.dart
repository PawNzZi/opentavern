/// 聊天页：流式回复、右键菜单（重新生成 / 续写 / 换候选 / 编辑 / 删除 / 分支）、
/// 剧情记忆压缩、提示词预览、导出。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/engine/chat_ops.dart';
import '../../core/engine/memory.dart' as memory_engine;
import '../../core/engine/prompt.dart';
import '../../core/engine/reply.dart';
import '../../core/engine/tavern_engine.dart';
import '../../core/models/tavern_card.dart';
import '../../core/settings/app_settings.dart';
import '../../core/store/tavern_store.dart';
import '../nav.dart';
import '../quote_text.dart';
import '../theme.dart';
import '../toast.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.chatId});

  final String chatId;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final AppSettings _settings = AppSettings.instance;
  final TavernEngine _engine = TavernEngine(settings: AppSettings.instance);
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  Map<String, dynamic>? _chat;
  Map<String, dynamic>? _character;
  List<TavernWorld> _worlds = <TavernWorld>[];

  bool _streaming = false;
  String _streamMessageId = '';
  bool _compacting = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _reload() {
    final Map<String, dynamic>? chat = TavernStore.instance.chat(widget.chatId);
    final Map<String, dynamic>? character =
        chat == null ? null : TavernStore.instance.character('${chat['characterId']}');
    final List<TavernWorld> worlds = <TavernWorld>[];
    if (character != null && character['worldIds'] is List) {
      for (final Object? id in character['worldIds'] as List) {
        final Map<String, dynamic>? world = TavernStore.instance.world('$id');
        if (world != null) worlds.add(TavernWorld.fromJson(world));
      }
    }
    setState(() {
      _chat = chat;
      _character = character;
      _worlds = worlds;
    });
  }

  List<Map<String, dynamic>> get _messages =>
      _chat == null ? <Map<String, dynamic>>[] : ChatOps.messages(_chat!);

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  /// 生成一轮回复。[userText] 会作为本轮用户输入拼进提示词。
  /// [before] 用于「重新生成」：临时把最后一条用户消息排除在历史之外，避免重复。
  Future<void> _generate(String userText, {bool dropTrailingMessage = false}) async {
    final Map<String, dynamic>? chat = _chat;
    final Map<String, dynamic>? character = _character;
    if (chat == null || character == null) return;
    if (!_engine.ready) {
      showToast(context, _engine.notReadyMessage);
      return;
    }
    if (_streaming) return;

    setState(() => _streaming = true);
    final Map<String, dynamic> promptChat = <String, dynamic>{
      ...chat,
      'messages': <dynamic>[
        ...(_messages.map((Map<String, dynamic> item) => <String, dynamic>{...item})),
      ],
    };
    if (dropTrailingMessage) {
      final List<dynamic> list = promptChat['messages'] as List;
      if (list.isNotEmpty) list.removeLast();
    }
    BuiltPrompt prompt;
    try {
      prompt = _engine.build(
        chat: promptChat,
        character: character,
        worlds: _worlds,
        userText: userText,
      );
    } catch (error) {
      setState(() => _streaming = false);
      showToast(context, '组装提示词失败：$error');
      return;
    }

    final Map<String, dynamic> placeholder =
        await ChatOps.append(widget.chatId, 'assistant', '');
    _streamMessageId = '${placeholder['id']}';
    final StringBuffer buffer = StringBuffer();
    String errorText = '';
    try {
      await for (final String delta in _engine.stream(prompt: prompt)) {
        buffer.write(delta);
        _updateStreamingText(buffer.toString());
      }
    } catch (error) {
      errorText = '$error';
    }

    final String raw = buffer.toString();
    if (errorText.isNotEmpty && raw.trim().isEmpty) {
      await ChatOps.deleteMessage(widget.chatId, _streamMessageId);
      _reload();
      setState(() => _streaming = false);
      if (mounted) showToast(context, '生成失败：$errorText');
      return;
    }
    final ParsedReply parsed = parseReply(raw);
    final Map? stored = TavernStore.instance.mutable('chats', widget.chatId);
    if (stored != null) {
      for (final Object? item in stored['messages'] as List) {
        if (item is Map && '${item['id']}' == _streamMessageId) {
          item['text'] = parsed.text;
          if (parsed.statusLines.isNotEmpty) {
            item['statusLines'] = parsed.statusLines.map((StatusLine line) => line.toJson()).toList();
          }
          if (parsed.quickOptions.isNotEmpty) {
            item['quickOptions'] = parsed.quickOptions;
          }
          item['swipes'] = <Map<String, dynamic>>[
            <String, dynamic>{
              'text': parsed.text,
              if (parsed.statusLines.isNotEmpty)
                'statusLines': parsed.statusLines.map((StatusLine l) => l.toJson()).toList(),
              if (parsed.quickOptions.isNotEmpty) 'quickOptions': parsed.quickOptions,
            },
          ];
          item['swipeIndex'] = 0;
        }
      }
      await TavernStore.instance.save();
    }
    _reload();
    setState(() {
      _streaming = false;
      _streamMessageId = '';
    });
    _scrollToBottom();
    if (errorText.isNotEmpty && mounted) {
      showToast(context, '回复中断：$errorText');
    }
  }

  void _updateStreamingText(String text) {
    final Map? chat = TavernStore.instance.mutable('chats', widget.chatId);
    if (chat == null) return;
    for (final Object? item in chat['messages'] as List) {
      if (item is Map && '${item['id']}' == _streamMessageId) {
        item['text'] = text;
      }
    }
    setState(() {});
    _scrollToBottom();
  }

  Future<void> _send() async {
    final String text = _input.text.trim();
    if (text.isEmpty || _streaming) return;
    _input.clear();
    await ChatOps.append(widget.chatId, 'user', text);
    _reload();
    _scrollToBottom();
    await _generate(text, dropTrailingMessage: true);
    await _maybeAutoCompact();
  }

  Future<void> _maybeAutoCompact() async {
    if (!_settings.memoryAuto || _compacting || _streaming) return;
    final List<Map<String, dynamic>> messages = _messages;
    if (messages.length < _settings.historyLimit * 2) return;
    await _compact(silent: true);
  }

  Future<void> _compact({bool silent = false}) async {
    final Map<String, dynamic>? chat = _chat;
    if (chat == null || _compacting) return;
    if (!_engine.ready) {
      if (!silent) showToast(context, _engine.notReadyMessage);
      return;
    }
    if (!silent) setState(() => _compacting = true);
    try {
      final Map<String, dynamic> live = Map<String, dynamic>.from(chat);
      live['characterName'] = '${_character?['name'] ?? '角色'}';
      final memory_engine.CompactResult result = await memory_engine.compactChat(
        chat: live,
        settings: _settings,
        summarize: _engine.summarize,
      );
      if (result.ok) {
        final Map? stored = TavernStore.instance.mutable('chats', widget.chatId);
        if (stored != null) {
          stored['memory'] = live['memory'];
          await TavernStore.instance.save();
        }
        _reload();
        if (!silent && mounted) {
          showToast(
            context,
            '已压缩 ${result.foldedMessages} 条：约 ${result.beforeTokens} → ${result.afterTokens} tokens',
          );
        }
      } else if (!silent && mounted) {
        showToast(
          context,
          result.reason == 'failed'
              ? '压缩失败：${result.error.isEmpty ? '模型没有返回内容' : result.error}'
              : '没有可压缩的历史',
        );
      }
    } catch (error) {
      if (!silent && mounted) showToast(context, '压缩失败：$error');
    } finally {
      if (!silent && mounted) setState(() => _compacting = false);
    }
  }

  Future<void> _regenerate() async {
    final Map<String, dynamic>? chat = _chat;
    if (chat == null || _streaming) return;
    final List<Map<String, dynamic>> messages = _messages;
    int userIndex = -1;
    for (int i = messages.length - 1; i >= 0; i--) {
      if ('${messages[i]['role']}' == 'user') {
        userIndex = i;
        break;
      }
    }
    if (userIndex < 0) {
      showToast(context, '没有可重新生成的用户消息');
      return;
    }
    final String userText = '${messages[userIndex]['text']}';
    await ChatOps.removeLastAssistant(widget.chatId);
    _reload();
    await _generate(userText, dropTrailingMessage: true);
  }

  Future<void> _continue() async {
    if (_streaming) return;
    await _generate('（继续）');
  }

  Future<void> _swipe(Map<String, dynamic> message) async {
    final String userText = _lastUserText();
    if (userText.isEmpty) return;
    final Map<String, dynamic>? character = _character;
    if (character == null || !_engine.ready) {
      showToast(context, _engine.notReadyMessage);
      return;
    }
    setState(() => _streaming = true);
    try {
      final Map<String, dynamic> promptChat = <String, dynamic>{
        ...(_chat ?? <String, dynamic>{}),
        'messages': <dynamic>[
          ..._messages.map((Map<String, dynamic> item) => <String, dynamic>{...item}),
        ],
      };
      final BuiltPrompt prompt = _engine.build(
        chat: promptChat,
        character: character,
        worlds: _worlds,
        userText: userText,
      );
      final StringBuffer buffer = StringBuffer();
      await for (final String delta in _engine.stream(
        prompt: prompt,
        temperature: (_settings.temperature + 0.1).clamp(0, 2),
      )) {
        buffer.write(delta);
      }
      final ParsedReply parsed = parseReply(buffer.toString());
      await ChatOps.addSwipe(
        widget.chatId,
        '${message['id']}',
        text: parsed.text,
        statusLines: parsed.statusLines.map((StatusLine line) => line.toJson()).toList(),
        quickOptions: parsed.quickOptions,
      );
      _reload();
    } catch (error) {
      if (mounted) showToast(context, '生成候选失败：$error');
    } finally {
      if (mounted) setState(() => _streaming = false);
    }
  }

  String _lastUserText() {
    final List<Map<String, dynamic>> messages = _messages;
    for (int i = messages.length - 1; i >= 0; i--) {
      if ('${messages[i]['role']}' == 'user') return '${messages[i]['text']}';
    }
    return '';
  }

  Future<void> _previewPrompt() async {
    final Map<String, dynamic>? chat = _chat;
    final Map<String, dynamic>? character = _character;
    if (chat == null || character == null) return;
    final String text = _input.text.trim();
    final BuiltPrompt prompt = _engine.build(
      chat: chat,
      character: character,
      worlds: _worlds,
      userText: text.isEmpty ? '（下一轮用户输入）' : text,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Row(
          children: <Widget>[
            const Expanded(child: Text('提示词预览', style: TavernText.title)),
            Text('${prompt.totalTokens} tokens', style: TavernText.tiny),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              '【System】\n${prompt.system}\n\n【User】\n${prompt.user}',
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('关闭')),
        ],
      ),
    );
  }

  Future<void> _showMessageMenu(Map<String, dynamic> message) async {
    final bool isAssistant = '${message['role']}' == 'assistant';
    final bool isLast = _messages.isNotEmpty && '${_messages.last['id']}' == '${message['id']}';
    final String? action = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (isAssistant && isLast)
              ListTile(
                title: const Text('重新生成'),
                onTap: () => Navigator.of(ctx).pop('regenerate'),
              ),
            if (isAssistant && isLast)
              ListTile(
                title: const Text('继续这条'),
                onTap: () => Navigator.of(ctx).pop('continue'),
              ),
            if (isAssistant)
              ListTile(
                title: const Text('换一个候选'),
                onTap: () => Navigator.of(ctx).pop('swipe'),
              ),
            ListTile(
              title: const Text('复制'),
              onTap: () => Navigator.of(ctx).pop('copy'),
            ),
            ListTile(
              title: const Text('编辑'),
              onTap: () => Navigator.of(ctx).pop('edit'),
            ),
            ListTile(
              title: const Text('从这里分支'),
              onTap: () => Navigator.of(ctx).pop('branch'),
            ),
            ListTile(
              title: const Text('删除', style: TextStyle(color: TavernColors.danger)),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'regenerate':
        await _regenerate();
      case 'continue':
        await _continue();
      case 'swipe':
        await _swipe(message);
      case 'copy':
        await _copyText('${message['text']}');
      case 'edit':
        await _editMessage(message);
      case 'branch':
        final Map<String, dynamic>? branch =
            await ChatOps.branch(widget.chatId, '${message['id']}');
        if (branch != null && mounted) {
          await pushPage<void>(context, ChatPage(chatId: '${branch['id']}'));
          _reload();
        }
      case 'delete':
        await ChatOps.deleteMessage(widget.chatId, '${message['id']}');
        _reload();
    }
  }

  Future<void> _copyText(String text) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('复制内容', style: TavernText.title),
        content: SelectableText(text, style: TavernText.secondary),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('关闭')),
        ],
      ),
    );
  }

  Future<void> _editMessage(Map<String, dynamic> message) async {
    final TextEditingController controller =
        TextEditingController(text: '${message['text']}');
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('编辑消息', style: TavernText.title),
        content: TextField(
          controller: controller,
          minLines: 4,
          maxLines: 10,
          style: TavernText.body,
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('保存')),
        ],
      ),
    );
    if (ok != true) return;
    await ChatOps.updateText(widget.chatId, '${message['id']}', controller.text.trim());
    _reload();
  }

  Future<void> _showMemory() async {
    final Map<String, dynamic>? chat = _chat;
    if (chat == null) return;
    final Object? memory = chat['memory'];
    final String summary = memory is Map ? '${memory['summary'] ?? ''}' : '';
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('剧情记忆', style: TavernText.title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: summary.isEmpty
                ? const Text('还没有压缩过的记忆。', style: TavernText.secondary)
                : SelectableText(summary, style: TavernText.secondary),
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('关闭')),
        ],
      ),
    );
  }

  Future<void> _exportChat() async {
    final Map<String, dynamic>? chat = _chat;
    if (chat == null) return;
    final String text = memory_engine.exportChatAsText(
      chat,
      characterName: '${_character?['name'] ?? '角色'}',
      userName: _settings.userName,
    );
    final Uri? saved = await FilePicker.saveFile(
      fileName: '${chat['title'] ?? 'chat'}.txt',
      bytes: Uint8List.fromList(utf8.encode(text)),
    );
    if (!mounted) return;
    showToast(context, saved != null ? '对话已导出' : '已取消');
  }

  Future<void> _showChatMenu() async {
    final String? action = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              title: const Text('提示词预览'),
              onTap: () => Navigator.of(ctx).pop('preview'),
            ),
            ListTile(
              title: const Text('查看剧情记忆'),
              onTap: () => Navigator.of(ctx).pop('memory'),
            ),
            ListTile(
              title: const Text('压缩剧情记忆'),
              onTap: () => Navigator.of(ctx).pop('compact'),
            ),
            ListTile(
              title: const Text('导出对话文本'),
              onTap: () => Navigator.of(ctx).pop('export'),
            ),
            ListTile(
              title: const Text('清除记忆'),
              onTap: () => Navigator.of(ctx).pop('clear'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'preview':
        await _previewPrompt();
      case 'memory':
        await _showMemory();
      case 'export':
        await _exportChat();
      case 'compact':
        await _compact();
      case 'clear':
        final Map? chat = TavernStore.instance.mutable('chats', widget.chatId);
        if (chat != null) {
          chat['memory'] = null;
          await TavernStore.instance.save();
          _reload();
          if (mounted) showToast(context, '记忆已清除');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? character = _character;
    final String title = '${_chat?['title'] ?? character?['name'] ?? '对话'}';
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: <Widget>[
          NavBar(
            title: title,
            actions: <Widget>[
              IconButton(
                onPressed: () => unawaited(_showChatMenu()),
                icon: const Icon(Icons.more_horiz, size: 22),
                color: TavernColors.accent,
              ),
            ],
          ),
          if (_compacting)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              itemCount: _messages.length,
              itemBuilder: (BuildContext context, int index) {
                final Map<String, dynamic> message = _messages[index];
                return _bubble(message);
              },
            ),
          ),
          _composer(),
        ],
      ),
    );
  }

  Widget _bubble(Map<String, dynamic> message) {
    final bool isUser = '${message['role']}' == 'user';
    final String text = '${message['text'] ?? ''}';
    final List<dynamic> statusLines =
        message['statusLines'] is List ? message['statusLines'] as List : <dynamic>[];
    final List<dynamic> options =
        message['quickOptions'] is List ? message['quickOptions'] as List : <dynamic>[];
    final List<dynamic> swipes = message['swipes'] is List ? message['swipes'] as List : <dynamic>[];
    final int swipeIndex = message['swipeIndex'] is num ? (message['swipeIndex'] as num).toInt() : 0;
    final bool streamingThis = _streaming && '${message['id']}' == _streamMessageId;

    final Widget body = Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
          decoration: BoxDecoration(
            color: isUser ? TavernColors.accent : TavernColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: text.isEmpty && streamingThis
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : QuoteText(
                  text,
                  enabled: !isUser,
                  style: TextStyle(
                    fontSize: 15,
                    height: 22 / 15,
                    color: isUser ? Colors.white : TavernColors.text,
                  ),
                ),
        ),
        if (statusLines.isNotEmpty && !isUser) _statusPanel(statusLines),
        if (options.isNotEmpty && !isUser)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final Object? option in options)
                  GestureDetector(
                    onTap: () {
                      _input.text = '$option';
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: TavernColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(TavernRadius.pill),
                      ),
                      child: Text('$option', style: const TextStyle(fontSize: 12, color: TavernColors.accent)),
                    ),
                  ),
              ],
            ),
          ),
        if (swipes.length > 1 && !isUser)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                GestureDetector(
                  onTap: () => unawaited(ChatOps.selectSwipe(
                      widget.chatId, '${message['id']}', (swipeIndex - 1).clamp(0, swipes.length - 1))),
                  child: const Icon(Icons.chevron_left, size: 16, color: TavernColors.textMuted),
                ),
                Text('${swipeIndex + 1}/${swipes.length}', style: TavernText.tiny),
                GestureDetector(
                  onTap: () => unawaited(ChatOps.selectSwipe(
                      widget.chatId, '${message['id']}', (swipeIndex + 1).clamp(0, swipes.length - 1))),
                  child: const Icon(Icons.chevron_right, size: 16, color: TavernColors.textMuted),
                ),
              ],
            ),
          ),
      ],
    );

    return GestureDetector(
      onLongPress: () => unawaited(_showMessageMenu(message)),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: <Widget>[
            if (!isUser) ...<Widget>[
              _avatar(24),
              const SizedBox(width: 8),
            ],
            Flexible(child: body),
          ],
        ),
      ),
    );
  }

  Widget _statusPanel(List<dynamic> lines) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: TavernColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TavernColors.separator, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('状态', style: TavernText.tiny),
          const SizedBox(height: 4),
          for (final Object? item in lines)
            if (item is Map)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${item['label'] ?? ''}：${item['value'] ?? ''}',
                  style: const TextStyle(fontSize: 11, height: 1.4, color: TavernColors.textSecondary),
                ),
              ),
        ],
      ),
    );
  }

  Widget _avatar(double size) {
    final String path = '${_character?['avatar'] ?? ''}';
    if (path.isNotEmpty && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 4),
        child: Image.file(File(path), width: size, height: size, fit: BoxFit.cover),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: TavernColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size / 4),
      ),
      alignment: Alignment.center,
      child: Text('${_character?['name'] ?? '?'}'.substring(0, 1),
          style: const TextStyle(fontSize: 11, color: TavernColors.accent)),
    );
  }

  Widget _composer() {
    final double bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottom),
      decoration: const BoxDecoration(
        color: TavernColors.surface,
        border: Border(top: BorderSide(color: TavernColors.separator, width: 0.5)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: TavernColors.bg,
                borderRadius: BorderRadius.circular(TavernRadius.pill),
              ),
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                style: TavernText.body,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '说点什么…',
                  hintStyle: TextStyle(fontSize: 14, color: TavernColors.textFaint),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _streaming ? null : () => unawaited(_send()),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _streaming ? TavernColors.textFaint : TavernColors.accent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _streaming ? Icons.hourglass_empty : Icons.arrow_upward,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
