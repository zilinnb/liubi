import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../widgets/app_toast.dart';

class InAppBrowserScreen extends StatefulWidget {
  final String url;
  final String? title;
  const InAppBrowserScreen({super.key, required this.url, this.title});

  @override
  State<InAppBrowserScreen> createState() => _InAppBrowserScreenState();
}

class _InAppBrowserScreenState extends State<InAppBrowserScreen> with SingleTickerProviderStateMixin {
  InAppWebViewController? _ctrl;
  String _title = '';
  bool _loading = true;
  double _progress = 0;
  String _currentUrl = '';
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _showNav = true;
  late AnimationController _progressCtrl;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _title = widget.title ?? '';
    _currentUrl = widget.url;
    _progressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _progressAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    super.dispose();
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 8), decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2))),
          ListTile(leading: const Icon(Icons.copy, size: 22, color: Color(0xFF333333)), title: const Text('复制链接', style: TextStyle(fontSize: 16, color: Color(0xFF333333))), onTap: () { Navigator.pop(context); Clipboard.setData(ClipboardData(text: _currentUrl)); AppToast.success(context, message: '已复制'); }),
          const Divider(height: 1, indent: 56),
          ListTile(leading: const Icon(Icons.open_in_browser, size: 22, color: Color(0xFF333333)), title: const Text('在浏览器中打开', style: TextStyle(fontSize: 16, color: Color(0xFF333333))), onTap: () { Navigator.pop(context); _openInExternalBrowser(); }),
          const Divider(height: 1, indent: 56),
          ListTile(leading: const Icon(Icons.refresh, size: 22, color: Color(0xFF333333)), title: const Text('刷新页面', style: TextStyle(fontSize: 16, color: Color(0xFF333333))), onTap: () { Navigator.pop(context); _ctrl?.reload(); }),
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

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // WebView content with padding for nav bars
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: statusBarH + 44, bottom: _showNav ? 48 + bottomPadding : 0),
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                initialSettings: InAppWebViewSettings(
                  useShouldOverrideUrlLoading: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  javaScriptEnabled: true,
                  supportZoom: true,
                  builtInZoomControls: true,
                  displayZoomControls: false,
                ),
                onWebViewCreated: (controller) {
                  _ctrl = controller;
                },
                onProgressChanged: (controller, progress) {
                  setState(() => _progress = progress / 100.0);
                  if (progress >= 100) {
                    _progressCtrl.reverse();
                  } else {
                    _progressCtrl.forward();
                  }
                },
                onTitleChanged: (controller, title) {
                  if (title != null && title.isNotEmpty && mounted) {
                    setState(() => _title = title);
                  }
                },
                onLoadStart: (controller, url) {
                  if (url != null && mounted) {
                    setState(() { _loading = true; _currentUrl = url.toString(); });
                    _progressCtrl.forward();
                  }
                },
                onLoadStop: (controller, url) {
                  if (mounted) {
                    setState(() { _loading = false; if (url != null) _currentUrl = url.toString(); });
                    _progressCtrl.reverse();
                  }
                  _updateNavState();
                },
              ),
            ),
          ),

          // Top navigation bar with blur effect
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(top: statusBarH),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                border: const Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 0.5)),
              ),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF222222)),
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
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: const Icon(Icons.more_horiz, size: 22, color: Color(0xFF666666)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Progress bar
          if (_loading && _progress < 1.0)
            Positioned(
              top: statusBarH + 44,
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _progress,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF6B6B)]),
                    ),
                  ),
                ),
              ),
            ),

          // Bottom toolbar with blur effect
          if (_showNav)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(bottom: bottomPadding),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  border: const Border(top: BorderSide(color: Color(0xFFF0F0F0), width: 0.5)),
                ),
                child: SizedBox(
                  height: 48,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _toolbarBtn(Icons.arrow_back_ios_new, '后退', _canGoBack ? () { _ctrl?.goBack(); _updateNavState(); } : null),
                      _toolbarBtn(Icons.arrow_forward_ios, '前进', _canGoForward ? () { _ctrl?.goForward(); _updateNavState(); } : null),
                      _toolbarBtn(Icons.refresh, '刷新', () => _ctrl?.reload()),
                      _toolbarBtn(Icons.open_in_browser, '浏览器', _openInExternalBrowser),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _toolbarBtn(IconData icon, String label, VoidCallback? onTap) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: enabled ? const Color(0xFF333333) : const Color(0xFFCCCCCC)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 9, color: enabled ? const Color(0xFF666666) : const Color(0xFFCCCCCC))),
          ],
        ),
      ),
    );
  }

  void _updateNavState() async {
    if (_ctrl == null) return;
    final canBack = await _ctrl!.canGoBack();
    final canForward = await _ctrl!.canGoForward();
    if (mounted) {
      setState(() {
        _canGoBack = canBack;
        _canGoForward = canForward;
      });
    }
  }
}
