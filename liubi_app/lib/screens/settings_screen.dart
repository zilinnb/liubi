import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/app_toast.dart';
import '../services/update_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _cacheClearing = false;
  String _cacheSize = '计算中...';

  @override
  void initState() {
    super.initState();
    _calcCacheSize();
  }

  Future<void> _calcCacheSize() async {
    try {
      final dirs = await Future.wait([
        getTemporaryDirectory(),
        getApplicationSupportDirectory(),
      ]);
      int totalBytes = 0;
      for (final dir in dirs) {
        totalBytes += await _dirSize(Directory(dir.path));
      }
      // Also check external storage for cached images
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) totalBytes += await _dirSize(Directory(extDir.path));
      } catch (_) {}

      if (mounted) {
        setState(() => _cacheSize = _formatBytes(totalBytes));
      }
    } catch (_) {
      if (mounted) setState(() => _cacheSize = '0MB');
    }
  }

  Future<int> _dirSize(Directory dir) async {
    if (!await dir.exists()) return 0;
    int total = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try { total += await entity.length(); } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
  }

  Future<void> _clearCache() async {
    setState(() { _cacheClearing = true; _cacheSize = '清理中...'; });
    try {
      final dirs = await Future.wait([
        getTemporaryDirectory(),
        getApplicationSupportDirectory(),
      ]);
      for (final dir in dirs) {
        await _clearDir(Directory(dir.path));
      }
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) await _clearDir(Directory(extDir.path));
      } catch (_) {}
      await _calcCacheSize();
      if (mounted) AppToast.success(context, message: '缓存已清除');
    } catch (_) {
      if (mounted) AppToast.error(context, message: '清除失败');
    }
    if (mounted) setState(() => _cacheClearing = false);
  }

  Future<void> _clearDir(Directory dir) async {
    if (!await dir.exists()) return;
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) {
          try { await entity.delete(); } catch (_) {}
        } else if (entity is Directory) {
          try { await entity.delete(recursive: true); } catch (_) {}
        }
      }
    } catch (_) {}
  }

  void _showXhsDialog({required String title, required String content, required VoidCallback onConfirm, bool danger = false}) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF222222))),
              const SizedBox(height: 12),
              Text(content, style: const TextStyle(fontSize: 14, color: Color(0xFF666666), height: 1.5), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(22)),
                        alignment: Alignment.center,
                        child: const Text('取消', style: TextStyle(fontSize: 15, color: Color(0xFF666666), fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        onConfirm();
                      },
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: danger ? const LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]) : const LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        alignment: Alignment.center,
                        child: const Text('确定', style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearCacheConfirm() {
    _showXhsDialog(title: '清除缓存', content: '确定要清除缓存吗？清除后浏览记录可能会丢失', onConfirm: _clearCache);
  }

  void _showLogoutConfirm() {
    _showXhsDialog(
      title: '退出登录',
      content: '确定要退出登录吗？退出后需要重新登录才能使用',
      onConfirm: () {
        Provider.of<UserProvider>(context, listen: false).logout();
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      },
    );
  }

  void _showChangePassword() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
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
            Padding(padding: const EdgeInsets.all(16), child: const Text('修改密码', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF222222)))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Container(decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)), child: TextField(controller: oldCtrl, obscureText: true, style: const TextStyle(fontSize: 14), decoration: const InputDecoration(hintText: '当前密码', hintStyle: TextStyle(fontSize: 14, color: Color(0xFFBBBBBB)), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12))))),
            const SizedBox(height: 10),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Container(decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)), child: TextField(controller: newCtrl, obscureText: true, style: const TextStyle(fontSize: 14), decoration: const InputDecoration(hintText: '新密码', hintStyle: TextStyle(fontSize: 14, color: Color(0xFFBBBBBB)), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12))))),
            const SizedBox(height: 10),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Container(decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)), child: TextField(controller: confirmCtrl, obscureText: true, style: const TextStyle(fontSize: 14), decoration: const InputDecoration(hintText: '确认新密码', hintStyle: TextStyle(fontSize: 14, color: Color(0xFFBBBBBB)), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12))))),
            const SizedBox(height: 20),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: GestureDetector(onTap: () async {
              if (newCtrl.text.trim() != confirmCtrl.text.trim()) { AppToast.error(ctx, message: '两次密码不一致'); return; }
              final res = await Provider.of<UserProvider>(context, listen: false).changePassword(email: '', code: oldCtrl.text.trim(), newPassword: newCtrl.text.trim());
              if (ctx.mounted) { Navigator.pop(ctx); if (res['code'] == 200) AppToast.success(context, message: '密码修改成功'); }
            }, child: Container(width: double.infinity, height: 44, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]), borderRadius: BorderRadius.circular(22)), alignment: Alignment.center, child: const Text('确定', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600))))),
            const SizedBox(height: 30),
          ]),
        );
      }),
    );
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
            color: Colors.white,
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.arrow_back, size: 20, color: Color(0xFF222222)))),
                  const Expanded(child: Center(child: Text('设置', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF222222))))),
                  const SizedBox(width: 46),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  _buildGroup([
                    _buildItem(Icons.person_outline, '编辑资料', onTap: () => Navigator.pushNamed(context, '/edit-profile')),
                    _buildItem(Icons.lock_outline, '修改密码', onTap: _showChangePassword),
                  ]),
                  Consumer<UserProvider>(
                    builder: (_, up, __) {
                      if (up.userInfo?.role != 1) return const SizedBox.shrink();
                      return Column(children: [
                        const SizedBox(height: 10),
                        _buildGroup([
                          _buildItem(Icons.admin_panel_settings_outlined, '管理中心', trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFFF2442), borderRadius: BorderRadius.circular(4)), child: const Text('Admin', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600))), onTap: () => Navigator.pushNamed(context, '/admin')),
                        ]),
                      ]);
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildGroup([
                    _buildItem(Icons.notifications_outlined, '通知设置', onTap: () => Navigator.pushNamed(context, '/notification-settings')),
                    _buildItem(Icons.security_outlined, '隐私设置', onTap: () => Navigator.pushNamed(context, '/privacy-settings')),
                    _buildItem(Icons.help_outline, '帮助与反馈', onTap: () => AppToast.info(context, message: '功能开发中')),
                    _buildItem(Icons.system_update_outlined, '检查更新', onTap: () => UpdateService.checkUpdate(context)),
                    _buildItem(Icons.info_outline, '关于留笔', onTap: () => Navigator.pushNamed(context, '/about')),
                  ]),
                  const SizedBox(height: 10),
                  _buildGroup([
                    _buildItem(Icons.cleaning_services_outlined, '清除缓存', trailing: _cacheClearing ? const CupertinoActivityIndicator(radius: 8) : Text(_cacheSize, style: const TextStyle(fontSize: 13, color: Color(0xFFBBBBBB))), onTap: _showClearCacheConfirm),
                  ]),
                  const SizedBox(height: 20),
                  Consumer<UserProvider>(
                    builder: (_, up, __) {
                      if (!up.isLoggedIn) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GestureDetector(
                          onTap: _showLogoutConfirm,
                          child: Container(
                            width: double.infinity,
                            height: 44,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFFE0E0), width: 0.5)),
                            alignment: Alignment.center,
                            child: const Text('退出登录', style: TextStyle(fontSize: 15, color: Color(0xFFFF2442), fontWeight: FontWeight.w600)),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Column(children: children),
    );
  }

  Widget _buildItem(IconData icon, String title, {Widget? trailing, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5), width: 0.5))),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF666666)),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 15, color: Color(0xFF333333)))),
            if (trailing != null) trailing else const Icon(Icons.chevron_right, size: 16, color: Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }
}
