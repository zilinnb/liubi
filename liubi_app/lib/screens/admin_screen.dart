import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../utils/helpers.dart';
import '../widgets/app_toast.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 8, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final res = await ApiService().get('/admin/stats');
      if (res['code'] == 200 && mounted) {
        setState(() => _stats = res['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(top: statusBarH),
            decoration: const BoxDecoration(color: Colors.white),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.arrow_back, size: 20, color: Color(0xFF222222)))),
                  const Expanded(child: Center(child: Text('管理中心', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF222222))))),
                  const SizedBox(width: 46),
                ],
              ),
            ),
          ),
          if (_stats != null)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  _statBox('用户', _stats?['users'] ?? 0, const Color(0xFF4A90D9)),
                  const SizedBox(width: 8),
                  _statBox('帖子', _stats?['posts'] ?? 0, const Color(0xFFFF2442)),
                  const SizedBox(width: 8),
                  _statBox('评论', _stats?['comments'] ?? 0, const Color(0xFFFAAD14)),
                  const SizedBox(width: 8),
                  _statBox('待审', _stats?['pending'] ?? 0, const Color(0xFF52C41A)),
                ],
              ),
            ),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              labelColor: const Color(0xFFFF2442),
              unselectedLabelColor: const Color(0xFF666666),
              indicatorColor: const Color(0xFFFF2442),
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 2,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: '用户'),
                Tab(text: '对话'),
                Tab(text: '审核'),
                Tab(text: '评论'),
                Tab(text: '分类'),
                Tab(text: 'AI助手'),
                Tab(text: '更新'),
                Tab(text: '邮箱'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _UserManageTab(),
                _ConversationManageTab(),
                _PostAuditTab(),
                _CommentManageTab(),
                _CategoryManageTab(),
                _AIConfigTab(),
                _VersionManageTab(),
                _EmailConfigTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }
}

class _UserManageTab extends StatefulWidget {
  @override
  State<_UserManageTab> createState() => _UserManageTabState();
}

class _UserManageTabState extends State<_UserManageTab> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  int _page = 1;
  int _total = 0;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) { _page = 1; _users.clear(); }
    try {
      final params = {'page': '$_page', 'pageSize': '50'};
      if (_searchCtrl.text.trim().isNotEmpty) params['keyword'] = _searchCtrl.text.trim();
      final res = await ApiService().get('/admin/users', queryParameters: params);
      if (res['code'] == 200 && mounted) {
        final data = res['data'] as Map<String, dynamic>;
        setState(() {
          _users = List<Map<String, dynamic>>.from((data['list'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
          _total = data['total'] as int? ?? 0;
          _loading = false;
        });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _updateStatus(int id, int status) async {
    try {
      final res = await ApiService().put('/admin/users/$id/status', data: {'status': status});
      if (res['code'] == 200) { AppToast.success(context, message: '操作成功'); _load(refresh: true); }
    } catch (_) { AppToast.error(context, message: '操作失败'); }
  }

  Future<void> _muteUser(int id, String? muteUntil) async {
    try {
      final res = await ApiService().put('/admin/users/$id/mute', data: {'mute_until': muteUntil});
      if (res['code'] == 200) { AppToast.success(context, message: muteUntil != null ? '禁言成功' : '已解除禁言'); _load(refresh: true); }
    } catch (_) { AppToast.error(context, message: '操作失败'); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CupertinoActivityIndicator(radius: 14));
    return Column(
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), child: Row(children: [
          Expanded(child: Container(height: 36, decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)), child: TextField(controller: _searchCtrl, style: const TextStyle(fontSize: 13), decoration: const InputDecoration(hintText: '搜索用户', hintStyle: TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)), onSubmitted: (_) => _load(refresh: true)))),
          const SizedBox(width: 8),
          GestureDetector(onTap: () => _load(refresh: true), child: Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFFF2442), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.search, size: 18, color: Colors.white))),
        ])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Align(alignment: Alignment.centerLeft, child: Text('共 $_total 个用户', style: const TextStyle(fontSize: 12, color: Color(0xFF999999))))),
        Expanded(child: ListView.builder(itemCount: _users.length, itemBuilder: (_, i) {
          final u = _users[i];
          final status = u['status'] as int? ?? 1;
          final muteUntil = u['mute_until'] as String?;
          final isMuted = muteUntil != null && muteUntil.isNotEmpty;
          final avatar = u['avatar'] as String? ?? '';
          final avatarUrl = fullUrl(avatar);
          return Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
                backgroundColor: avatarUrl.isEmpty ? getColorForId(u['id'] ?? 0) : null,
                child: avatarUrl.isEmpty ? Text((u['nickname'] ?? '?')[0], style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)) : null,
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(u['nickname'] ?? u['username'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF222222)), overflow: TextOverflow.ellipsis)),
                  if (u['role'] == 1) Container(margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: const Color(0xFFFF2442), borderRadius: BorderRadius.circular(4)), child: const Text('管理员', style: TextStyle(fontSize: 9, color: Colors.white))),
                  if (status == 0) Container(margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: const Color(0xFF999999), borderRadius: BorderRadius.circular(4)), child: const Text('已禁用', style: TextStyle(fontSize: 9, color: Colors.white))),
                  if (isMuted) Container(margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: const Color(0xFFFAAD14), borderRadius: BorderRadius.circular(4)), child: const Text('禁言中', style: TextStyle(fontSize: 9, color: Colors.white))),
                ]),
                const SizedBox(height: 2),
                Text('ID: ${u['id']}  粉丝: ${u['fans_count'] ?? 0}  关注: ${u['follow_count'] ?? 0}', style: const TextStyle(fontSize: 11, color: Color(0xFF999999))),
                const SizedBox(height: 2),
                Text('账号: ${u['username'] ?? ''}  邮箱: ${u['email'] ?? ''}', style: const TextStyle(fontSize: 11, color: Color(0xFF999999)), overflow: TextOverflow.ellipsis),
                if (u['location'] != null && (u['location'] as String).isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('IP属地: ${u['location']}', style: const TextStyle(fontSize: 11, color: Color(0xFF999999)), overflow: TextOverflow.ellipsis),
                ],
              ])),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _showEditUserDialog(u);
                  else if (v == 'disable') _updateStatus(u['id'], 0);
                  else if (v == 'enable') _updateStatus(u['id'], 1);
                  else if (v == 'mute') _muteUser(u['id'], DateTime.now().add(const Duration(days: 7)).toIso8601String());
                  else if (v == 'unmute') _muteUser(u['id'], null);
                  else if (v == 'admin') _updateRole(u['id'], 1);
                  else if (v == 'unadmin') _updateRole(u['id'], 0);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('编辑信息', style: TextStyle(color: Color(0xFF4A90D9)))),
                  if (status == 1) const PopupMenuItem(value: 'disable', child: Text('禁用账号', style: TextStyle(color: Color(0xFFFF2442)))),
                  if (status == 0) const PopupMenuItem(value: 'enable', child: Text('启用账号', style: TextStyle(color: Color(0xFF52C41A)))),
                  if (!isMuted) const PopupMenuItem(value: 'mute', child: Text('禁言7天')),
                  if (isMuted) const PopupMenuItem(value: 'unmute', child: Text('解除禁言')),
                  if (u['role'] != 1) const PopupMenuItem(value: 'admin', child: Text('设为管理员')),
                  if (u['role'] == 1) const PopupMenuItem(value: 'unadmin', child: Text('取消管理员')),
                ],
              ),
            ]),
          );
        })),
      ],
    );
  }

  void _showEditUserDialog(Map<String, dynamic> u) {
    final nickCtrl = TextEditingController(text: u['nickname'] ?? '');
    final userCtrl = TextEditingController(text: u['username'] ?? '');
    final emailCtrl = TextEditingController(text: u['email'] ?? '');
    final bioCtrl = TextEditingController(text: u['bio'] ?? '');
    final avatarCtrl = TextEditingController(text: u['avatar'] ?? '');
    int role = u['role'] ?? 0;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, ds) => AlertDialog(
      title: Text('编辑用户 ${u['nickname'] ?? u['username'] ?? ''}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (u['avatar'] != null && (u['avatar'] as String).isNotEmpty)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: CircleAvatar(radius: 32, backgroundImage: CachedNetworkImageProvider(fullUrl(u['avatar'])))),
        _adminField(nickCtrl, '昵称'),
        _adminField(userCtrl, '留笔账号'),
        _adminField(emailCtrl, '邮箱'),
        _adminField(bioCtrl, '简介', maxLines: 3),
        _adminField(avatarCtrl, '头像URL'),
        Row(children: [const Text('管理员: '), Switch(value: role == 1, onChanged: (v) => ds(() => role = v ? 1 : 0))]),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        TextButton(onPressed: () async {
          Navigator.pop(ctx);
          try {
            final res = await ApiService().put('/admin/users/${u['id']}', data: {
              'nickname': nickCtrl.text, 'username': userCtrl.text, 'email': emailCtrl.text,
              'bio': bioCtrl.text, 'avatar': avatarCtrl.text, 'role': role,
            });
            if (res['code'] == 200) { AppToast.success(context, message: '更新成功'); _load(refresh: true); }
            else { AppToast.error(context, message: res['msg'] ?? '更新失败'); }
          } catch (_) { AppToast.error(context, message: '更新失败'); }
        }, child: const Text('保存', style: TextStyle(color: Color(0xFFFF2442)))),
      ],
    )));
  }

  Future<void> _updateRole(int id, int role) async {
    try {
      final res = await ApiService().put('/admin/users/$id', data: {'role': role});
      if (res['code'] == 200) { AppToast.success(context, message: '操作成功'); _load(refresh: true); }
    } catch (_) { AppToast.error(context, message: '操作失败'); }
  }
}

class _ConversationManageTab extends StatefulWidget {
  @override
  State<_ConversationManageTab> createState() => _ConversationManageTabState();
}

class _ConversationManageTabState extends State<_ConversationManageTab> {
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await ApiService().get('/admin/conversations', queryParameters: {'pageSize': '50'});
      if (res['code'] == 200 && mounted) {
        setState(() { _list = List<Map<String, dynamic>>.from(((res['data'] as Map)['list'] as List).map((e) => Map<String, dynamic>.from(e as Map))); _loading = false; });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _delete(int id) async {
    try {
      final res = await ApiService().delete('/admin/conversations/$id');
      if (res['code'] == 200) { AppToast.success(context, message: '已删除'); _load(); }
    } catch (_) { AppToast.error(context, message: '删除失败'); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CupertinoActivityIndicator(radius: 14));
    return ListView.builder(itemCount: _list.length, padding: const EdgeInsets.all(12), itemBuilder: (_, i) {
      final c = _list[i];
      final members = c['members'] as List? ?? [];
      final memberNames = members.map((m) => m['nickname'] ?? m['username'] ?? '').join(', ');
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(c['name'] ?? '会话#${c['id']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
              const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: c['type'] == 1 ? const Color(0xFF4A90D9) : const Color(0xFFFAAD14), borderRadius: BorderRadius.circular(4)), child: Text(c['type'] == 1 ? '私聊' : '群聊', style: const TextStyle(fontSize: 9, color: Colors.white))),
            ]),
            const SizedBox(height: 2),
            Text('成员: $memberNames', style: const TextStyle(fontSize: 11, color: Color(0xFF999999)), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('消息: ${c['msg_count'] ?? 0}条  ${c['last_message'] ?? ''}', style: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          IconButton(onPressed: () => _delete(c['id']), icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFFF2442))),
        ]),
      );
    });
  }
}

class _PostAuditTab extends StatefulWidget {
  @override
  State<_PostAuditTab> createState() => _PostAuditTabState();
}

class _PostAuditTabState extends State<_PostAuditTab> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  int _statusFilter = 2;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('/admin/posts', queryParameters: {'pageSize': '50', 'status': '$_statusFilter'});
      if (res['code'] == 200 && mounted) {
        setState(() { _posts = List<Map<String, dynamic>>.from(((res['data'] as Map)['list'] as List).map((e) => Map<String, dynamic>.from(e as Map))); _loading = false; });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _updateStatus(int id, int status) async {
    try {
      final res = await ApiService().put('/admin/posts/$id/status', data: {'status': status});
      if (res['code'] == 200) { AppToast.success(context, message: '操作成功'); _load(); }
    } catch (_) { AppToast.error(context, message: '操作失败'); }
  }

  Future<void> _deletePost(int id) async {
    try {
      final res = await ApiService().delete('/admin/posts/$id');
      if (res['code'] == 200) { AppToast.success(context, message: '已删除'); _load(); }
    } catch (_) { AppToast.error(context, message: '删除失败'); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), child: Row(children: [
        _filterChip('待审核', 2), const SizedBox(width: 6), _filterChip('已通过', 1), const SizedBox(width: 6), _filterChip('已拒绝', 3), const SizedBox(width: 6), _filterChip('全部', -1),
      ])),
      Expanded(child: _loading ? const Center(child: CupertinoActivityIndicator(radius: 14)) : ListView.builder(itemCount: _posts.length, padding: const EdgeInsets.symmetric(horizontal: 12), itemBuilder: (_, i) {
        final p = _posts[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(p['title'] ?? '无标题', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF222222)), maxLines: 1, overflow: TextOverflow.ellipsis)),
              PopupMenuButton<String>(onSelected: (v) {
                if (v == 'approve') _updateStatus(p['id'], 1);
                else if (v == 'reject') _updateStatus(p['id'], 3);
                else if (v == 'delete') _deletePost(p['id']);
              }, itemBuilder: (_) => [
                const PopupMenuItem(value: 'approve', child: Text('通过审核', style: TextStyle(color: Color(0xFF52C41A)))),
                const PopupMenuItem(value: 'reject', child: Text('拒绝审核', style: TextStyle(color: Color(0xFFFAAD14)))),
                const PopupMenuItem(value: 'delete', child: Text('删除帖子', style: TextStyle(color: Color(0xFFFF2442)))),
              ]),
            ]),
            const SizedBox(height: 4),
            Text('作者: ${p['nickname'] ?? ''}  ID: ${p['id']}', style: const TextStyle(fontSize: 11, color: Color(0xFF999999))),
          ]),
        );
      })),
    ]);
  }

  Widget _filterChip(String label, int status) {
    final isOn = _statusFilter == status;
    return GestureDetector(onTap: () { _statusFilter = status; _load(); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: isOn ? const Color(0xFFFF2442) : const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(14)), child: Text(label, style: TextStyle(fontSize: 12, color: isOn ? Colors.white : const Color(0xFF888888), fontWeight: isOn ? FontWeight.w600 : FontWeight.w400))));
  }
}

class _CommentManageTab extends StatefulWidget {
  @override
  State<_CommentManageTab> createState() => _CommentManageTabState();
}

class _CommentManageTabState extends State<_CommentManageTab> {
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  int _page = 1;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) { _page = 1; _comments.clear(); }
    try {
      final res = await ApiService().get('/admin/comments', queryParameters: {'page': '$_page', 'pageSize': '50'});
      if (res['code'] == 200 && mounted) {
        setState(() { _comments = List<Map<String, dynamic>>.from(((res['data'] as Map)['list'] as List).map((e) => Map<String, dynamic>.from(e as Map))); _loading = false; });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _delete(int id) async {
    try {
      final res = await ApiService().delete('/admin/comments/$id');
      if (res['code'] == 200) { AppToast.success(context, message: '已删除'); _load(refresh: true); }
    } catch (_) { AppToast.error(context, message: '删除失败'); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CupertinoActivityIndicator(radius: 14));
    return RefreshIndicator(onRefresh: () => _load(refresh: true), child: ListView.builder(itemCount: _comments.length, padding: const EdgeInsets.all(12), itemBuilder: (_, i) {
      final c = _comments[i];
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c['content'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF333333)), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('用户: ${c['nickname'] ?? ''}  帖子ID: ${c['post_id'] ?? ''}  ${c['created_at'] ?? ''}', style: const TextStyle(fontSize: 11, color: Color(0xFF999999))),
          ])),
          IconButton(onPressed: () => _delete(c['id']), icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFFF2442))),
        ]),
      );
    }));
  }
}

class _CategoryManageTab extends StatefulWidget {
  @override
  State<_CategoryManageTab> createState() => _CategoryManageTabState();
}

class _CategoryManageTabState extends State<_CategoryManageTab> {
  List<Map<String, dynamic>> _cats = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await ApiService().get('/admin/categories');
      if (res['code'] == 200 && mounted) {
        setState(() { _cats = List<Map<String, dynamic>>.from((res['data'] as List).map((e) => Map<String, dynamic>.from(e as Map))); _loading = false; });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _save(Map<String, dynamic> data, {int? id}) async {
    try {
      final res = id != null ? await ApiService().put('/admin/categories/$id', data: data) : await ApiService().post('/admin/categories', data: data);
      if (res['code'] == 200) { AppToast.success(context, message: '保存成功'); _load(); } else { AppToast.error(context, message: res['msg'] ?? '保存失败'); }
    } catch (_) { AppToast.error(context, message: '保存失败'); }
  }

  Future<void> _delete(int id) async {
    try {
      final res = await ApiService().delete('/admin/categories/$id');
      if (res['code'] == 200) { AppToast.success(context, message: '已删除'); _load(); }
    } catch (_) { AppToast.error(context, message: '删除失败'); }
  }

  void _showEditDialog({Map<String, dynamic>? cat}) {
    final nameCtrl = TextEditingController(text: cat?['name'] ?? '');
    final iconCtrl = TextEditingController(text: cat?['icon'] ?? '');
    final descCtrl = TextEditingController(text: cat?['description'] ?? '');
    final colorCtrl = TextEditingController(text: cat?['color'] ?? '');
    final sortCtrl = TextEditingController(text: '${cat?['sort_order'] ?? 0}');
    int status = cat?['status'] ?? 1;
    int restriction = cat?['publish_restriction'] ?? 0;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, ds) => AlertDialog(
      title: Text(cat != null ? '编辑分类' : '添加分类', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _adminField(nameCtrl, '分类名称'),
        _adminField(iconCtrl, '图标(emoji)'),
        _adminField(descCtrl, '描述'),
        _buildColorPickerField(colorCtrl, ds),
        _adminField(sortCtrl, '排序', kb: TextInputType.number),
        Row(children: [const Text('状态: '), Switch(value: status == 1, onChanged: (v) => ds(() => status = v ? 1 : 0))]),
        Row(children: [const Text('发布限制: '), Switch(value: restriction == 1, onChanged: (v) => ds(() => restriction = v ? 1 : 0))]),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        TextButton(onPressed: () {
          Navigator.pop(ctx);
          _save({'name': nameCtrl.text, 'icon': iconCtrl.text, 'description': descCtrl.text, 'color': colorCtrl.text, 'sort_order': int.tryParse(sortCtrl.text) ?? 0, 'status': status, 'publish_restriction': restriction}, id: cat?['id']);
        }, child: const Text('保存', style: TextStyle(color: Color(0xFFFF2442)))),
      ],
    )));
  }

  static const _presetColors = [
    '#FF2442', '#FF5A6E', '#FF6B35', '#FAAD14', '#FADB14',
    '#52C41A', '#13C2C2', '#1890FF', '#2F54EB', '#722ED1',
    '#EB2F96', '#FF85C0', '#9254DE', '#597EF7', '#36CFC9',
    '#73D13D', '#FFC53D', '#FF7A45', '#FF4D4F', '#A0D911',
    '#40A9FF', '#531DAB', '#CF1322', '#0050B3', '#23180D',
  ];

  Color? _parseHex(String hex) {
    final h = hex.replaceAll('#', '');
    if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    return null;
  }

  Widget _buildColorPickerField(TextEditingController ctrl, StateSetter ds) {
    final currentColor = _parseHex(ctrl.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('颜色', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _showColorPickerDialog(ctrl, ds),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: currentColor ?? const Color(0xFFCCCCCC),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(ctrl.text.isEmpty ? '选择颜色' : ctrl.text, style: TextStyle(fontSize: 13, color: ctrl.text.isEmpty ? const Color(0xFFBBBBBB) : const Color(0xFF333333)))),
              const Icon(Icons.color_lens, size: 18, color: Color(0xFF999999)),
            ]),
          ),
        ),
      ],
    );
  }

  void _showColorPickerDialog(TextEditingController ctrl, StateSetter parentDs) {
    final tempCtrl = TextEditingController(text: ctrl.text);
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, ds) => AlertDialog(
      title: const Text('选择颜色', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        GridView.count(
          crossAxisCount: 5,
          shrinkWrap: true,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: _presetColors.map((hex) {
            final isSelected = tempCtrl.text.toUpperCase() == hex.toUpperCase();
            return GestureDetector(
              onTap: () { ds(() => tempCtrl.text = hex); },
              child: Container(
                decoration: BoxDecoration(
                  color: _parseHex(hex),
                  borderRadius: BorderRadius.circular(6),
                  border: isSelected ? Border.all(color: const Color(0xFF222222), width: 2) : null,
                ),
                child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: _parseHex(tempCtrl.text) ?? const Color(0xFFCCCCCC),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            controller: tempCtrl,
            onChanged: (_) => ds(() {}),
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(hintText: '#hex', hintStyle: TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)), border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
          )),
        ]),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        TextButton(onPressed: () {
          ctrl.text = tempCtrl.text;
          parentDs(() {});
          Navigator.pop(ctx);
        }, child: const Text('确定', style: TextStyle(color: Color(0xFFFF2442)))),
      ],
    )));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CupertinoActivityIndicator(radius: 14));
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), child: Align(alignment: Alignment.centerRight, child: GestureDetector(onTap: () => _showEditDialog(), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFFF2442), borderRadius: BorderRadius.circular(14)), child: const Text('+ 添加分类', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)))))),
      Expanded(child: ListView.builder(itemCount: _cats.length, padding: const EdgeInsets.symmetric(horizontal: 12), itemBuilder: (_, i) {
        final c = _cats[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            if (c['icon'] != null && (c['icon'] as String).isNotEmpty) Padding(padding: const EdgeInsets.only(right: 8), child: Text(c['icon'], style: const TextStyle(fontSize: 24))),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
              Text('排序: ${c['sort_order'] ?? 0}  ${c['status'] == 1 ? '启用' : '禁用'}', style: const TextStyle(fontSize: 11, color: Color(0xFF999999))),
            ])),
            IconButton(onPressed: () => _showEditDialog(cat: c), icon: const Icon(Icons.edit, size: 18, color: Color(0xFF4A90D9))),
            IconButton(onPressed: () => _delete(c['id']), icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFFF2442))),
          ]),
        );
      })),
    ]);
  }
}

class _AIConfigTab extends StatefulWidget {
  @override
  State<_AIConfigTab> createState() => _AIConfigTabState();
}

class _AIConfigTabState extends State<_AIConfigTab> {
  final _urlCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _promptCtrl = TextEditingController();
  bool _enabled = true;
  bool _loading = true;

  final _imgUrlCtrl = TextEditingController();
  final _imgKeyCtrl = TextEditingController();
  final _imgModelCtrl = TextEditingController();
  bool _imgEnabled = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await ApiService().get('/admin/ai-config');
      if (res['code'] == 200) {
        final d = res['data'] as Map<String, dynamic>;
        _urlCtrl.text = d['api_url'] ?? '';
        _keyCtrl.text = d['api_key'] ?? '';
        _modelCtrl.text = d['model_name'] ?? '';
        _promptCtrl.text = d['system_prompt'] ?? '';
        _enabled = d['enabled'] != 0;
      }
    } catch (_) {}
    try {
      final res = await ApiService().get('/admin/ai-image-config');
      if (res['code'] == 200) {
        final d = res['data'] as Map<String, dynamic>;
        _imgUrlCtrl.text = d['api_url'] ?? '';
        _imgKeyCtrl.text = d['api_key'] ?? '';
        _imgModelCtrl.text = d['model_name'] ?? '';
        _imgEnabled = d['enabled'] != 0;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    try {
      final res = await ApiService().put('/admin/ai-config', data: {'api_url': _urlCtrl.text, 'api_key': _keyCtrl.text, 'model_name': _modelCtrl.text, 'system_prompt': _promptCtrl.text, 'enabled': _enabled ? 1 : 0});
      if (res['code'] == 200) AppToast.success(context, message: 'AI对话配置保存成功');
      else AppToast.error(context, message: res['msg'] ?? '保存失败');
    } catch (_) { AppToast.error(context, message: '保存失败'); }
  }

  Future<void> _saveImage() async {
    try {
      final res = await ApiService().put('/admin/ai-image-config', data: {'api_url': _imgUrlCtrl.text, 'api_key': _imgKeyCtrl.text, 'model_name': _imgModelCtrl.text, 'enabled': _imgEnabled ? 1 : 0});
      if (res['code'] == 200) AppToast.success(context, message: 'AI绘画配置保存成功');
      else AppToast.error(context, message: res['msg'] ?? '保存失败');
    } catch (_) { AppToast.error(context, message: '保存失败'); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CupertinoActivityIndicator(radius: 14));
    return SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
      _configCard('AI对话配置', [
        _adminField(_urlCtrl, 'API URL (如 https://api.deepseek.com/v1/chat/completions)'),
        _adminField(_keyCtrl, 'API Key', obscure: true),
        _adminField(_modelCtrl, '模型名称 (如 deepseek-chat)'),
        _adminField(_promptCtrl, '系统提示词', maxLines: 4),
        Container(margin: const EdgeInsets.only(bottom: 8), child: Row(children: [const Expanded(child: Text('启用AI对话', style: TextStyle(fontSize: 14, color: Color(0xFF333333)))), Switch(value: _enabled, onChanged: (v) => setState(() => _enabled = v))])),
        const SizedBox(height: 4),
        GestureDetector(onTap: _save, child: Container(width: double.infinity, height: 40, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]), borderRadius: BorderRadius.circular(20)), alignment: Alignment.center, child: const Text('保存对话配置', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)))),
      ]),
      const SizedBox(height: 12),
      _configCard('AI绘画配置', [
        Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFFE0E0), width: 0.5)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.brush_outlined, size: 16, color: Color(0xFFFF2442)), SizedBox(width: 6), Text('GPT Image 2', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFFF2442)))],),
          SizedBox(height: 4),
          Text('最先进的图像生成模型，支持快速、高质量的图像生成和编辑', style: TextStyle(fontSize: 11, color: Color(0xFF999999), height: 1.4)),
          SizedBox(height: 2),
          Text('端点: /v1/images/generations', style: TextStyle(fontSize: 11, color: Color(0xFFBBBBBB))),
        ])),
        _adminField(_imgUrlCtrl, 'API URL (如 https://api.openai.com/v1/images/generations)'),
        _adminField(_imgKeyCtrl, 'API Key', obscure: true),
        _adminField(_imgModelCtrl, '模型名称 (如 gpt-image-2)'),
        Container(margin: const EdgeInsets.only(bottom: 8), child: Row(children: [const Expanded(child: Text('启用AI绘画', style: TextStyle(fontSize: 14, color: Color(0xFF333333)))), Switch(value: _imgEnabled, onChanged: (v) => setState(() => _imgEnabled = v))])),
        const SizedBox(height: 4),
        GestureDetector(onTap: _saveImage, child: Container(width: double.infinity, height: 40, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]), borderRadius: BorderRadius.circular(20)), alignment: Alignment.center, child: const Text('保存绘画配置', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)))),
      ]),
    ]));
  }
}

class _VersionManageTab extends StatefulWidget {
  @override
  State<_VersionManageTab> createState() => _VersionManageTabState();
}

class _VersionManageTabState extends State<_VersionManageTab> {
  List<Map<String, dynamic>> _versions = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await ApiService().get('/version/list');
      if (res['code'] == 200 && mounted) {
        setState(() { _versions = List<Map<String, dynamic>>.from((res['data'] as List).map((e) => Map<String, dynamic>.from(e as Map))); _loading = false; });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _save(Map<String, dynamic> data, {int? id}) async {
    try {
      final res = id != null ? await ApiService().put('/version/$id', data: data) : await ApiService().post('/version', data: data);
      if (res['code'] == 200) { AppToast.success(context, message: '保存成功'); _load(); } else { AppToast.error(context, message: res['msg'] ?? '保存失败'); }
    } catch (_) { AppToast.error(context, message: '保存失败'); }
  }

  Future<void> _delete(int id) async {
    try {
      final res = await ApiService().delete('/version/$id');
      if (res['code'] == 200) { AppToast.success(context, message: '已删除'); _load(); }
    } catch (_) { AppToast.error(context, message: '删除失败'); }
  }

  void _showEditDialog({Map<String, dynamic>? v}) {
    final codeCtrl = TextEditingController(text: v != null ? '${v['version_code']}' : '');
    final nameCtrl = TextEditingController(text: v?['version_name'] ?? '');
    final urlCtrl = TextEditingController(text: v?['download_url'] ?? '');
    final contentCtrl = TextEditingController(text: v?['update_content'] ?? '');
    final sizeCtrl = TextEditingController(text: v?['package_size'] ?? '');
    int forceUpdate = v?['force_update'] ?? 0;
    int updateType = v?['update_type'] ?? 1;
    int status = v?['status'] ?? 1;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, ds) => AlertDialog(
      title: Text(v != null ? '编辑版本' : '发布新版本', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _adminField(codeCtrl, '版本号(数字)', kb: TextInputType.number),
        _adminField(nameCtrl, '版本名(如1.0.0)'),
        _adminField(urlCtrl, '下载地址'),
        _adminField(contentCtrl, '更新内容(每行一条)', maxLines: 4),
        _adminField(sizeCtrl, '包大小(如25MB)'),
        Row(children: [const Text('强制更新: '), Switch(value: forceUpdate == 1, onChanged: (v) => ds(() => forceUpdate = v ? 1 : 0))]),
        Row(children: [const Text('启用: '), Switch(value: status == 1, onChanged: (v) => ds(() => status = v ? 1 : 0))]),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        TextButton(onPressed: () {
          Navigator.pop(ctx);
          _save({'version_code': int.tryParse(codeCtrl.text) ?? 1, 'version_name': nameCtrl.text, 'platform': 'android', 'update_type': updateType, 'force_update': forceUpdate, 'download_url': urlCtrl.text, 'update_content': contentCtrl.text, 'package_size': sizeCtrl.text, 'status': status}, id: v?['id']);
        }, child: const Text('保存', style: TextStyle(color: Color(0xFFFF2442)))),
      ],
    )));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CupertinoActivityIndicator(radius: 14));
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), child: Align(alignment: Alignment.centerRight, child: GestureDetector(onTap: () => _showEditDialog(), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFFF2442), borderRadius: BorderRadius.circular(14)), child: const Text('+ 发布新版本', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)))))),
      Expanded(child: ListView.builder(itemCount: _versions.length, padding: const EdgeInsets.symmetric(horizontal: 12), itemBuilder: (_, i) {
        final v = _versions[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('v${v['version_name'] ?? ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
                const SizedBox(width: 6),
                if (v['force_update'] == 1) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: const Color(0xFFFF2442), borderRadius: BorderRadius.circular(4)), child: const Text('强制', style: TextStyle(fontSize: 9, color: Colors.white))),
                if (v['status'] == 1) Container(margin: const EdgeInsets.only(left: 4), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: const Color(0xFF52C41A), borderRadius: BorderRadius.circular(4)), child: const Text('启用', style: TextStyle(fontSize: 9, color: Colors.white))),
              ]),
              const SizedBox(height: 2),
              Text('code: ${v['version_code']}  ${v['package_size'] ?? ''}', style: const TextStyle(fontSize: 11, color: Color(0xFF999999))),
            ])),
            IconButton(onPressed: () => _showEditDialog(v: v), icon: const Icon(Icons.edit, size: 18, color: Color(0xFF4A90D9))),
            IconButton(onPressed: () => _delete(v['id']), icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFFF2442))),
          ]),
        );
      })),
    ]);
  }
}

class _EmailConfigTab extends StatefulWidget {
  @override
  State<_EmailConfigTab> createState() => _EmailConfigTabState();
}

class _EmailConfigTabState extends State<_EmailConfigTab> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _fromCtrl = TextEditingController();
  bool _secure = true;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await ApiService().get('/admin/email-config');
      if (res['code'] == 200) {
        final d = res['data'] as Map<String, dynamic>;
        _hostCtrl.text = d['host'] ?? '';
        _portCtrl.text = d['port'] ?? '';
        _userCtrl.text = d['user'] ?? '';
        _passCtrl.text = d['pass'] ?? '';
        _fromCtrl.text = d['from'] ?? '';
        _secure = d['secure'] == 'true' || d['secure'] == '1';
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    try {
      final res = await ApiService().put('/admin/email-config', data: {'host': _hostCtrl.text, 'port': _portCtrl.text, 'secure': _secure ? 'true' : 'false', 'user': _userCtrl.text, 'pass': _passCtrl.text, 'from': _fromCtrl.text});
      if (res['code'] == 200) AppToast.success(context, message: '保存成功，需重启后端生效');
      else AppToast.error(context, message: '保存失败');
    } catch (_) { AppToast.error(context, message: '保存失败'); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CupertinoActivityIndicator(radius: 14));
    return SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
      _configCard('SMTP配置', [
        _adminField(_hostCtrl, 'SMTP服务器'),
        _adminField(_portCtrl, '端口', kb: TextInputType.number),
        Row(children: [const Text('使用SSL: '), Switch(value: _secure, onChanged: (v) => setState(() => _secure = v))]),
        _adminField(_userCtrl, '用户名'),
        _adminField(_passCtrl, '密码/授权码', obscure: true),
        _adminField(_fromCtrl, '发件人地址'),
      ]),
      const SizedBox(height: 12),
      GestureDetector(onTap: _save, child: Container(width: double.infinity, height: 44, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]), borderRadius: BorderRadius.circular(22)), alignment: Alignment.center, child: const Text('保存配置', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)))),
    ]));
  }
}

Widget _adminField(TextEditingController ctrl, String hint, {bool obscure = false, int maxLines = 1, TextInputType? kb}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        maxLines: maxLines,
        keyboardType: kb,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
      ),
    ),
  );
}

Widget _configCard(String title, List<Widget> children) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
      const SizedBox(height: 8),
      ...children,
    ]),
  );
}
