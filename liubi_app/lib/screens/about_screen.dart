import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});
  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = 'v${info.version}');
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
            color: Colors.white,
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.arrow_back, size: 20, color: Color(0xFF222222)),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text('关于留笔', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF222222))),
                    ),
                  ),
                  const SizedBox(width: 46),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset('assets/icons/app_icon.png', width: 80, height: 80, fit: BoxFit.cover),
          ),
          const SizedBox(height: 16),
          const Text('留笔', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF222222))),
          const SizedBox(height: 6),
          Text(_version.isEmpty ? '' : _version, style: const TextStyle(fontSize: 14, color: Color(0xFF999999))),
          const SizedBox(height: 4),
          const Text('标记我的生活', style: TextStyle(fontSize: 13, color: Color(0xFFBBBBBB))),
          const SizedBox(height: 30),
          _buildGroup([
            _buildItem('用户协议', onTap: () => Navigator.pushNamed(context, '/browser', arguments: {'url': 'https://liubi.app/terms', 'title': '用户协议'})),
            _buildItem('隐私政策', onTap: () => Navigator.pushNamed(context, '/browser', arguments: {'url': 'https://liubi.app/privacy', 'title': '隐私政策'})),
          ]),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.only(bottom: 30),
            child: Text('Copyright © 2026 留笔 All Rights Reserved', style: TextStyle(fontSize: 11, color: Color(0xFFCCCCCC))),
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

  Widget _buildItem(String title, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5), width: 0.5))),
        child: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 15, color: Color(0xFF333333)))),
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }
}
