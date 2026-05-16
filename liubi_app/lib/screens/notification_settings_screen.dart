import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _pushEnabled = true;
  bool _notifyLike = true;
  bool _notifyComment = true;
  bool _notifyFollow = true;
  bool _notifyCollect = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushEnabled = prefs.getBool('push_enabled') ?? true;
      _notifyLike = prefs.getBool('notify_like') ?? true;
      _notifyComment = prefs.getBool('notify_comment') ?? true;
      _notifyFollow = prefs.getBool('notify_follow') ?? true;
      _notifyCollect = prefs.getBool('notify_collect') ?? true;
      _loaded = true;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(key, value);
  }

  Future<void> _onPushToggle(bool v) async {
    if (v) {
      final granted = await NotificationService.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请在系统设置中开启通知权限'), duration: Duration(seconds: 2)),
          );
        }
        return;
      }
    }
    setState(() => _pushEnabled = v);
    _saveBool('push_enabled', v);
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
                  const Expanded(child: Center(child: Text('通知设置', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF222222))))),
                  const SizedBox(width: 46),
                ],
              ),
            ),
          ),
          if (!_loaded)
            const Expanded(child: Center(child: CupertinoActivityIndicator(radius: 14)))
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    _sectionTitle('系统推送通知'),
                    _buildGroup([
                      _buildSwitchItem('接收推送通知', _pushEnabled, _onPushToggle),
                    ]),
                    const SizedBox(height: 10),
                    _sectionTitle('通知类型'),
                    _buildGroup([
                      _buildSwitchItem('点赞通知', _notifyLike, (v) { setState(() => _notifyLike = v); _saveBool('notify_like', v); }),
                      _buildSwitchItem('评论通知', _notifyComment, (v) { setState(() => _notifyComment = v); _saveBool('notify_comment', v); }),
                      _buildSwitchItem('关注通知', _notifyFollow, (v) { setState(() => _notifyFollow = v); _saveBool('notify_follow', v); }),
                      _buildSwitchItem('收藏通知', _notifyCollect, (v) { setState(() => _notifyCollect = v); _saveBool('notify_collect', v); }),
                    ]),
                  ],
                ),
              ),
            ),
        ],
      ),
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
