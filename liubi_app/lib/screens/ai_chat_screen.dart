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
  int? id;
  final String role;
  String content;
  final DateTime? createdAt;
  bool isStreaming;
  bool isLiked;
  bool isDisliked;
  _ChatMessage({this.id, required this.role, required this.content, this.createdAt, this.isStreaming = false, this.isLiked = false, this.isDisliked = false});
}

class _AiConversation {
  final int id;
  String title;
  final String? lastMessage;
  final String? updatedAt;
  _AiConversation({required this.id, required this.title, this.lastMessage, this.updatedAt});
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
  final _sidebarSearchCtrl = TextEditingController();
  final _editCtrl = TextEditingController();
  final _inputFocusNode = FocusNode();
  bool _isLoading = false;
  bool _sending = false;
  late AnimationController _dotCtrl;
  int? _currentConvId;
  List<_AiConversation> _conversations = [];
  List<_AiConversation> _filteredConversations = [];
  bool _showSidebar = false;
  late AnimationController _sidebarCtrl;
  late Animation<Offset> _sidebarSlide;
  int? _editingIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dotCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _sidebarCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _sidebarSlide = Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero).animate(
      CurvedAnimation(parent: _sidebarCtrl, curve: Curves.easeOutCubic),
    );
    _inputCtrl.addListener(() => setState(() {}));
    _sidebarSearchCtrl.addListener(() {
      final q = _sidebarSearchCtrl.text.toLowerCase();
      setState(() {
        _filteredConversations = q.isEmpty
            ? _conversations
            : _conversations.where((c) => c.title.toLowerCase().contains(q)).toList();
      });
    });
    _loadConversations();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _scrollToBottom();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dotCtrl.dispose();
    _sidebarCtrl.dispose();
    _inputCtrl.dispose();
    _sidebarSearchCtrl.dispose();
    _editCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  Future<void> _loadConversations() async {
    try {
      final res = await ApiService().get('/ai/conversations');
      if (res['code'] == 200 && mounted) {
        final list = res['data'] as List? ?? [];
        setState(() {
          _conversations = list.map((e) => _AiConversation(
            id: e['id'] as int,
            title: e['title'] as String? ?? '新对话',
            lastMessage: e['last_message'] as String?,
            updatedAt: e['updated_at'] as String?,
          )).toList();
          _filteredConversations = _conversations;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadConversation(int convId) async {
    _dismissKeyboard();
    setState(() { _isLoading = true; _messages.clear(); _currentConvId = convId; _showSidebar = false; });
    _sidebarCtrl.reverse();
    try {
      final res = await ApiService().get('/ai/history?conversation_id=$convId');
      if (res['code'] == 200 && mounted) {
        final list = res['data'] as List? ?? [];
        setState(() {
          _messages.addAll(list.map((e) => _ChatMessage(
            id: e['id'] as int?,
            role: e['role'] ?? 'user',
            content: e['content'] ?? '',
            createdAt: e['created_at'] != null ? DateTime.tryParse(e['created_at']) : null,
            isLiked: e['is_liked'] == 1,
            isDisliked: e['is_disliked'] == 1,
          )));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _newChat() async {
    _dismissKeyboard();
    setState(() { _messages.clear(); _currentConvId = null; _showSidebar = false; });
    _sidebarCtrl.reverse();
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    _inputCtrl.clear();
    _dismissKeyboard();
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
        if (_currentConvId != null) 'conversation_id': _currentConvId,
      });

      if (res['code'] == 200 && mounted) {
        final fullContent = res['data']?['content'] ?? '抱歉，我暂时无法回答';
        final newConvId = res['data']?['conversation_id'] as int?;
        final newMsgId = res['data']?['message_id'] as int?;
        if (newConvId != null && _currentConvId == null) {
          _currentConvId = newConvId;
          _loadConversations();
        }
        final aiMsg = _ChatMessage(id: newMsgId, role: 'assistant', content: '', createdAt: DateTime.now(), isStreaming: true);
        setState(() => _messages.add(aiMsg));
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
      _messages.removeAt(index);
      _sending = true;
    });

    try {
      final chatMsgs = _messages
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final lastUserMsg = chatMsgs.lastWhere((m) => m['role'] == 'user', orElse: () => {'content': ''});

      final res = await ApiService().post('/ai/chat', data: {
        'messages': chatMsgs,
        'userMessage': lastUserMsg['content'] ?? '',
        if (_currentConvId != null) 'conversation_id': _currentConvId,
      });

      if (res['code'] == 200 && mounted) {
        final fullContent = res['data']?['content'] ?? '抱歉，我暂时无法回答';
        final newMsgId = res['data']?['message_id'] as int?;
        final aiMsg = _ChatMessage(id: newMsgId, role: 'assistant', content: '', createdAt: DateTime.now(), isStreaming: true);
        setState(() => _messages.add(aiMsg));
        await _typewriterEffect(aiMsg, fullContent);
      } else if (mounted) {
        AppToast.error(context, message: res['msg'] ?? '重新生成失败');
      }
    } catch (_) {
      if (mounted) AppToast.error(context, message: '网络错误');
    }

    if (mounted) {
      setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  Future<void> _toggleLike(int index) async {
    final msg = _messages[index];
    if (msg.role != 'assistant') return;
    setState(() {
      msg.isLiked = !msg.isLiked;
      if (msg.isLiked) msg.isDisliked = false;
    });
    if (msg.id != null) {
      try {
        await ApiService().post('/ai/messages/feedback', data: {
          'message_id': msg.id,
          'action': msg.isLiked ? 'like' : 'cancel',
        });
      } catch (_) {}
    }
  }

  Future<void> _toggleDislike(int index) async {
    final msg = _messages[index];
    if (msg.role != 'assistant') return;
    setState(() {
      msg.isDisliked = !msg.isDisliked;
      if (msg.isDisliked) msg.isLiked = false;
    });
    if (msg.id != null) {
      try {
        await ApiService().post('/ai/messages/feedback', data: {
          'message_id': msg.id,
          'action': msg.isDisliked ? 'dislike' : 'cancel',
        });
      } catch (_) {}
    }
  }

  void _startEdit(int index) {
    final msg = _messages[index];
    if (msg.role != 'user') return;
    _dismissKeyboard();
    _editCtrl.text = msg.content;
    setState(() => _editingIndex = index);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('编辑消息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close, size: 20, color: Color(0xFF999999)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _editCtrl,
                maxLines: null,
                autofocus: true,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: '输入消息...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  final text = _editCtrl.text.trim();
                  if (text.isNotEmpty) {
                    setState(() {
                      _messages[index].content = text;
                    });
                    Navigator.pop(ctx);
                    setState(() {
                      _messages.removeRange(index + 1, _messages.length);
                    });
                    _inputCtrl.text = text;
                    _sendMessage();
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF2442),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text('发送', style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) => setState(() => _editingIndex = null));
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      return;
    }
    final max = _scrollCtrl.position.maxScrollExtent;
    final current = _scrollCtrl.offset;
    if (max - current < 200) {
      _scrollCtrl.jumpTo(max);
    } else {
      _scrollCtrl.animateTo(max, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
    }
  }

  void _toggleSidebar() {
    _dismissKeyboard();
    setState(() => _showSidebar = !_showSidebar);
    if (_showSidebar) {
      _sidebarCtrl.forward();
      _loadConversations();
    } else {
      _sidebarSearchCtrl.clear();
      _sidebarCtrl.reverse();
    }
  }

  void _closeSidebar() {
    _dismissKeyboard();
    _sidebarSearchCtrl.clear();
    setState(() => _showSidebar = false);
    _sidebarCtrl.reverse();
  }

  Future<void> _deleteConversation(int convId) async {
    try {
      await ApiService().delete('/ai/conversations/$convId');
      _loadConversations();
      if (_currentConvId == convId) {
        _newChat();
      }
    } catch (_) {}
  }

  Future<void> _renameConversation(int convId, String newTitle) async {
    try {
      await ApiService().put('/ai/conversations/$convId', data: {'title': newTitle});
      _loadConversations();
    } catch (_) {}
  }

  void _showConvActions(_AiConversation conv) {
    _dismissKeyboard();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Color(0xFF222222), size: 20),
              title: const Text('备注', style: TextStyle(fontSize: 15)),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(conv);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFFF2442), size: 20),
              title: const Text('删除', style: TextStyle(color: Color(0xFFFF2442), fontSize: 15)),
              onTap: () { Navigator.pop(ctx); _deleteConversation(conv.id); },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(_AiConversation conv) {
    final ctrl = TextEditingController(text: conv.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('备注对话', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: '输入对话名称'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isNotEmpty) {
                _renameConversation(conv.id, text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('确定', style: TextStyle(color: Color(0xFFFF2442))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    return PopScope(
      canPop: !_showSidebar,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showSidebar) {
          _closeSidebar();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            Column(
              children: [
                _buildAppBar(statusBarH),
                Expanded(child: _buildMessageList()),
                _buildInputBar(),
              ],
            ),
            if (_showSidebar) _buildSidebarOverlay(),
            if (_showSidebar) _buildSidebar(statusBarH),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarOverlay() {
    return GestureDetector(
      onTap: _closeSidebar,
      child: AnimatedBuilder(
        animation: _sidebarCtrl,
        builder: (_, __) {
          return Container(
            color: Colors.black.withValues(alpha: 0.25 * _sidebarCtrl.value),
          );
        },
      ),
    );
  }

  Widget _buildSidebar(double statusBarH) {
    return SlideTransition(
      position: _sidebarSlide,
      child: Container(
        width: 300,
        color: Colors.white,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    const Text('留笔AI', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFFFF2442))),
                    const Spacer(),
                    GestureDetector(
                      onTap: _closeSidebar,
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(18)),
                        child: const Icon(Icons.close, size: 18, color: Color(0xFF666666)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(width: 12),
                      const Icon(Icons.search, size: 18, color: Color(0xFF999999)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _sidebarSearchCtrl,
                          style: const TextStyle(fontSize: 14, height: 1.2),
                          textAlignVertical: TextAlignVertical.center,
                          decoration: const InputDecoration(
                            hintText: '搜索对话',
                            hintStyle: TextStyle(fontSize: 14, color: Color(0xFFBBBBBB), height: 1.2),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isCollapsed: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () {
                    _closeSidebar();
                    Navigator.of(context).pushNamed('/ai-image');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.brush_outlined, size: 18, color: Color(0xFFFF2442)),
                        SizedBox(width: 10),
                        Text('AI绘画', style: TextStyle(fontSize: 14, color: Color(0xFF222222), fontWeight: FontWeight.w500)),
                        Spacer(),
                        Icon(Icons.chevron_right, size: 18, color: Color(0xFF999999)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('最近', style: TextStyle(fontSize: 12, color: Color(0xFF999999), fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildSidebarSection(_filteredConversations)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: _newChat,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222222),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text('新对话', style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500)),
                      ],
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

  Widget _buildSidebarSection(List<_AiConversation> list) {
    return list.isEmpty
        ? const Center(child: Text('暂无对话', style: TextStyle(fontSize: 13, color: Color(0xFFBBBBBB))))
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: list.length,
            itemBuilder: (_, i) => _buildConvItem(list[i]),
          );
  }

  Widget _buildConvItem(_AiConversation conv) {
    final isActive = conv.id == _currentConvId;
    return GestureDetector(
      onTap: () => _loadConversation(conv.id),
      onLongPress: () => _showConvActions(conv),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFF5F5F5) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          conv.title,
          style: TextStyle(
            fontSize: 14,
            color: isActive ? const Color(0xFF222222) : const Color(0xFF666666),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildAppBar(double statusBarH) {
    return Container(
      padding: EdgeInsets.only(top: statusBarH),
      color: Colors.white,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Icon(Icons.arrow_back, size: 22, color: Color(0xFF222222)),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _toggleSidebar,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Icon(Icons.menu_open_outlined, size: 22, color: Color(0xFF222222)),
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
              width: 56, height: 56,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Icon(Icons.auto_awesome, size: 24, color: Colors.white)),
            ),
            const SizedBox(height: 20),
            const Text('你好，我是留笔AI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
            const SizedBox(height: 8),
            const Text('有什么我可以帮你的吗？', style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
            const SizedBox(height: 32),
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

    final hasStreamingAi = _messages.any((m) => m.role == 'assistant' && m.isStreaming);
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: _messages.length + (_sending && !hasStreamingAi ? 1 : 0),
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
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF555555))),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg, int index) {
    final isUser = msg.role == 'user';
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: isUser ? () => _startEdit(index) : null,
                      child: isUser
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(msg.content, style: const TextStyle(fontSize: 15, color: Color(0xFF222222), height: 1.5)),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (msg.content.isEmpty && msg.isStreaming)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 0, top: 2),
                                    child: _buildStreamingDot(),
                                  )
                                else ...[
                                  MarkdownBody(
                                    data: msg.content,
                                    builders: {'pre': _CodeBlockBuilder(), 'code': _InlineCodeBuilder()},
                                    styleSheet: MarkdownStyleSheet(
                                      p: const TextStyle(fontSize: 15, color: Color(0xFF222222), height: 1.6),
                                      h2: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF222222)),
                                      listBullet: const TextStyle(fontSize: 15, color: Color(0xFF222222)),
                                    ),
                                    selectable: true,
                                  ),
                                  if (msg.isStreaming) _buildStreamingCursor(),
                                ],
                              ],
                            ),
                    ),
                    if (!isUser && !msg.isStreaming)
                      Padding(
                        padding: const EdgeInsets.only(left: 0, top: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ActionBtn(
                              icon: msg.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                              isActive: msg.isLiked,
                              activeColor: const Color(0xFFFF2442),
                              onTap: () => _toggleLike(index),
                            ),
                            _ActionBtn(
                              icon: msg.isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                              isActive: msg.isDisliked,
                              activeColor: const Color(0xFFFF2442),
                              onTap: () => _toggleDislike(index),
                            ),
                            _ActionBtn(
                              icon: Icons.copy_outlined,
                              isActive: false,
                              activeColor: const Color(0xFFFF2442),
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: msg.content));
                                AppToast.success(context, message: '已复制');
                              },
                            ),
                            _ActionBtn(
                              icon: Icons.refresh,
                              isActive: false,
                              activeColor: const Color(0xFFFF2442),
                              onTap: () => _regenerate(index),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreamingDot() {
    if (!_dotCtrl.isAnimating) _dotCtrl.repeat();
    return AnimatedBuilder(
      animation: _dotCtrl,
      builder: (_, __) {
        final t = _dotCtrl.value;
        final opacity = 0.3 + 0.7 * (1 - (2 * t - 1).abs());
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: Color(0xFF999999).withValues(alpha: opacity),
            shape: BoxShape.circle,
          ),
        );
      },
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
      margin: const EdgeInsets.only(bottom: 20, left: 14),
      child: AnimatedBuilder(
        animation: _dotCtrl,
        builder: (_, __) {
          final t = _dotCtrl.value;
          final opacity = 0.3 + 0.7 * (1 - (2 * t - 1).abs());
          return Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Color(0xFF999999).withValues(alpha: opacity),
              shape: BoxShape.circle,
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    final hasText = _inputCtrl.text.trim().isNotEmpty;
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: _inputCtrl,
                focusNode: _inputFocusNode,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: '询问 留笔AI',
                  hintStyle: TextStyle(fontSize: 15, color: Color(0xFFBBBBBB)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (hasText)
            GestureDetector(
              onTap: _sending ? null : _sendMessage,
              child: Container(
                width: 32, height: 32,
                margin: const EdgeInsets.only(left: 4, bottom: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFFFF2442),
                  shape: BoxShape.circle,
                ),
                child: _sending
                    ? const CupertinoActivityIndicator(radius: 8, color: Colors.white)
                    : const Icon(Icons.arrow_upward, size: 18, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatefulWidget {
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant _ActionBtn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      _ctrl.forward(from: 0).then((_) {
        if (mounted) _ctrl.reverse();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, __) {
          final scale = _ctrl.isAnimating ? _scaleAnim.value : 1.0;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: Icon(
                widget.icon,
                size: 18,
                color: widget.isActive ? widget.activeColor : const Color(0xFFBBBBBB),
              ),
            ),
          );
        },
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
      child: Container(width: 2, height: 16, decoration: BoxDecoration(color: const Color(0xFFFF2442), borderRadius: BorderRadius.circular(1))),
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
      decoration: BoxDecoration(color: const Color(0xFF1E1E2E), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF313244), width: 0.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: const BoxDecoration(color: Color(0xFF181825), borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
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
                  onTap: () { Clipboard.setData(ClipboardData(text: code)); AppToast.success(context, message: '已复制代码'); },
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
            child: SelectableText(code, style: const TextStyle(fontSize: 13, color: Color(0xFFCDD6F4), fontFamily: 'monospace', height: 1.5)),
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
