import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../services/chat_service.dart';
import '../utils/helpers.dart';
import '../utils/emoji_text.dart';
import '../models/conversation.dart';
import 'main_screen.dart';

class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  List<Conversation> _conversations = [];
  bool _loading = true;
  int _likeCount = 0;
  int _followCount = 0;
  int _commentCount = 0;
  StreamSubscription? _msgSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    final cs = Provider.of<ChatService>(context, listen: false);
    if (!cs.isConnected) cs.connect();
    _msgSub = cs.onMessage.listen((msg) {
      if (!mounted) return;
      if (msg['type'] == 'chat') {
        _loadConversations();
      } else if (msg['type'] == 'notification') {
        _loadUnread();
      }
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadConversations(), _loadUnread()]);
  }

  Future<void> _loadUnread() async {
    try {
      final res = await ApiService().get('/notifications/unread');
      if (res['code'] == 200 && mounted) {
        final data = res['data'] as Map<String, dynamic>? ?? {};
        setState(() {
          _likeCount = data['like_count'] as int? ?? 0;
          _followCount = data['follow_count'] as int? ?? 0;
          _commentCount = data['comment_count'] as int? ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadConversations() async {
    try {
      final res = await ApiService().get('/chat/conversations');
      if (res['code'] == 200 && mounted) {
        final list = res['data'] as List? ?? [];
        var convs = list.map((e) => Conversation.fromJson(e as Map<String, dynamic>)).toList();
        convs.sort((a, b) {
          final aPinned = a.isPinned;
          final bPinned = b.isPinned;
          if (aPinned && !bPinned) return -1;
          if (!aPinned && bPinned) return 1;
          final aTime = DateTime.tryParse(a.lastTime) ?? DateTime(2000);
          final bTime = DateTime.tryParse(b.lastTime) ?? DateTime(2000);
          return bTime.compareTo(aTime);
        });
        setState(() {
          _conversations = convs;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCreateGroup() {
    final nameCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, ms) {
        return Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 8), decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2))),
            Padding(padding: const EdgeInsets.all(16), child: Text('创建群聊', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF222222)))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Container(decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)), child: TextField(controller: nameCtrl, style: const TextStyle(fontSize: 14), decoration: const InputDecoration(hintText: '群聊名称', hintStyle: TextStyle(fontSize: 14, color: Color(0xFFBBBBBB)), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12))))),
            const SizedBox(height: 20),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: GestureDetector(onTap: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await ApiService().post('/chat/conversation/group', data: {'name': nameCtrl.text.trim(), 'member_ids': <int>[]});
              if (ctx.mounted) { Navigator.pop(ctx); _loadConversations(); }
            }, child: Container(width: double.infinity, height: 44, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]), borderRadius: BorderRadius.circular(22)), alignment: Alignment.center, child: const Text('创建', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600))))),
            const SizedBox(height: 30),
          ]),
        );
      }),
    );
  }

  void _showJoinGroup() {
    final codeCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, ms) {
        return Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 8), decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2))),
            Padding(padding: const EdgeInsets.all(16), child: Text('加入群聊', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF222222)))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Container(decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)), child: TextField(controller: codeCtrl, style: const TextStyle(fontSize: 14), decoration: const InputDecoration(hintText: '群聊码', hintStyle: TextStyle(fontSize: 14, color: Color(0xFFBBBBBB)), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12))))),
            const SizedBox(height: 20),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: GestureDetector(onTap: () async {
              if (codeCtrl.text.trim().isEmpty) return;
              await ApiService().post('/chat/conversation/join', data: {'group_code': codeCtrl.text.trim()});
              if (ctx.mounted) { Navigator.pop(ctx); _loadConversations(); }
            }, child: Container(width: double.infinity, height: 44, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]), borderRadius: BorderRadius.circular(22)), alignment: Alignment.center, child: const Text('加入', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600))))),
            const SizedBox(height: 30),
          ]),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    return Consumer<UserProvider>(
      builder: (_, userProvider, __) {
        final isLoggedIn = userProvider.isLoggedIn;
        return Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              Container(
                padding: EdgeInsets.only(top: statusBarH),
                color: Colors.white,
                child: SizedBox(
                  height: 44,
                  child: Stack(
                    children: [
                      const Center(child: Text('消息', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF222222)))),
                      Positioned(
                        right: 8, top: 0, bottom: 0,
                        child: Consumer<UserProvider>(builder: (_, up, ___) {
                          final isAdmin = up.userInfo?.role == 1;
                          return Row(mainAxisSize: MainAxisSize.min, children: [
                            if (isAdmin) GestureDetector(onTap: _showJoinGroup, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.group_add_outlined, size: 20, color: Color(0xFF555555)))),
                            GestureDetector(onTap: _showCreateGroup, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.add, size: 22, color: Color(0xFF555555)))),
                          ]);
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: !isLoggedIn
                    ? _buildNotLoggedIn()
                    : _loading
                        ? const Center(child: CupertinoActivityIndicator(radius: 14, color: Color(0xFFFF2442)))
                        : CustomScrollView(
                            slivers: [
                              CupertinoSliverRefreshControl(onRefresh: _loadData),
                              SliverToBoxAdapter(child: _buildNotificationCards()),
                              SliverToBoxAdapter(child: _buildAIAssistant()),
                              if (_conversations.isNotEmpty)
                                SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (_, i) => _buildConversationItem(_conversations[i]),
                                    childCount: _conversations.length,
                                  ),
                                ),
                              if (_conversations.isEmpty)
                                const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: 60), child: Center(child: Text('暂无消息', style: TextStyle(fontSize: 14, color: Color(0xFF999999)))))),
                            ],
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotLoggedIn() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset('assets/icons/app_icon.png', width: 72, height: 72, fit: BoxFit.cover),
          ),
          const SizedBox(height: 12),
          const Text('留笔', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF222222))),
          const SizedBox(height: 12),
          const Text('登录后查看消息', style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/login'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]), borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: const Color(0xFFFF2442).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]),
              child: const Text('登录', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(child: _buildNotifCard('赞和收藏', _likeCount, const [Color(0xFFFF2442), Color(0xFFFF5A6E)], Icons.favorite)),
          const SizedBox(width: 8),
          Expanded(child: _buildNotifCard('新增关注', _followCount, const [Color(0xFF1890FF), Color(0xFF40A9FF)], Icons.person_add)),
          const SizedBox(width: 8),
          Expanded(child: _buildNotifCard('评论和@', _commentCount, const [Color(0xFF52C41A), Color(0xFF73D13D)], Icons.chat_bubble)),
        ],
      ),
    );
  }

  Widget _buildNotifCard(String label, int count, List<Color> colors, IconData icon) {
    return GestureDetector(
      onTap: () async {
        final type = label == '赞和收藏' ? 'like' : label == '新增关注' ? 'follow' : 'comment';
        await Navigator.pushNamed(context, '/notifications', arguments: type);
        _loadUnread();
        MainScreen.onUnreadNeedsRefresh?.call();
      },
      child: Column(
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(gradient: LinearGradient(colors: colors), shape: BoxShape.circle, boxShadow: [BoxShadow(color: colors[0].withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]),
                  child: Center(child: Icon(icon, size: 22, color: Colors.white)),
                ),
                if (count > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      padding: EdgeInsets.symmetric(horizontal: count > 9 ? 4 : (count > 1 ? 3 : 0)),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF23030),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(child: Text(count > 99 ? '99+' : '$count', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500, height: 1.2)))),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF333333))),
        ],
      ),
    );
  }

  Widget _buildAIAssistant() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/ai-chat'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFFE0E0), width: 0.5)),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]), shape: BoxShape.circle),
              child: const Center(child: Text('AI', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w800))),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('智能助手', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
                  const SizedBox(width: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: const Color(0xFFFF2442).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3)), child: const Text('智能', style: TextStyle(fontSize: 9, color: Color(0xFFFF2442), fontWeight: FontWeight.w600))),
                ]),
                const SizedBox(height: 2),
                const Text('你的AI助手', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24 && date.day == now.day) return '${diff.inHours}小时前';
    if (diff.inDays == 1) return '昨天';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}周前';
    if (date.year == now.year) return '${date.month}月${date.day}日';
    return '${date.year}年${date.month}月';
  }

  String _formatLastMsg(Conversation conv) {
    String msg = conv.lastMessage;
    if (msg.startsWith('/uploads/')) {
      if (msg.endsWith('.m4a') || msg.endsWith('.mp3') || msg.endsWith('.wav')) {
        return '[语音]';
      } else if (msg.endsWith('.jpg') || msg.endsWith('.jpeg') || msg.endsWith('.png') || msg.endsWith('.gif')) {
        return '[图片]';
      }
    }
    return stripEmojiMarkers(msg);
  }

  Widget _buildConversationItem(Conversation conv) {
    final isGroup = conv.type == 2;
    final isPinned = conv.isPinned;
    return GestureDetector(
      onTap: () async {
        await Navigator.pushNamed(context, '/chat', arguments: {'id': conv.id, 'name': conv.name, 'avatar': conv.avatar, 'otherUserId': conv.otherUserId});
        _loadData();
        MainScreen.onUnreadNeedsRefresh?.call();
      },
      onLongPressStart: (details) => _showConvMenu(conv, details.globalPosition),
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: isPinned ? const Color(0xFFF5F5F5) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                if (isGroup)
                  _buildGroupAvatar(conv)
                else
                  _buildSingleAvatar(conv),
                if (conv.unreadCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: EdgeInsets.symmetric(horizontal: conv.unreadCount > 9 ? 5 : (conv.unreadCount > 1 ? 4 : 0)),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF23030),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Center(child: Text(conv.unreadCount > 99 ? '99+' : '${conv.unreadCount}', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500, height: 1.2), textAlign: TextAlign.center)),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Row(children: [
                        Flexible(child: Text(conv.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF333333)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        if (isGroup) ...[
                          const SizedBox(width: 4),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: const Color(0xFF1890FF), borderRadius: BorderRadius.circular(2)), child: Text('群聊', style: const TextStyle(fontSize: 9, color: Colors.white))),
                          const SizedBox(width: 4),
                          Text('${conv.memberCount}人', style: const TextStyle(fontSize: 10, color: Color(0xFFBBBBBB))),
                        ],
                      ])),
                      Text(_formatTime(conv.lastTime), style: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB))),
                    ],
                  ),
                  const SizedBox(height: 4),
          Text(_formatLastMsg(conv), style: const TextStyle(fontSize: 13, color: Color(0xFF999999)), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConvMenu(Conversation conv, Offset position) {
    final menuW = 150.0;
    final menuH = 48.0 * 3 + 8;
    final screenW = MediaQuery.of(context).size.width;
    double left = position.dx - menuW / 2;
    double top = position.dy - menuH - 8;
    if (left < 12) left = 12;
    if (left + menuW > screenW - 12) left = screenW - 12 - menuW;
    if (top < MediaQuery.of(context).padding.top + 56) top = position.dy + 8;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => Stack(children: [
      GestureDetector(onTap: () => entry.remove(), behavior: HitTestBehavior.opaque, child: const SizedBox.expand()),
      Positioned(
        left: left, top: top,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: menuW,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _menuItem(conv.isPinned ? Icons.push_pin : Icons.push_pin_outlined, conv.isPinned ? '取消置顶' : '置顶', const Color(0xFF333333), () {
                  entry.remove();
                  final newPinned = !conv.isPinned;
                  setState(() {
                    conv.isPinned = newPinned;
                    _conversations.sort((a, b) {
                      if (a.isPinned && !b.isPinned) return -1;
                      if (!a.isPinned && b.isPinned) return 1;
                      final aTime = DateTime.tryParse(a.lastTime) ?? DateTime(2000);
                      final bTime = DateTime.tryParse(b.lastTime) ?? DateTime(2000);
                      return bTime.compareTo(aTime);
                    });
                  });
                  ApiService().post('/chat/conversation/pin', data: {'conversation_id': conv.id, 'pinned': newPinned});
                  MainScreen.onUnreadNeedsRefresh?.call();
                }),
                const Divider(height: 0.5, thickness: 0.5, indent: 40, endIndent: 8, color: Color(0xFFF0F0F0)),
                _menuItem(Icons.done_all, conv.unreadCount > 0 ? '标为已读' : '标为未读', const Color(0xFF333333), () {
                  entry.remove();
                  if (conv.unreadCount > 0) {
                    setState(() { conv.unreadCount = 0; });
                    ApiService().post('/chat/conversation/read', data: {'conversation_id': conv.id});
                    MainScreen.onUnreadNeedsRefresh?.call();
                  } else {
                    setState(() { conv.unreadCount = 1; });
                    MainScreen.onUnreadNeedsRefresh?.call();
                  }
                }),
                const Divider(height: 0.5, thickness: 0.5, indent: 40, endIndent: 8, color: Color(0xFFF0F0F0)),
                _menuItem(Icons.delete_outline, '删除', const Color(0xFFF23030), () {
                  entry.remove();
                  setState(() { _conversations.removeWhere((c) => c.id == conv.id); });
                  ApiService().post('/chat/conversation/hide', data: {'conversation_id': conv.id});
                  MainScreen.onUnreadNeedsRefresh?.call();
                }),
              ]),
            ),
          ),
        ),
      ),
    ]));
    overlay.insert(entry);
  }

  Widget _menuItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(height: 48, child: Row(children: [
        const SizedBox(width: 14),
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w400)),
      ])),
    );
  }

  Widget _buildSingleAvatar(Conversation conv) {
    final avatarSrc = conv.avatar.isNotEmpty ? conv.avatar : (conv.memberAvatars.isNotEmpty ? conv.memberAvatars.first : '');
    final avatarUrl = fullUrl(avatarSrc);
    final colorId = conv.otherUserId > 0 ? conv.otherUserId : conv.id;
    return CircleAvatar(
      radius: 24,
      backgroundImage: avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
      backgroundColor: avatarUrl.isEmpty ? getColorForId(colorId) : null,
      child: avatarUrl.isEmpty ? Text(conv.name.isNotEmpty ? conv.name[0] : '?', style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600)) : null,
    );
  }

  Widget _buildGroupAvatar(Conversation conv) {
    final avatars = conv.memberAvatars.take(4).toList();
    final names = conv.memberNames.take(4).toList();
    final ids = conv.memberIds.take(4).toList();
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: const Color(0xFFF0F0F0), shape: BoxShape.circle),
      child: avatars.isEmpty
          ? Container(decoration: BoxDecoration(color: getColorForId(conv.id), shape: BoxShape.circle), alignment: Alignment.center, child: Text(conv.name.isNotEmpty ? conv.name[0] : '?', style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600)))
          : ClipOval(
              child: GridView.count(
                crossAxisCount: 2,
                padding: const EdgeInsets.all(2),
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(avatars.length.clamp(0, 4), (i) {
                  final url = fullUrl(avatars[i]);
                  final name = i < names.length ? names[i] : '?';
                  final id = i < ids.length ? ids[i] : avatars[i].hashCode;
                  return Padding(
                    padding: const EdgeInsets.all(1),
                    child: ClipOval(
                      child: url.isNotEmpty
                          ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: getColorForId(id), alignment: Alignment.center, child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w600))))
                          : Container(color: getColorForId(id), alignment: Alignment.center, child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w600))),
                    ),
                  );
                }),
              ),
            ),
    );
  }
}
