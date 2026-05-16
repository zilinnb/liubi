import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../widgets/app_toast.dart';

class InAppBrowserScreen extends StatefulWidget {
  final String url;
  final String? title;
  const InAppBrowserScreen({super.key, required this.url, this.title});

  @override
  State<InAppBrowserScreen> createState() => _InAppBrowserScreenState();
}

class _InAppBrowserScreenState extends State<InAppBrowserScreen> {
  late WebViewController _ctrl;
  String _title = '';
  bool _loading = true;
  double _progress = 0;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();
    _title = widget.title ?? '';
    _currentUrl = widget.url;
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p / 100.0),
        onPageStarted: (url) => setState(() { _loading = true; _currentUrl = url; }),
        onPageFinished: (_) async {
          setState(() => _loading = false);
          final t = await _ctrl.getTitle();
          final url = await _ctrl.currentUrl();
          if (mounted) setState(() {
            if (t != null && t.isNotEmpty) _title = t;
            if (url != null) _currentUrl = url;
          });
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
        child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 8), decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2))),
          ListTile(leading: const Icon(Icons.copy, size: 22, color: Color(0xFF333333)), title: const Text('复制链接', style: TextStyle(fontSize: 16, color: Color(0xFF333333))), onTap: () { Navigator.pop(context); Clipboard.setData(ClipboardData(text: _currentUrl)); AppToast.success(context, message: '已复制'); }),
          const Divider(height: 1, indent: 56),
          ListTile(leading: const Icon(Icons.open_in_browser, size: 22, color: Color(0xFF333333)), title: const Text('在浏览器中打开', style: TextStyle(fontSize: 16, color: Color(0xFF333333))), onTap: () { Navigator.pop(context); _openInExternalBrowser(); }),
          const Divider(height: 1, indent: 56),
          ListTile(leading: const Icon(Icons.refresh, size: 22, color: Color(0xFF333333)), title: const Text('刷新页面', style: TextStyle(fontSize: 16, color: Color(0xFF333333))), onTap: () { Navigator.pop(context); _ctrl.reload(); }),
          const SizedBox(height: 8),
        ])),
      ),
    );
  }

  void _openInExternalBrowser() async {
    final url = _currentUrl;
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        Clipboard.setData(ClipboardData(text: url));
        AppToast.success(context, message: '链接已复制，请在浏览器中粘贴打开');
      }
    }
  }

  Future<void> _onRefresh() async {
    await _ctrl.reload();
  }

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(top: statusBarH),
            decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 0.5))),
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
                  Expanded(
                    child: Center(
                      child: Text(
                        _title.isEmpty ? '加载中...' : _title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF222222)),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _showMoreMenu,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.more_vert, size: 20, color: Color(0xFF666666)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading && _progress < 1.0)
            LinearProgressIndicator(value: _progress, backgroundColor: const Color(0xFFF0F0F0), valueColor: const AlwaysStoppedAnimation(Color(0xFFFF2442)), minHeight: 2),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _ctrl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
