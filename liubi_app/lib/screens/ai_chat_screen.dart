import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../services/api_service.dart';
import '../utils/helpers.dart';
import '../widgets/app_toast.dart';

class _ChatMessage {
  final String role;
  String content;
  final DateTime? createdAt;
  bool isStreaming;
  _ChatMessage({required this.role, required this.content, this.createdAt, this.isStreaming = false});
}

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final List<_ChatMessage> _messages = [];
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isLoading = false;
  bool _sending = false;
  late AnimationController _dotCtrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dotCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _loadHistory();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // 当键盘弹出或收起时，延迟一点滚动到底部
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dotCtrl.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService().get('/ai/history');
      if (res['code'] == 200 && mounted) {
        final list = res['data'] as List? ?? [];
        setState(() {
          _messages.clear();
          _messages.addAll(list.map((e) => _ChatMessage(
            role: e['role'] ?? 'user',
            content: e['content'] ?? '',
            createdAt: e['created_at'] != null ? DateTime.tryParse(e['created_at']) : null,
          )));
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollCtrl.hasClients) {
              _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
            }
          });
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollCtrl.hasClients && mounted) {
            _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    _inputCtrl.clear();
    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text, createdAt: DateTime.now()));
      _sending = true;
    });
    _scrollToBottom();

    try {
      final chatMsgs = _messages
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final res = await ApiService().post('/ai/chat', data: {
        'messages': chatMsgs,
        'userMessage': text,
      });

      if (res['code'] == 200 && mounted) {
        final fullContent = res['data']?['content'] ?? '抱歉，我暂时无法回答';
        final aiMsg = _ChatMessage(role: 'assistant', content: '', createdAt: DateTime.now(), isStreaming: true);
        setState(() => _messages.add(aiMsg));

        // Typewriter effect
        await _typewriterEffect(aiMsg, fullContent);
      } else if (mounted) {
        AppToast.error(context, message: res['msg'] ?? '发送失败');
      }
    } catch (_) {
      if (mounted) AppToast.error(context, message: '网络错误');
    }

    if (mounted) {
      setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  Future<void> _typewriterEffect(_ChatMessage msg, String fullContent) async {
    final chars = fullContent.runes.toList();
    int frameCount = 0;
    for (int i = 0; i < chars.length; i++) {
      if (!mounted) break;
      msg.content = String.fromCharCodes(chars.sublist(0, i + 1));
      frameCount++;
      // Update UI and scroll every 2 chars for smooth feel
      if (frameCount % 2 == 0 || i == chars.length - 1) {
        setState(() {});
        _scrollToBottom();
        await Future.delayed(const Duration(milliseconds: 16));
      }
    }
    msg.isStreaming = false;
    if (mounted) {
      setState(() {});
      _scrollToBottom();
    }
  }

  Future<void> _regenerate(int index) async {
    if (index < 0 || index >= _messages.length) return;
    final msg = _messages[index];
    if (msg.role != 'assistant') return;

    setState(() {
      msg.content = '';
      msg.isStreaming = true;
    });

    try {
      final chatMsgs = _messages.sublist(0, index)
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final res = await ApiService().post('/ai/chat', data: {
        'messages': chatMsgs,
        'userMessage': chatMsgs.last['content'] ?? '',
      });

      if (res['code'] == 200 && mounted) {
        final fullContent = res['data']?['content'] ?? '抱歉，我暂时无法回答';
        await _typewriterEffect(msg, fullContent);
      } else if (mounted) {
        msg.content = '重新生成失败';
        msg.isStreaming = false;
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        msg.content = '网络错误，请重试';
        msg.isStreaming = false;
        setState(() {});
      }
    }
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      return;
    }
    final max = _scrollCtrl.position.maxScrollExtent;
    final current = _scrollCtrl.offset;
    // If close to bottom, jump instantly for smooth follow
    if (max - current < 200) {
      _scrollCtrl.jumpTo(max);
    } else {
      _scrollCtrl.animateTo(max, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
    }
  }

  void _newChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('新对话', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: const Text('将清空当前对话记录，确定吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try { await ApiService().delete('/ai/history'); } catch (_) {}
              if (mounted) setState(() => _messages.clear());
            },
            child: const Text('确定', style: TextStyle(color: Color(0xFFFF2442))),
          ),
        ],
      ),
    );
  }

  void _showBubbleMenu(int index, BuildContext bubbleCtx) {
    final msg = _messages[index];
    final isUser = msg.role == 'user';
    final overlay = Overlay.of(context);
    final box = bubbleCtx.findRenderObject() as RenderBox;
    final overlayBox = overlay.context.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final size = box.size;
    final screenSize = MediaQuery.of(context).size;

    final items = <_MenuItem>[];
    items.add(_MenuItem(Icons.copy, '复制', () {
      Clipboard.setData(ClipboardData(text: msg.content));
      AppToast.success(context, message: '已复制');
    }));
    if (!isUser) {
      items.add(_MenuItem(Icons.refresh, '重新生成', () {
        _regenerate(index);
      }));
    }

    double menuW = items.length * 64.0;
    double menuH = 40.0;
    double left = (pos.dx + size.width / 2 - menuW / 2).clamp(8.0, screenSize.width - menuW - 8);
    double top = pos.dy - menuH - 8;
    if (top < screenSize.height * 0.12) top = pos.dy + size.height + 8;

    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (_) => GestureDetector(
        onTap: () { entry?.remove(); if (mounted) setState(() {}); },
        behavior: HitTestBehavior.opaque,
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Container(color: Colors.black.withValues(alpha: 0.08)),
              Positioned(
                left: left, top: top,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    height: menuH,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3C3C3C),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: items.map((item) {
                        return GestureDetector(
                          onTap: () {
                            entry?.remove();
                            if (mounted) setState(() {});
                            item.onTap();
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 64, height: menuH,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(item.icon, size: 14, color: Colors.white),
                                const SizedBox(height: 2),
                                Text(item.label, style: const TextStyle(fontSize: 10, color: Colors.white, decoration: TextDecoration.none)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    overlay.insert(entry);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          _buildAppBar(statusBarH),
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildAppBar(double statusBarH) {
    return Container(
      padding: EdgeInsets.only(top: statusBarH),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 0.5)),
      ),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Icon(Icons.arrow_back, size: 20, color: Color(0xFF222222)),
              ),
            ),
            const Expanded(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: Color(0xFFFF2442)),
                    SizedBox(width: 4),
                    Text('智能助手', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF222222))),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: _newChat,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Icon(Icons.add_comment_outlined, size: 20, color: Color(0xFF555555)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator(radius: 14, color: Color(0xFFFF2442)));
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64, height: 64,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Icon(Icons.auto_awesome, size: 28, color: Colors.white)),
            ),
            const SizedBox(height: 16),
            const Text('你好，我是留笔AI助手', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
            const SizedBox(height: 8),
            const Text('有什么我可以帮助你的吗？', style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8, runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestionChip('帮我写一段文艺文案'),
                _buildSuggestionChip('推荐几首好歌'),
                _buildSuggestionChip('讲个故事吧'),
                _buildSuggestionChip('推荐美食'),
              ],
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _messages.length) return _buildTypingIndicator();
        return _buildMessageBubble(_messages[i], i);
      },
    );
  }

  Widget _buildSuggestionChip(String text) {
    return GestureDetector(
      onTap: () {
        _inputCtrl.text = text;
        _sendMessage();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
        ),
        child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF555555))),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg, int index) {
    final isUser = msg.role == 'user';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Icon(Icons.auto_awesome, size: 16, color: Colors.white)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Builder(builder: (bubbleCtx) {
              return GestureDetector(
                onLongPress: () => _showBubbleMenu(index, bubbleCtx),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFFFF2442) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    boxShadow: isUser ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: isUser
                      ? Text(msg.content, style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.5))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MarkdownBody(
                              data: msg.content,
                              builders: {
                                'pre': _CodeBlockBuilder(),
                                'code': _InlineCodeBuilder(),
                              },
                              styleSheet: MarkdownStyleSheet(
                                p: const TextStyle(fontSize: 15, color: Color(0xFF222222), height: 1.6),
                                h2: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF222222)),
                                listBullet: const TextStyle(fontSize: 15, color: Color(0xFF222222)),
                              ),
                              selectable: false,
                            ),
                            if (msg.isStreaming)
                              _buildStreamingCursor(),
                          ],
                        ),
                ),
              );
            }),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: getColorForId(0),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Icon(Icons.person, size: 16, color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStreamingCursor() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 2),
        _StreamingCursor(),
      ],
    );
  }

  Widget _buildTypingIndicator() {
    if (!_dotCtrl.isAnimating) _dotCtrl.repeat();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Icon(Icons.auto_awesome, size: 16, color: Colors.white)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: AnimatedBuilder(
              animation: _dotCtrl,
              builder: (_, __) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final t = (_dotCtrl.value * 3 + i) % 1.0;
                    final scale = 0.5 + 0.5 * (1 - (t * 2 - 1).abs());
                    final opacity = 0.3 + 0.7 * (1 - (t * 2 - 1).abs());
                    return Container(
                      margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: Color(0xFFFF2442).withValues(alpha: opacity),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0F0F0), width: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 100),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _inputCtrl,
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  style: const TextStyle(fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: '输入消息...',
                    hintStyle: TextStyle(fontSize: 15, color: Color(0xFFBBBBBB)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: _sending
                      ? const LinearGradient(colors: [Color(0xFFCCCCCC), Color(0xFFDDDDDD)])
                      : const LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]),
                  shape: BoxShape.circle,
                  boxShadow: _sending
                      ? []
                      : [BoxShadow(color: const Color(0xFFFF2442).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: _sending
                    ? const CupertinoActivityIndicator(radius: 10, color: Colors.white)
                    : const Icon(Icons.send, size: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreamingCursor extends StatefulWidget {
  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _ctrl.repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl.drive(Tween(begin: 0.3, end: 1.0).chain(CurveTween(curve: Curves.easeInOut))),
      child: Container(
        width: 2, height: 16,
        decoration: BoxDecoration(
          color: const Color(0xFFFF2442),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _MenuItem(this.icon, this.label, this.onTap);
}

class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfterWithContext(BuildContext context, md.Element element, _, __) {
    final codeEl = element.children?.firstWhere((c) => c is md.Element && c.tag == 'code', orElse: () => md.Element.empty('code')) as md.Element?;
    String lang = codeEl?.attributes['class']?.replaceFirst('language-', '') ?? '';
    String code = codeEl?.textContent ?? element.textContent;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF313244), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: const BoxDecoration(
              color: Color(0xFF181825),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Row(children: [
                  Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFFF5F57), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFFFBD2E), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF28C840), shape: BoxShape.circle)),
                ]),
                const SizedBox(width: 12),
                Expanded(child: Text(lang.isEmpty ? 'code' : lang, style: const TextStyle(fontSize: 11, color: Color(0xFF6C7086), fontWeight: FontWeight.w500))),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    AppToast.success(context, message: '已复制代码');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF313244), borderRadius: BorderRadius.circular(4)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.copy, size: 11, color: Color(0xFF6C7086)),
                      SizedBox(width: 3),
                      Text('复制', style: TextStyle(fontSize: 10, color: Color(0xFF6C7086), fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              code,
              style: const TextStyle(fontSize: 13, color: Color(0xFFCDD6F4), fontFamily: 'monospace', height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineCodeBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfterWithContext(BuildContext context, md.Element element, _, __) {
    final code = element.textContent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(color: const Color(0xFFF1F3F5), borderRadius: BorderRadius.circular(3)),
      child: Text(code, style: const TextStyle(fontSize: 13, color: Color(0xFFE74C3C), fontFamily: 'monospace')),
    );
  }
}
