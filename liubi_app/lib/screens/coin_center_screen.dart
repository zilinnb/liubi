import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/post_provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../utils/helpers.dart';
import '../widgets/app_toast.dart';

class CoinCenterScreen extends StatefulWidget {
  const CoinCenterScreen({super.key});

  @override
  State<CoinCenterScreen> createState() => _CoinCenterScreenState();
}

class _CoinCenterScreenState extends State<CoinCenterScreen> {
  int _balance = 0;
  int _totalEarned = 0;
  int _totalSpent = 0;
  int _checkinDays = 0;
  String? _lastCheckin;
  bool _checkedInToday = false;
  bool _balanceLoading = true;
  bool _checkinLoading = false;

  final List<Map<String, dynamic>> _transactions = [];
  int _txOffset = 0;
  bool _txLoading = false;
  bool _txNoMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadBalance();
    _loadTransactions();
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
      _loadMoreTransactions();
    }
  }

  Future<void> _loadBalance() async {
    try {
      final pp = Provider.of<PostProvider>(context, listen: false);
      final res = await pp.getCoinBalance();
      if (res['code'] == 200 && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _balance = data['balance'] as int? ?? 0;
            _totalEarned = data['total_earned'] as int? ?? 0;
            _totalSpent = data['total_spent'] as int? ?? 0;
            _checkinDays = data['checkin_days'] as int? ?? 0;
            _lastCheckin = data['last_checkin'] as String?;
            _checkedInToday = _isToday(_lastCheckin);
            _balanceLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _balanceLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _balanceLoading = false);
    }
  }

  bool _isToday(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return false;
    final date = DateTime.tryParse(dateStr);
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Future<void> _doCheckin() async {
    if (_checkinLoading || _checkedInToday) return;
    setState(() => _checkinLoading = true);
    try {
      final res = await ApiService().post('/coins/checkin');
      if (res['code'] == 200 && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        final reward = data['reward'] as int? ?? 5;
        final days = data['days'] as int? ?? 1;
        if (mounted) {
          setState(() {
            _checkedInToday = true;
            _balance += reward;
            _checkinDays = days;
          });
          AppToast.success(context, message: '签到成功！获得 $reward 留币，连续签到 $days 天');
        }
        _loadTransactions(refresh: true);
      } else {
        if (mounted) {
          AppToast.error(context, message: res['msg'] ?? '签到失败');
          if (res['code'] == 400) {
            setState(() => _checkedInToday = true);
          }
        }
      }
    } catch (_) {
      if (mounted) AppToast.error(context, message: '网络错误');
    } finally {
      if (mounted) setState(() => _checkinLoading = false);
    }
  }

  Future<void> _loadTransactions({bool refresh = false}) async {
    if (_txLoading) return;
    if (refresh) {
      _txOffset = 0;
      _txNoMore = false;
    }
    if (_txNoMore && !refresh) return;
    setState(() => _txLoading = true);
    try {
      final res = await ApiService().get('/coins/transactions', queryParameters: {
        'limit': 20,
        'offset': _txOffset,
      });
      if (res['code'] == 200 && res['data'] != null) {
        final list = res['data'] as List;
        final items = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        if (mounted) {
          setState(() {
            if (refresh) {
              _transactions.clear();
            }
            _transactions.addAll(items);
            _txOffset = _transactions.length;
            _txNoMore = items.length < 20;
            _txLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _txLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _txLoading = false);
    }
  }

  void _loadMoreTransactions() {
    if (!_txLoading && !_txNoMore) {
      _loadTransactions();
    }
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      _loadBalance(),
      _loadTransactions(refresh: true),
    ]);
  }

  List<bool> _buildWeekCheckinStatus() {
    final now = DateTime.now();
    final today = now.weekday;
    final monday = now.subtract(Duration(days: today - 1));
    final statuses = <bool>[];

    for (int i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      if (day.isAfter(now)) {
        statuses.add(false);
      } else if (i == today - 1 && _checkedInToday) {
        statuses.add(true);
      } else if (i < today - 1) {
        if (_checkinDays > 0 && _lastCheckin != null) {
          final lastDate = DateTime.tryParse(_lastCheckin!);
          if (lastDate != null) {
            final diff = now.difference(lastDate).inDays;
            final daysBeforeToday = today - 1 - i;
            statuses.add(diff <= daysBeforeToday + 1 && _checkinDays > daysBeforeToday);
          } else {
            statuses.add(false);
          }
        } else {
          statuses.add(false);
        }
      } else {
        statuses.add(false);
      }
    }
    return statuses;
  }

  IconData _getTypeIcon(int type) {
    switch (type) {
      case 1: return Icons.star_rounded;
      case 2: return Icons.card_giftcard_rounded;
      case 3: return Icons.redeem_rounded;
      case 4: return Icons.favorite_outline_rounded;
      case 5: return Icons.favorite_rounded;
      case 6: return Icons.settings_rounded;
      default: return Icons.swap_horiz_rounded;
    }
  }

  Color _getTypeIconColor(int type) {
    switch (type) {
      case 1: return const Color(0xFFFAAD14);
      case 2: return const Color(0xFF1890FF);
      case 3: return const Color(0xFFFF4D4F);
      case 4: return const Color(0xFFEB2F96);
      case 5: return const Color(0xFFF5222D);
      case 6: return const Color(0xFF8C8C8C);
      default: return const Color(0xFF8C8C8C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekStatus = _buildWeekCheckinStatus();
    final now = DateTime.now();
    final todayIndex = now.weekday - 1;
    const weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('留币中心',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF222222))),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: const Color(0xFFFF6B35),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 余额卡片
            SliverToBoxAdapter(child: _buildBalanceCard()),
            // 7天签到日历
            SliverToBoxAdapter(child: _buildWeekCalendar(weekLabels, weekStatus, todayIndex)),
            // 交易记录标题
            SliverToBoxAdapter(child: _buildSectionTitle('交易记录')),
            // 交易记录列表
            _buildTransactionList(),
            // 底部间距
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF8C42), Color(0xFFFF3D3D)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF3D3D).withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('留币余额',
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                                fontWeight: FontWeight.w400)),
                        const SizedBox(height: 8),
                        _balanceLoading
                            ? const SizedBox(
                                width: 80,
                                height: 32,
                                child: LinearProgressIndicator(
                                  color: Colors.white30,
                                  backgroundColor: Colors.white10,
                                ),
                              )
                            : Text(
                                '$_balance',
                                style: const TextStyle(
                                    fontSize: 36,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    height: 1.1),
                              ),
                      ],
                    ),
                  ),
                  _buildCheckinButton(),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildStatItem('累计获得', _totalEarned),
                  const SizedBox(width: 32),
                  _buildStatItem('累计支出', _totalSpent),
                  const SizedBox(width: 32),
                  _buildStatItem('连续签到', _checkinDays),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckinButton() {
    if (_checkedInToday) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('已签到 ✓',
            style: TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500)),
      );
    }
    return GestureDetector(
      onTap: _doCheckin,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: _checkinLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFF3D3D),
                ),
              )
            : const Text('签到 +5',
                style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFFF3D3D),
                    fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildStatItem(String label, int value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.white60)),
        const SizedBox(height: 2),
        Text('$value',
            style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildWeekCalendar(List<String> labels, List<bool> status, int todayIndex) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('本周签到',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF222222))),
              const SizedBox(width: 8),
              Text('连续 $_checkinDays 天',
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF999999))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final isToday = i == todayIndex;
              final checked = status[i];
              final isFuture = i > todayIndex;
              return Column(
                children: [
                  Text(labels[i],
                      style: TextStyle(
                          fontSize: 12,
                          color: isToday
                              ? const Color(0xFFFF6B35)
                              : const Color(0xFF999999),
                          fontWeight: isToday ? FontWeight.w600 : FontWeight.w400)),
                  const SizedBox(height: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: checked
                          ? const Color(0xFF52C41A)
                          : isToday
                              ? const Color(0xFFFF6B35).withValues(alpha: 0.12)
                              : const Color(0xFFF5F5F5),
                      border: isToday && !checked
                          ? Border.all(color: const Color(0xFFFF6B35), width: 2)
                          : null,
                    ),
                    child: Center(
                      child: isFuture
                          ? null
                          : checked
                              ? const Icon(Icons.check_rounded,
                                  size: 18, color: Colors.white)
                              : isToday
                                  ? Text('今',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: const Color(0xFFFF6B35),
                                          fontWeight: FontWeight.w600))
                                  : null,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(title,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF222222))),
    );
  }

  Widget _buildTransactionList() {
    if (_transactions.isEmpty && !_txLoading) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined, size: 48, color: const Color(0xFFDDDDDD)),
              const SizedBox(height: 8),
              const Text('暂无交易记录',
                  style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index < _transactions.length) {
            return _buildTransactionItem(_transactions[index]);
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: _txNoMore
                  ? const Text('没有更多了',
                      style: TextStyle(fontSize: 13, color: Color(0xFFCCCCCC)))
                  : const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFF6B35),
                      ),
                    ),
            ),
          );
        },
        childCount: _transactions.length + 1,
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx) {
    final type = tx['type'] as int? ?? 0;
    final amount = tx['amount'] as int? ?? 0;
    final desc = tx['description'] as String? ?? '';
    final createdAt = tx['created_at'] as String? ?? '';
    final isPositive = amount > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getTypeIconColor(type).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_getTypeIcon(type),
                size: 22, color: _getTypeIconColor(type)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(desc,
                    style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF333333),
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(fmtTime(createdAt),
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFBBBBBB))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${isPositive ? '+' : ''}$amount',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isPositive ? const Color(0xFF52C41A) : const Color(0xFFFF4D4F),
            ),
          ),
        ],
      ),
    );
  }
}
