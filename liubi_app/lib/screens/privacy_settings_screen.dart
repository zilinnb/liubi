import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../widgets/app_toast.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});
  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    return Consumer<UserProvider>(
      builder: (_, up, __) {
        final user = up.userInfo;
        final privacyFollows = user?.privacyFollows == 1;
        final privacyFans = user?.privacyFans == 1;
        final privacyLikes = user?.privacyLikes == 1;
        final privacyActivities = (user?.privacyActivities ?? 0) == 1;
        final email = user?.email ?? '';
        final username = user?.username ?? '';

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
                      const Expanded(child: Center(child: Text('隐私设置', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF222222))))),
                      const SizedBox(width: 46),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      _sectionTitle('账号安全'),
                      _buildGroup([
                        _buildItem('修改邮箱号', subtitle: email.isNotEmpty ? email : '未绑定', showArrow: true, onTap: () => _showChangeEmail(email)),
                        _buildItem('修改留笔号', subtitle: username, showArrow: true, onTap: () => _showChangeUsername(username)),
                      ]),
                      const SizedBox(height: 10),
                      _sectionTitle('隐私'),
                      _buildGroup([
                        _buildSwitchItem('隐藏我的关注列表', privacyFollows, (v) => _updatePrivacy(up, 'privacy_follows', v)),
                        _buildSwitchItem('隐藏我的粉丝列表', privacyFans, (v) => _updatePrivacy(up, 'privacy_fans', v)),
                        _buildSwitchItem('隐藏我的获赞与收藏', privacyLikes, (v) => _updatePrivacy(up, 'privacy_likes', v)),
                        _buildSwitchItem('隐藏我的动态', privacyActivities, (v) => _updatePrivacy(up, 'privacy_activities', v)),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updatePrivacy(UserProvider up, String key, bool value) async {
    if (_saving) return;
    setState(() => _saving = true);
    await up.updateProfile({key: value ? 1 : 0});
    if (mounted) setState(() => _saving = false);
  }

  void _showChangeEmail(String currentEmail) {
    final emailCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    bool codeSent = false;
    int countdown = 0;
    bool sendingCode = false;

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
            const Padding(padding: EdgeInsets.all(16), child: Text('修改邮箱号', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF222222)))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Expanded(child: TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, style: const TextStyle(fontSize: 14), decoration: const InputDecoration(hintText: '请输入新邮箱号', hintStyle: TextStyle(fontSize: 14, color: Color(0xFFBBBBBB)), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)))),
                    GestureDetector(
                      onTap: (countdown > 0 || sendingCode) ? null : () async {
                        final email = emailCtrl.text.trim();
                        if (email.isEmpty || !email.contains('@')) {
                          AppToast.error(ctx, message: '请输入正确的邮箱');
                          return;
                        }
                        ms(() { sendingCode = true; });
                        try {
                          final res = await ApiService().post('/auth/send-code', data: {'email': email, 'type': 4});
                          if (ctx.mounted) {
                            if (res['code'] == 200) {
                              ms(() { codeSent = true; countdown = 60; sendingCode = false; });
                              AppToast.success(ctx, message: '验证码已发送');
                              _startCountdown(ctx, ms, (c) { countdown = c; });
                            } else {
                              ms(() { sendingCode = false; });
                              AppToast.error(ctx, message: res['msg'] ?? '发送失败');
                            }
                          }
                        } catch (_) {
                          if (ctx.mounted) {
                            ms(() { sendingCode = false; });
                            AppToast.error(ctx, message: '发送失败');
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: sendingCode
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF999999)))
                          : Text(
                              countdown > 0 ? '${countdown}s' : '获取验证码',
                              style: TextStyle(fontSize: 13, color: countdown > 0 ? const Color(0xFFCCCCCC) : const Color(0xFFFF2442), fontWeight: FontWeight.w500),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Container(decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)), child: TextField(controller: codeCtrl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 14), decoration: const InputDecoration(hintText: '请输入验证码', hintStyle: TextStyle(fontSize: 14, color: Color(0xFFBBBBBB)), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12))))),
            const SizedBox(height: 20),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: GestureDetector(
              onTap: () async {
                final email = emailCtrl.text.trim();
                final code = codeCtrl.text.trim();
                if (email.isEmpty || code.isEmpty) {
                  AppToast.error(ctx, message: '请填写完整信息');
                  return;
                }
                final up = Provider.of<UserProvider>(ctx, listen: false);
                final res = await up.changeEmail(email, code: code);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  AppToast.success(context, message: res['code'] == 200 ? '邮箱号修改成功' : (res['msg'] ?? '修改失败'));
                }
              },
              child: Container(width: double.infinity, height: 44, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]), borderRadius: BorderRadius.circular(22)), alignment: Alignment.center, child: const Text('保存', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600))),
            )),
            const SizedBox(height: 30),
          ]),
        );
      }),
    );
  }

  void _startCountdown(BuildContext ctx, StateSetter ms, Function(int) onUpdate) {
    int c = 60;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      c--;
      if (c <= 0 || !ctx.mounted) return false;
      ms(() => onUpdate(c));
      return true;
    });
  }

  void _showChangeUsername(String currentUsername) {
    final ctrl = TextEditingController(text: currentUsername);
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
            const Padding(padding: EdgeInsets.all(16), child: Text('修改留笔号', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF222222)))),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('留笔号每90天只能修改一次', style: TextStyle(fontSize: 12, color: Color(0xFF999999)))),
            const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Container(decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)), child: TextField(controller: ctrl, style: const TextStyle(fontSize: 14), decoration: const InputDecoration(hintText: '请输入新留笔号', hintStyle: TextStyle(fontSize: 14, color: Color(0xFFBBBBBB)), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12))))),
            const SizedBox(height: 20),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: GestureDetector(
              onTap: () async {
                final name = ctrl.text.trim();
                if (name.isEmpty || name == currentUsername) return;
                final up = Provider.of<UserProvider>(ctx, listen: false);
                final res = await up.changeUsername(name);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  AppToast.success(context, message: res['code'] == 200 ? '留笔号修改成功' : (res['msg'] ?? '修改失败'));
                }
              },
              child: Container(width: double.infinity, height: 44, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]), borderRadius: BorderRadius.circular(22)), alignment: Alignment.center, child: const Text('保存', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600))),
            )),
            const SizedBox(height: 30),
          ]),
        );
      }),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Align(alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF999999), fontWeight: FontWeight.w500))),
    );
  }

  Widget _buildGroup(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Column(children: children),
    );
  }

  Widget _buildItem(String title, {String? subtitle, bool showArrow = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5), width: 0.5))),
        child: Row(
          children: [
            Text(title, style: const TextStyle(fontSize: 15, color: Color(0xFF333333))),
            const Spacer(),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)), overflow: TextOverflow.ellipsis),
              ),
            if (showArrow)
              const Icon(Icons.chevron_right, size: 16, color: Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchItem(String title, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5), width: 0.5))),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 15, color: Color(0xFF333333)))),
          CupertinoSwitch(value: value, onChanged: onChanged, activeTrackColor: const Color(0xFFFF2442)),
        ],
      ),
    );
  }
}
