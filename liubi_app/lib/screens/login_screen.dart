import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../widgets/app_toast.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // 登录页 - 密码登录
  final _accountCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _obscurePwd = true;

  // 登录页 - 验证码登录
  final _loginEmailCtrl = TextEditingController();
  final _loginCodeCtrl = TextEditingController();

  // 注册页
  final _regEmailCtrl = TextEditingController();
  final _regCodeCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _regPwdCtrl = TextEditingController();
  bool _obscureRegPwd = true;

  // 找回密码页
  final _fpEmailCtrl = TextEditingController();
  final _fpCodeCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();
  bool _obscureNewPwd = true;
  bool _obscureConfirmPwd = true;

  // 登录页 Tab：0 密码登录，1 验证码登录
  int _loginTab = 0;

  // 验证码倒计时
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _accountCtrl.dispose();
    _pwdCtrl.dispose();
    _loginEmailCtrl.dispose();
    _loginCodeCtrl.dispose();
    _regEmailCtrl.dispose();
    _regCodeCtrl.dispose();
    _nicknameCtrl.dispose();
    _regPwdCtrl.dispose();
    _fpEmailCtrl.dispose();
    _fpCodeCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  // ========== 页面跳转 ==========

  void _navigateTo(int page) {
    _pageController.jumpToPage(page);
    setState(() => _currentPage = page);
  }

  // ========== 自定义弹窗 ==========

  void _showLoading({String text = '加载中'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black26,
      builder: (_) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(radius: 14, color: Color(0xFFFF2442)),
            const SizedBox(height: 10),
            Text(text, style: const TextStyle(fontSize: 13, color: Colors.white, decoration: TextDecoration.none)),
          ],
        ),
      ),
    );
  }

  void _showSuccess({String text = '操作成功', VoidCallback? onClose}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black26,
      builder: (_) {
        Future.delayed(Duration(milliseconds: 1500), () {
          if (!mounted) return;
          Navigator.pop(context);
          onClose?.call();
        });
        return Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 40, color: Color(0xFF07C160)),
                SizedBox(height: 10),
                Text(text, style: TextStyle(fontSize: 13, color: Color(0xFF222222), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ========== 验证码倒计时 ==========

  void _startCountdown() {
    setState(() => _countdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (t) {
      if (_countdown <= 1) {
        t.cancel();
        setState(() => _countdown = 0);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  bool _sendingCode = false;

  void _sendCode(String email, int type) async {
    if (email.isEmpty) {
      AppToast.error(context, message: '请输入邮箱');
      return;
    }
    if (_sendingCode) return;
    setState(() => _sendingCode = true);
    final up = Provider.of<UserProvider>(context, listen: false);
    final res = await up.sendCode(email, type);
    if (!mounted) return;
    setState(() => _sendingCode = false);
    if (res['code'] == 200) {
      _startCountdown();
      AppToast.success(context, message: '验证码已发送');
    } else {
      AppToast.error(context, message: res['msg'] ?? '发送失败');
    }
  }

  // ========== 业务逻辑 ==========

  void _loginByPassword() async {
    if (_accountCtrl.text.trim().isEmpty || _pwdCtrl.text.trim().isEmpty) {
      AppToast.error(context, message: '请输入账号和密码');
      return;
    }
    _showLoading(text: '登录中');
    final up = Provider.of<UserProvider>(context, listen: false);
    final res = await up.login(_accountCtrl.text.trim(), _pwdCtrl.text.trim());
    if (!mounted) return;
    Navigator.pop(context);
    if (res['code'] == 200) {
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } else {
      AppToast.error(context, message: res['msg'] ?? '登录失败');
    }
  }

  void _loginByCode() async {
    if (_loginEmailCtrl.text.trim().isEmpty) {
      AppToast.error(context, message: '请输入邮箱');
      return;
    }
    if (_loginCodeCtrl.text.trim().isEmpty) {
      AppToast.error(context, message: '请输入验证码');
      return;
    }
    _showLoading(text: '登录中');
    final up = Provider.of<UserProvider>(context, listen: false);
    final res = await up.loginByCode(_loginEmailCtrl.text.trim(), _loginCodeCtrl.text.trim());
    if (!mounted) return;
    Navigator.pop(context);
    if (res['code'] == 200) {
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } else {
      AppToast.error(context, message: res['msg'] ?? '登录失败');
    }
  }

  void _register() async {
    if (_regEmailCtrl.text.trim().isEmpty) {
      AppToast.error(context, message: '请输入邮箱');
      return;
    }
    if (_regCodeCtrl.text.trim().isEmpty) {
      AppToast.error(context, message: '请输入验证码');
      return;
    }
    if (_regPwdCtrl.text.trim().isEmpty) {
      AppToast.error(context, message: '请输入密码');
      return;
    }
    _showLoading(text: '注册中');
    final up = Provider.of<UserProvider>(context, listen: false);
    final res = await up.register(
      email: _regEmailCtrl.text.trim(),
      code: _regCodeCtrl.text.trim(),
      password: _regPwdCtrl.text.trim(),
      nickname: _nicknameCtrl.text.trim(),
    );
    if (!mounted) return;
    Navigator.pop(context);
    if (res['code'] == 200) {
      _showSuccess(text: '注册成功', onClose: () {
        if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      });
    } else {
      AppToast.error(context, message: res['msg'] ?? '注册失败');
    }
  }

  void _resetPassword() async {
    if (_fpEmailCtrl.text.trim().isEmpty) {
      AppToast.error(context, message: '请输入邮箱');
      return;
    }
    if (_fpCodeCtrl.text.trim().isEmpty) {
      AppToast.error(context, message: '请输入验证码');
      return;
    }
    if (_newPwdCtrl.text.trim().isEmpty) {
      AppToast.error(context, message: '请输入新密码');
      return;
    }
    if (_confirmPwdCtrl.text.trim().isEmpty) {
      AppToast.error(context, message: '请确认新密码');
      return;
    }
    if (_newPwdCtrl.text.trim() != _confirmPwdCtrl.text.trim()) {
      AppToast.error(context, message: '两次密码不一致');
      return;
    }
    _showLoading(text: '重置中');
    try {
      final res = await ApiService().post('/auth/change-password', data: {
        'email': _fpEmailCtrl.text.trim(),
        'code': _fpCodeCtrl.text.trim(),
        'new_password': _newPwdCtrl.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      if (res['code'] == 200) {
        _showSuccess(text: '密码重置成功', onClose: () {
          _navigateTo(0);
        });
      } else {
        AppToast.error(context, message: res['msg'] ?? '重置失败');
      }
    } catch (_) {
      if (mounted) {
        Navigator.pop(context);
        AppToast.error(context, message: '网络错误');
      }
    }
  }

  // ========== 通用组件 ==========

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Container(
      height: 48,
      margin: EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          SizedBox(width: 16),
          Icon(icon, size: 20, color: Color(0xFF999999)),
          SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              style: TextStyle(fontSize: 15, color: Color(0xFF222222)),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(fontSize: 15, color: Color(0xFFBBBBBB)),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (suffix != null) suffix,
          if (suffix != null) SizedBox(width: 4) else SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildEyeToggle(bool obscure, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!obscure),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 20,
          color: Color(0xFF999999),
        ),
      ),
    );
  }

  Widget _buildCodeButton(TextEditingController emailCtrl, int type) {
    return GestureDetector(
      onTap: _countdown > 0 || _sendingCode ? null : () => _sendCode(emailCtrl.text.trim(), type),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: _sendingCode
            ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF2442)))
            : Text(
          _countdown > 0 ? '${_countdown}s' : '获取验证码',
          style: TextStyle(
            fontSize: 13,
            color: _countdown > 0 ? Color(0xFFBBBBBB) : Color(0xFFFF2442),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 44,
        decoration: BoxDecoration(
          color: Color(0xFFFF2442),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Center(
          child: Text(text, style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  // ========== 登录页 ==========

  Widget _buildLoginTabs() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _loginTab = 0),
                child: Center(
                  child: Text(
                    '密码登录',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: _loginTab == 0 ? FontWeight.w600 : FontWeight.w400,
                      color: _loginTab == 0 ? Color(0xFF222222) : Color(0xFF999999),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _loginTab = 1),
                child: Center(
                  child: Text(
                    '验证码登录',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: _loginTab == 1 ? FontWeight.w600 : FontWeight.w400,
                      color: _loginTab == 1 ? Color(0xFF222222) : Color(0xFF999999),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Center(
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color: _loginTab == 0 ? Color(0xFFFF2442) : Colors.transparent,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color: _loginTab == 1 ? Color(0xFFFF2442) : Colors.transparent,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoginPage() {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            SizedBox(height: 60),
            // Logo
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset('assets/icons/app_icon.png', width: 72, height: 72, fit: BoxFit.cover),
            ),
            SizedBox(height: 14),
            // App 名称
            Text('留笔', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF222222))),
            SizedBox(height: 36),
            // Tab 切换
            _buildLoginTabs(),
            SizedBox(height: 24),
            // 密码登录表单
            if (_loginTab == 0) ...[
              _buildInputField(
                controller: _accountCtrl,
                hint: '邮箱/用户名',
                icon: Icons.person_outline,
              ),
              _buildInputField(
                controller: _pwdCtrl,
                hint: '密码',
                icon: Icons.lock_outline,
                obscure: _obscurePwd,
                suffix: _buildEyeToggle(_obscurePwd, (v) => setState(() => _obscurePwd = v)),
              ),
              SizedBox(height: 10),
              _buildActionButton('登录', _loginByPassword),
            ],
            // 验证码登录表单
            if (_loginTab == 1) ...[
              _buildInputField(
                controller: _loginEmailCtrl,
                hint: '邮箱',
                icon: Icons.email_outlined,
              ),
              _buildInputField(
                controller: _loginCodeCtrl,
                hint: '验证码',
                icon: Icons.verified_user_outlined,
                suffix: _buildCodeButton(_loginEmailCtrl, 2),
              ),
              SizedBox(height: 10),
              _buildActionButton('登录', _loginByCode),
            ],
            SizedBox(height: 24),
            // 底部链接
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _navigateTo(1),
                  child: Text('注册账号', style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
                ),
                Text('  |  ', style: TextStyle(fontSize: 13, color: Color(0xFFDDDDDD))),
                GestureDetector(
                  onTap: () => _navigateTo(2),
                  child: Text('忘记密码', style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
                ),
              ],
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ========== 注册页 ==========

  Widget _buildRegisterPage() {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            SizedBox(height: 10),
            // 顶部导航栏
            Row(
              children: [
                GestureDetector(
                  onTap: () => _navigateTo(0),
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.arrow_back, size: 20, color: Color(0xFF555555)),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text('注册', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
                  ),
                ),
                SizedBox(width: 34),
              ],
            ),
            SizedBox(height: 36),
            _buildInputField(
              controller: _regEmailCtrl,
              hint: '邮箱',
              icon: Icons.email_outlined,
            ),
            _buildInputField(
              controller: _regCodeCtrl,
              hint: '验证码',
              icon: Icons.verified_user_outlined,
              suffix: _buildCodeButton(_regEmailCtrl, 1),
            ),
            _buildInputField(
              controller: _nicknameCtrl,
              hint: '昵称（选填）',
              icon: Icons.person_outline,
            ),
            _buildInputField(
              controller: _regPwdCtrl,
              hint: '密码',
              icon: Icons.lock_outline,
              obscure: _obscureRegPwd,
              suffix: _buildEyeToggle(_obscureRegPwd, (v) => setState(() => _obscureRegPwd = v)),
            ),
            SizedBox(height: 10),
            _buildActionButton('注册', _register),
            SizedBox(height: 24),
            // 底部链接
            Center(
              child: GestureDetector(
                onTap: () => _navigateTo(0),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
                    children: [
                      TextSpan(text: '已有账号？'),
                      TextSpan(text: '去登录', style: TextStyle(color: Color(0xFFFF2442))),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ========== 找回密码页 ==========

  Widget _buildForgotPasswordPage() {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            SizedBox(height: 10),
            // 顶部导航栏
            Row(
              children: [
                GestureDetector(
                  onTap: () => _navigateTo(0),
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.arrow_back, size: 20, color: Color(0xFF555555)),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text('找回密码', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
                  ),
                ),
                SizedBox(width: 34),
              ],
            ),
            SizedBox(height: 36),
            _buildInputField(
              controller: _fpEmailCtrl,
              hint: '邮箱',
              icon: Icons.email_outlined,
            ),
            _buildInputField(
              controller: _fpCodeCtrl,
              hint: '验证码',
              icon: Icons.verified_user_outlined,
              suffix: _buildCodeButton(_fpEmailCtrl, 3),
            ),
            _buildInputField(
              controller: _newPwdCtrl,
              hint: '新密码',
              icon: Icons.lock_outline,
              obscure: _obscureNewPwd,
              suffix: _buildEyeToggle(_obscureNewPwd, (v) => setState(() => _obscureNewPwd = v)),
            ),
            _buildInputField(
              controller: _confirmPwdCtrl,
              hint: '确认新密码',
              icon: Icons.lock_outline,
              obscure: _obscureConfirmPwd,
              suffix: _buildEyeToggle(_obscureConfirmPwd, (v) => setState(() => _obscureConfirmPwd = v)),
            ),
            SizedBox(height: 10),
            _buildActionButton('重置密码', _resetPassword),
            SizedBox(height: 24),
            // 底部链接
            Center(
              child: GestureDetector(
                onTap: () => _navigateTo(0),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
                    children: [
                      TextSpan(text: '想起密码？'),
                      TextSpan(text: '去登录', style: TextStyle(color: Color(0xFFFF2442))),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ========== 主构建 ==========

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (_currentPage != 0) _navigateTo(0);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: PageView(
            controller: _pageController,
            physics: NeverScrollableScrollPhysics(),
            children: [
              _buildLoginPage(),
              _buildRegisterPage(),
              _buildForgotPasswordPage(),
            ],
          ),
        ),
      ),
    );
  }
}
