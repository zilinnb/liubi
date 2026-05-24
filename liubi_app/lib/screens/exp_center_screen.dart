import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/helpers.dart';

class ExpCenterScreen extends StatefulWidget {
  const ExpCenterScreen({super.key});

  @override
  State<ExpCenterScreen> createState() => _ExpCenterScreenState();
}

class _ExpCenterScreenState extends State<ExpCenterScreen> {
  // 等级信息
  int _level = 1;
  String _title = '';
  int _exp = 0;
  int _currentExp = 0;
  int _expToNext = 100;
  int _needExp = 100;
  int _nextLevelExp = 100;
  double _progress = 0.0;
  bool _levelLoading = true;

  // 每日任务
  List<Map<String, dynamic>> _tasks = [];
  bool _tasksLoading = true;

  // 经验记录
  final List<Map<String, dynamic>> _records = [];
  int _recordsPage = 1;
  bool _recordsLoading = false;
  bool _recordsNoMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLevel();
    _loadTasks();
    _loadRecords();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      _loadMoreRecords();
    }
  }

  Color _getLevelColor(int level) {
    if (level <= 3) return const Color(0xFF999999);
    if (level <= 6) return const Color(0xFF1890FF);
    if (level <= 9) return const Color(0xFF722ED1);
    return const Color(0xFFFAAD14);
  }

  Future<void> _loadLevel() async {
    try {
      final res = await ApiService().get('/coins/level');
      if (res['code'] == 200 && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _level = data['level'] as int? ?? 1;
            _title = data['title'] as String? ?? '';
            _exp = data['exp'] as int? ?? 0;
            _currentExp = data['current_exp'] as int? ?? 0;
            _expToNext = data['exp_to_next'] as int? ?? 100;
            _needExp = data['need_exp'] as int? ?? 100;
            _nextLevelExp = data['next_level_exp'] as int? ?? 100;
            _progress = (data['progress'] as num?)?.toDouble() ?? 0.0;
            _levelLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _levelLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _levelLoading = false);
    }
  }

  Future<void> _loadTasks() async {
    try {
      final res = await ApiService().get('/coins/exp-tasks');
      if (res['code'] == 200 && res['data'] != null) {
        final list = res['data'] as List;
        if (mounted) {
          setState(() {
            _tasks = list
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            _tasksLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _tasksLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _tasksLoading = false);
    }
  }

  Future<void> _loadRecords({bool refresh = false}) async {
    if (_recordsLoading) return;
    if (refresh) {
      _recordsPage = 1;
      _recordsNoMore = false;
    }
    if (_recordsNoMore && !refresh) return;
    setState(() => _recordsLoading = true);
    try {
      final res = await ApiService().get('/coins/exp-records', queryParameters: {
        'page': _recordsPage,
        'pageSize': 20,
      });
      if (res['code'] == 200 && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        final list = (data['list'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final total = data['total'] as int? ?? 0;
        if (mounted) {
          setState(() {
            if (refresh) {
              _records.clear();
            }
            _records.addAll(list);
            _recordsPage++;
            _recordsNoMore = _records.length >= total;
            _recordsLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _recordsLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _recordsLoading = false);
    }
  }

  void _loadMoreRecords() {
    if (!_recordsLoading && !_recordsNoMore) {
      _loadRecords();
    }
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      _loadLevel(),
      _loadTasks(),
      _loadRecords(refresh: true),
    ]);
  }

  IconData _getTaskIcon(int type) {
    switch (type) {
      case 4: return Icons.calendar_today_rounded; // 签到
      case 1: return Icons.edit_note_rounded; // 发帖
      case 3: return Icons.favorite_rounded; // 点赞
      case 2: return Icons.chat_bubble_rounded; // 评论
      case 7: return Icons.bookmark_rounded; // 收藏
      case 5: return Icons.chat_rounded; // 聊天
      case 6: return Icons.person_add_rounded; // 关注
      default: return Icons.star_rounded;
    }
  }

  Color _getTaskIconColor(int type) {
    switch (type) {
      case 4: return const Color(0xFFFAAD14);
      case 1: return const Color(0xFF1890FF);
      case 3: return const Color(0xFFFF4D4F);
      case 2: return const Color(0xFF52C41A);
      case 7: return const Color(0xFF722ED1);
      case 5: return const Color(0xFF13C2C2);
      case 6: return const Color(0xFFEB2F96);
      default: return const Color(0xFF8C8C8C);
    }
  }

  IconData _getRecordIcon(int type) {
    switch (type) {
      case 5: return Icons.calendar_today_rounded; // 签到
      case 1: return Icons.edit_note_rounded; // 发帖
      case 3: return Icons.favorite_rounded; // 点赞
      case 4: return Icons.favorite_border_rounded; // 被赞
      case 2: return Icons.chat_bubble_rounded; // 评论
      case 10: return Icons.bookmark_rounded; // 收藏
      case 6: return Icons.chat_rounded; // 聊天
      case 8: return Icons.person_add_rounded; // 关注
      case 9: return Icons.person_add_alt_rounded; // 被关注
      case 7: return Icons.admin_panel_settings_rounded; // 管理员调整
      default: return Icons.auto_awesome_rounded;
    }
  }

  Color _getRecordIconColor(int type) {
    switch (type) {
      case 5: return const Color(0xFFFAAD14);
      case 1: return const Color(0xFF1890FF);
      case 3: return const Color(0xFFFF4D4F);
      case 4: return const Color(0xFFFF7875);
      case 2: return const Color(0xFF52C41A);
      case 10: return const Color(0xFF722ED1);
      case 6: return const Color(0xFF13C2C2);
      case 8: return const Color(0xFFEB2F96);
      case 9: return const Color(0xFFF759AB);
      case 7: return const Color(0xFFFF2442);
      default: return const Color(0xFFFF2442);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('经验中心',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF222222))),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: const Color(0xFFFF2442),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 等级信息卡片
            SliverToBoxAdapter(child: _buildLevelCard()),
            // 每日任务区域
            SliverToBoxAdapter(child: _buildTaskSection()),
            // 经验记录标题
            SliverToBoxAdapter(child: _buildSectionTitle('经验记录')),
            // 经验记录列表
            _buildRecordList(),
            // 底部间距
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard() {
    final levelColor = _getLevelColor(_level);
    final isMaxLevel = _nextLevelExp == null || _nextLevelExp <= 0 || _progress >= 1.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF2442), Color(0xFFFF5A6E), Color(0xFFFF8A9E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF2442).withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _levelLoading
              ? const Center(
                  child: CupertinoActivityIndicator(
                      radius: 10, color: Colors.white70))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                                width: 0.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.military_tech_rounded,
                                  size: 16, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                'Lv.$_level',
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (_title.isNotEmpty)
                          Text(
                            _title,
                            style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w500),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          '当前经验',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7)),
                        ),
                        const Spacer(),
                        if (isMaxLevel)
                          const Text('已满级',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500))
                        else
                          Text(
                            '升级还需 ${_needExp} 经验',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.7)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          fmtNum(_exp),
                          style: const TextStyle(
                              fontSize: 28,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              height: 1.1),
                        ),
                        if (!isMaxLevel) ...[
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '/ ${fmtNum(_expToNext)}',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.6)),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (!isMaxLevel)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${(_progress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value:
                            isMaxLevel ? 1.0 : _progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.white24,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(levelColor),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTaskSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('每日任务',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222))),
          const SizedBox(height: 10),
          _tasksLoading
              ? _buildTaskSkeleton()
              : _tasks.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.task_alt_outlined,
                              size: 40, color: Color(0xFFDDDDDD)),
                          SizedBox(height: 8),
                          Text('暂无任务',
                              style: TextStyle(
                                  fontSize: 14, color: Color(0xFF999999))),
                        ],
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: _tasks.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final task = entry.value;
                          return _buildTaskItem(task, idx == _tasks.length - 1);
                        }).toList(),
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildTaskSkeleton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(10))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          width: 80,
                          height: 14,
                          decoration: BoxDecoration(
                              color: const Color(0xFFF0F0F0),
                              borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 6),
                      Container(
                          width: 120,
                          height: 12,
                          decoration: BoxDecoration(
                              color: const Color(0xFFF0F0F0),
                              borderRadius: BorderRadius.circular(4))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task, bool isLast) {
    final type = task['type'] as int? ?? 0;
    final name = task['name'] as String? ?? '';
    final exp = task['exp'] as int? ?? 0;
    final dailyLimit = task['daily_limit'] as int? ?? 0;
    final todayCount = task['today_count'] as int? ?? 0;
    final isActive = (task['is_active'] as int? ?? 0) == 1;
    final isCompleted = dailyLimit > 0 && todayCount >= dailyLimit;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                    color: const Color(0xFFF0F0F0), width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getTaskIconColor(type).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_getTaskIcon(type),
                size: 22, color: _getTaskIconColor(type)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF333333),
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text('+$exp 经验',
                        style: TextStyle(
                            fontSize: 12,
                            color: _getTaskIconColor(type),
                            fontWeight: FontWeight.w500)),
                    if (dailyLimit > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '$todayCount/$dailyLimit',
                        style: TextStyle(
                          fontSize: 12,
                          color: isCompleted
                              ? const Color(0xFF52C41A)
                              : const Color(0xFF999999),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isCompleted)
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFF52C41A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  size: 16, color: Colors.white),
            )
          else if (isActive)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF2442).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('去完成',
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFFF2442),
                      fontWeight: FontWeight.w500)),
            )
          else
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('未开始',
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFBBBBBB),
                      fontWeight: FontWeight.w500)),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Text(title,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF222222))),
    );
  }

  Widget _buildRecordList() {
    if (_records.isEmpty && !_recordsLoading) {
      return SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(vertical: 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            children: [
              Icon(Icons.history_rounded,
                  size: 48, color: Color(0xFFDDDDDD)),
              SizedBox(height: 8),
              Text('暂无经验记录',
                  style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index < _records.length) {
            return _buildRecordItem(_records[index], index);
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: _recordsNoMore
                  ? const Text('没有更多了',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFFCCCCCC)))
                  : const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFF2442),
                      ),
                    ),
            ),
          );
        },
        childCount: _records.length + 1,
      ),
    );
  }

  Widget _buildRecordItem(Map<String, dynamic> record, int index) {
    final type = record['type'] as int? ?? 0;
    final amount = record['amount'] as int? ?? 0;
    final desc = record['desc'] as String? ?? '';
    final createdAt = record['created_at'] as String? ?? '';
    final iconColor = _getRecordIconColor(type);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 时间线
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_getRecordIcon(type),
                        size: 14, color: iconColor),
                  ),
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: const Color(0xFFE8E8E8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // 内容卡片
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(desc,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF333333),
                                  fontWeight: FontWeight.w500),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(fmtTime(createdAt),
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFFBBBBBB))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '+$amount',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: iconColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
