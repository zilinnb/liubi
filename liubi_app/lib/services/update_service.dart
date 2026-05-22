import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:dio/dio.dart';
import 'api_service.dart';

class UpdateService {
  static Future<void> checkUpdate(BuildContext context, {bool silent = false}) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      String buildNumber = packageInfo.buildNumber;
      if (buildNumber.isEmpty) buildNumber = '0';
      final currentCode = int.tryParse(buildNumber) ?? 0;
      final platform = Platform.isAndroid ? 'android' : 'ios';

      debugPrint('=== UpdateService ===');
      debugPrint('currentVersion=$currentVersion, buildNumber=$buildNumber, currentCode=$currentCode, platform=$platform');

      // 使用ApiService发起请求（和其他接口共用同一个Dio实例）
      final res = await ApiService().get('/version/check', queryParameters: {
        'platform': platform,
        'versionCode': '$currentCode',
      });

      debugPrint('UpdateService: API response=$res');

      final code = res['code'];
      if (code != 200) {
        debugPrint('UpdateService: API code=$code, msg=${res['msg']}');
        if (!silent && context.mounted) {
          _showCheckFailed(context, '服务器返回异常($code)');
        }
        return;
      }

      final data = res['data'];
      if (data == null) {
        debugPrint('UpdateService: data is null');
        if (!silent && context.mounted) {
          _showNoUpdate(context, currentVersion, buildNumber);
        }
        return;
      }

      final hasUpdate = data['hasUpdate'];
      debugPrint('UpdateService: hasUpdate=$hasUpdate, data=$data');

      if (hasUpdate != true) {
        if (!silent && context.mounted) {
          _showNoUpdate(context, currentVersion, buildNumber);
        }
        return;
      }

      // 有更新，无论silent与否都弹窗
      if (context.mounted) {
        _showUpdateDialog(context, data, currentVersion, buildNumber);
      }
    } on DioException catch (e) {
      debugPrint('UpdateService: DioException type=${e.type}, message=${e.message}, response=${e.response?.data}');
      if (!silent && context.mounted) {
        final msg = e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout
            ? '连接超时，请重试'
            : '网络连接失败(${e.type.name})';
        _showCheckFailed(context, msg);
      }
    } catch (e, stack) {
      debugPrint('UpdateService: error=$e\n$stack');
      if (!silent && context.mounted) {
        _showCheckFailed(context, '检查更新失败: $e');
      }
    }
  }

  static void _showNoUpdate(BuildContext context, String version, String buildNumber) {
    _showSimpleDialog(
      context,
      icon: Icons.check_circle,
      iconColor: const Color(0xFF52C41A),
      iconBg: const Color(0xFFF0FFF0),
      title: '已是最新版本',
      subtitle: '当前版本: v$version ($buildNumber)',
    );
  }

  static void _showCheckFailed(BuildContext context, String msg) {
    _showSimpleDialog(
      context,
      icon: Icons.error_outline,
      iconColor: const Color(0xFFFF2442),
      iconBg: const Color(0xFFFFF5F5),
      title: msg,
    );
  }

  static void _showSimpleDialog(BuildContext context, {required IconData icon, required Color iconColor, required Color iconBg, required String title, String? subtitle}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (_, anim, __, child) => ScaleTransition(scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack), child: FadeTransition(opacity: anim, child: child)),
      pageBuilder: (_, __, ___) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 56, height: 56, decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 32)),
                const SizedBox(height: 12),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
                ],
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    height: 40,
                    decoration: BoxDecoration(color: const Color(0xFFFF2442), borderRadius: BorderRadius.circular(20)),
                    alignment: Alignment.center,
                    child: const Text('确定', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _showUpdateDialog(BuildContext context, Map<String, dynamic> data, String currentVersion, String buildNumber) {
    final forceUpdate = data['forceUpdate'] == true;
    final versionName = data['versionName']?.toString() ?? '';
    final updateContent = data['updateContent'] as List? ?? [];
    final downloadUrl = data['downloadUrl']?.toString() ?? '';
    final packageSize = data['packageSize']?.toString() ?? '';

    showGeneralDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (_, anim, __, child) => ScaleTransition(scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack), child: FadeTransition(opacity: anim, child: child)),
      pageBuilder: (_, __, ___) => Center(
        child: Material(
          color: Colors.transparent,
          child: PopScope(
            canPop: !forceUpdate,
            child: Container(
              width: 300,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.system_update, size: 40, color: Colors.white),
                        const SizedBox(height: 10),
                        const Text('发现新版本', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('v$versionName', style: const TextStyle(fontSize: 14, color: Colors.white70)),
                      ],
                    ),
                  ),
                  if (updateContent.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('更新内容', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
                          const SizedBox(height: 8),
                          ...updateContent.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(margin: const EdgeInsets.only(top: 6, right: 8), width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFFFF2442), shape: BoxShape.circle)),
                                Expanded(child: Text('$item', style: const TextStyle(fontSize: 12, color: Color(0xFF666666), height: 1.4))),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                  if (packageSize.isNotEmpty)
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('安装包大小: $packageSize', style: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Row(
                      children: [
                        if (!forceUpdate)
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(height: 42, decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(21)), alignment: Alignment.center, child: const Text('稍后再说', style: TextStyle(fontSize: 14, color: Color(0xFF999999)))),
                            ),
                          ),
                        if (!forceUpdate) const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _doUpdate(context, downloadUrl, forceUpdate),
                            child: Container(
                              height: 42,
                              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]), borderRadius: BorderRadius.circular(21)),
                              alignment: Alignment.center,
                              child: const Text('立即更新', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _doUpdate(BuildContext context, String url, bool forceUpdate) async {
    if (url.isEmpty) return;
    Navigator.pop(context);

    if (!Platform.isAndroid) {
      try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); } catch (_) {}
      return;
    }

    _showDownloadDialog(context, url, forceUpdate);
  }

  static void _showDownloadDialog(BuildContext context, String url, bool forceUpdate) {
    final progressNotifier = ValueNotifier<double>(0.0);
    final statusNotifier = ValueNotifier<String>('正在下载...');
    final doneNotifier = ValueNotifier<bool>(false);

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (_, anim, __, child) => ScaleTransition(scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack), child: FadeTransition(opacity: anim, child: child)),
      pageBuilder: (_, __, ___) => Center(
        child: Material(
          color: Colors.transparent,
          child: PopScope(
            canPop: false,
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: const BoxDecoration(color: Color(0xFFFFF5F5), shape: BoxShape.circle),
                    child: const Icon(Icons.system_update, size: 28, color: Color(0xFFFF2442)),
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<String>(
                    valueListenable: statusNotifier,
                    builder: (_, status, __) => Text(status, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<double>(
                    valueListenable: progressNotifier,
                    builder: (_, progress, __) {
                      final displayProgress = progress.clamp(0.0, 1.0);
                      return Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: displayProgress > 0 ? displayProgress : null,
                              minHeight: 8,
                              backgroundColor: const Color(0xFFF0F0F0),
                              valueColor: AlwaysStoppedAnimation<Color>(displayProgress >= 1.0 ? const Color(0xFF52C41A) : const Color(0xFFFF2442)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            displayProgress > 0 ? '${(displayProgress * 100).toStringAsFixed(1)}%' : '准备中...',
                            style: const TextStyle(fontSize: 14, color: Color(0xFF999999)),
                          ),
                        ],
                      );
                    },
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: doneNotifier,
                    builder: (_, done, __) => done && !forceUpdate
                        ? Column(children: [
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: double.infinity,
                                height: 40,
                                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(20)),
                                alignment: Alignment.center,
                                child: const Text('关闭', style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
                              ),
                            ),
                          ])
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    _startDownload(url, progressNotifier, statusNotifier, doneNotifier);
  }

  static void _startDownload(
    String url,
    ValueNotifier<double> progressNotifier,
    ValueNotifier<String> statusNotifier,
    ValueNotifier<bool> doneNotifier,
  ) async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) {
        statusNotifier.value = '下载失败';
        doneNotifier.value = true;
        return;
      }
      final savePath = '${dir.path}/liubi_update.apk';

      final oldFile = File(savePath);
      if (await oldFile.exists()) await oldFile.delete();

      await Dio().download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            progressNotifier.value = received / total;
            final percent = (received / total * 100).toStringAsFixed(0);
            statusNotifier.value = '正在下载... $percent%';
          }
        },
        options: Options(receiveTimeout: const Duration(minutes: 10)),
      );

      statusNotifier.value = '下载完成，正在安装...';
      progressNotifier.value = 1.0;
      doneNotifier.value = true;

      try {
        await OpenFilex.open(savePath);
      } catch (_) {
        try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); } catch (_) {}
      }
    } catch (e) {
      statusNotifier.value = '下载失败';
      doneNotifier.value = true;
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }
}
