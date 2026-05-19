import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/emoji_assets.dart';

class EmojiPickerPanel extends StatefulWidget {
  final void Function(String assetPath) onEmojiSelected;
  final double height;

  const EmojiPickerPanel({
    super.key,
    required this.onEmojiSelected,
    this.height = 250,
  });

  static Future<void> recordRecent(String assetPath) async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList('recent_emojis') ?? [];
    list.remove(assetPath);
    list.insert(0, assetPath);
    if (list.length > 36) list.removeRange(36, list.length);
    await sp.setStringList('recent_emojis', list);
  }

  static Future<List<String>> getRecent() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getStringList('recent_emojis') ?? [];
  }

  @override
  State<EmojiPickerPanel> createState() => _EmojiPickerPanelState();
}

class _EmojiPickerPanelState extends State<EmojiPickerPanel>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;
  List<String> _recentList = [];
  bool _recentLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadRecent();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final list = await EmojiPickerPanel.getRecent();
    if (mounted) {
      setState(() {
        _recentList = list;
        _recentLoaded = true;
      });
    }
  }

  void _onTap(String assetPath) {
    EmojiPickerPanel.recordRecent(assetPath);
    _loadRecent();
    widget.onEmojiSelected(assetPath);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: widget.height),
      color: const Color(0xFFF5F5F5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 38,
            color: Colors.white,
            child: TabBar(
              controller: _tabCtrl,
              labelColor: const Color(0xFFFF2442),
              unselectedLabelColor: const Color(0xFF666666),
              indicatorColor: const Color(0xFFFF2442),
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
              tabs: const [
                Tab(text: '最近使用'),
                Tab(text: '所有表情'),
              ],
            ),
          ),
          SizedBox(
            height: widget.height - 38,
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildRecentTab(),
                _buildAllTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTab() {
    if (!_recentLoaded) {
      return const Center(child: CupertinoActivityIndicator(radius: 10, color: Color(0xFFFF2442)));
    }
    if (_recentList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.emoji_emotions_outlined, size: 36, color: Color(0xFFCCCCCC)),
            SizedBox(height: 8),
            Text('暂无最近使用的表情', style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        childAspectRatio: 1,
      ),
      itemCount: _recentList.length,
      itemBuilder: (ctx, i) => GestureDetector(
        onTap: () => _onTap(_recentList[i]),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Image.asset(_recentList[i], fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildAllTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        childAspectRatio: 1,
      ),
      itemCount: emojiAssets.length,
      itemBuilder: (ctx, i) => GestureDetector(
        onTap: () => _onTap(emojiAssets[i]),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Image.asset(emojiAssets[i], fit: BoxFit.contain),
        ),
      ),
    );
  }
}
