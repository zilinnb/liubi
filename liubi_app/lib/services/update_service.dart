import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:dio/dio.dart';

class UpdateService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://liu.bi/api',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  /// 检查更新
  /// [silent] = true: 进入app自动检查，有更新才弹窗，无更新不弹
  /// [silent] = false: 用户手动点击"检查更新"，无论结果都弹窗
  static Future<void> checkUpdate(BuildContext context, {bool silent = false}) async {
    debugPrint('========== UpdateService.checkUpdate ==========');
    debugPrint('silent=$silent');

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = packageInfo.version;
      final buildNumber = packageInfo.buildNumber;
      final currentCode = int.tryParse(buildNumber) ?? 0;
      final platform = Platform.isAndroid ? 'android' : 'ios';

      debugPrint('version=$version, buildNumber=$buildNumber, currentCode=$currentCode');

      final response = await _dio.get('/version/check', queryParameters: {
        'platform': platform,
        'versionCode': '$currentCode',
      });

      debugPrint('Response: ${jsonEncode(response.data)}');

      final res = response.data;
      if (res == null) {
        if (!silent && context.mounted) _showResultDialog(context, success: false, msg: '服务器无响应');
        return;
      }

      Map<String, dynamic> resMap;
      if (res is Map<String, dynamic>) {
        resMap = res;
      } else if (res is String) {
        resMap = jsonDecode(res) as Map<String, dynamic>;
      } else {
        if (!silent && context.mounted) _showResultDialog(context, success: false, msg: '数据格式异常');
        return;
      }

      final code = resMap['code'];
      if (code != 200) {
        if (!silent && context.mounted) _showResultDialog(context, success: false, msg: '服务器错误($code)');
        return;
      }

      final data = resMap['data'];
      if (data == null) {
        if (!silent && context.mounted) _showResultDialog(context, success: true, version: version, buildNumber: buildNumber);
        return;
      }

      final hasUpdate = data['hasUpdate'];
      debugPrint('hasUpdate=$hasUpdate (type=${hasUpdate.runtimeType})');

      if (hasUpdate == true) {
        debugPrint('>>> HAS UPDATE <<<');
        if (context.mounted) _showUpdateDialog(context, data, version, buildNumber);
      } else {
        if (!silent && context.mounted) _showResultDialog(context, success: true, version: version, buildNumber: buildNumber);
      }
    } on DioException catch (e) {
      debugPrint('DioException: ${e.type} ${e.message}');
      if (!silent && context.mounted) _showResultDialog(context, success: false, msg: '网络请求失败');
    } catch (e) {
      debugPrint('Error: $e');
      if (!silent && context.mounted) _showResultDialog(context, success: false, msg: '检查失败');
    }
  }

  // ============ 结果弹窗 ============
  static void _showResultDialog(BuildContext context, {
    required bool success,
    String? msg,
    String? version,
    String? buildNumber,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return ScaleTransition(scale: Tween(begin: 0.8, end: 1.0).animate(curved), child: FadeTransition(opacity: curved, child: child));
      },
      pageBuilder: (_, __, ___) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 240,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8))]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (_, value, child) => Transform.scale(scale: value, child: child),
                  child: Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(color: success ? const Color(0xFFE8F8EE) : const Color(0xFFFFF0F0), shape: BoxShape.circle),
                    child: Icon(success ? Icons.check_rounded : Icons.close_rounded, size: 32, color: success ? const Color(0xFF52C41A) : const Color(0xFFFF2442)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(success ? '已是最新版本' : (msg ?? '检查更新失败'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
                if (success && version != null) ...[
                  const SizedBox(height: 6),
                  Text('v$version ($buildNumber)', style: const TextStyle(fontSize: 12, color: Color(0xFFBBBBBB))),
                ],
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity, height: 40,
                    decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(20)),
                    alignment: Alignment.center,
                    child: const Text('知道了', style: TextStyle(fontSize: 14, color: Color(0xFF666666), fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============ 更新弹窗 - 按钮显示下载进度 ============
  static void _showUpdateDialog(BuildContext context, dynamic data, String currentVersion, String buildNumber) {
    final forceUpdate = data['forceUpdate'] == true;
    final versionName = (data['versionName'] ?? '').toString();
    final updateContent = data['updateContent'];
    final downloadUrl = (data['downloadUrl'] ?? '').toString();
    final packageSize = (data['packageSize'] ?? '').toString();

    List<String> contentList = [];
    if (updateContent is List) {
      contentList = updateContent.map((e) => e.toString()).toList();
    }

    // 下载状态管理
    final progressNotifier = ValueNotifier<double>(0.0);
    final downloadingNotifier = ValueNotifier<bool>(false);
    final doneNotifier = ValueNotifier<bool>(false);

    showGeneralDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      barrierLabel: '',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 500),
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(scale: Tween(begin: 0.7, end: 1.0).animate(curved), child: FadeTransition(opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut), child: child));
      },
      pageBuilder: (_, __, ___) => Center(
        child: Material(
          color: Colors.transparent,
          child: PopScope(
            canPop: !forceUpdate && !downloadingNotifier.value,
            child: Container(
              width: 300,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 10))]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 顶部渐变
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF2442), Color(0xFFFF6B81), Color(0xFFFF8FA3)]),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutBack,
                          builder: (_, value, child) => Transform.scale(scale: value, child: Transform.rotate(angle: (1 - value) * 0.3, child: child)),
                          child: Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                            child: const Icon(Icons.rocket_launch_rounded, size: 36, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('发现新版本', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                          child: Text('v$versionName', style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ),
                  // 更新内容
                  if (contentList.isNotEmpty)
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 140),
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(children: [
                            Container(width: 3, height: 14, decoration: BoxDecoration(color: const Color(0xFFFF2442), borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 8),
                            const Text('更新内容', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
                          ]),
                          const SizedBox(height: 12),
                          Flexible(
                            child: SingleChildScrollView(
                              child: Column(
                                children: contentList.asMap().entries.map((entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 6, right: 8),
                                        width: 18, height: 18,
                                        decoration: const BoxDecoration(color: Color(0xFFFFF0F3), shape: BoxShape.circle),
                                        alignment: Alignment.center,
                                        child: Text('${entry.key + 1}', style: const TextStyle(fontSize: 10, color: Color(0xFFFF2442), fontWeight: FontWeight.w600)),
                                      ),
                                      Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 13, color: Color(0xFF555555), height: 1.5))),
                                    ],
                                  ),
                                )).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (packageSize.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Icon(Icons.download_rounded, size: 12, color: Color(0xFFCCCCCC)),
                          const SizedBox(width: 4),
                          Text(packageSize, style: const TextStyle(fontSize: 11, color: Color(0xFFCCCCCC))),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  // 按钮区域 - 下载进度直接显示在按钮上
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: ValueListenableBuilder<bool>(
                      valueListenable: doneNotifier,
                      builder: (_, done, __) => ValueListenableBuilder<bool>(
                        valueListenable: downloadingNotifier,
                        builder: (_, downloading, ___) => ValueListenableBuilder<double>(
                          valueListenable: progressNotifier,
                          builder: (_, progress, ____) {
                            final p = progress.clamp(0.0, 1.0);

                            if (done) {
                              // 下载完成
                              return Column(
                                children: [
                                  Container(
                                    width: double.infinity, height: 44,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [Color(0xFF52C41A), Color(0xFF73D13D)]),
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text('安装中...', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              );
                            }

                            if (downloading) {
                              // 下载中 - 按钮显示进度条和百分比
                              return Column(
                                children: [
                                  Container(
                                    width: double.infinity, height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF0F3),
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    child: Stack(
                                      children: [
                                        // 进度条背景
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeOut,
                                          width: p > 0 ? 252 * p : 0,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF6B81)]),
                                            borderRadius: BorderRadius.circular(22),
                                          ),
                                        ),
                                        // 百分比文字
                                        Center(
                                          child: Text(
                                            p > 0 ? '正在下载 ${(p * 100).toStringAsFixed(0)}%' : '准备下载...',
                                            style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }

                            // 初始状态
                            return Row(
                              children: [
                                if (!forceUpdate)
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => Navigator.pop(context),
                                      child: Container(
                                        height: 44,
                                        decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(22)),
                                        alignment: Alignment.center,
                                        child: const Text('稍后再说', style: TextStyle(fontSize: 14, color: Color(0xFF999999), fontWeight: FontWeight.w500)),
                                      ),
                                    ),
                                  ),
                                if (!forceUpdate) const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      downloadingNotifier.value = true;
                                      _startDownload(downloadUrl, progressNotifier, doneNotifier, context);
                                    },
                                    child: Container(
                                      height: 44,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF6B81)]),
                                        borderRadius: BorderRadius.circular(22),
                                        boxShadow: [BoxShadow(color: const Color(0xFFFF2442).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                                      ),
                                      alignment: Alignment.center,
                                      child: const Text('立即更新', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
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

  static void _startDownload(
    String url,
    ValueNotifier<double> progressNotifier,
    ValueNotifier<bool> doneNotifier,
    BuildContext context,
  ) async {
    if (url.isEmpty) {
      doneNotifier.value = true;
      return;
    }
    debugPrint('Download: $url');

    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) {
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
          }
        },
        options: Options(receiveTimeout: const Duration(minutes: 10)),
      );

      progressNotifier.value = 1.0;
      doneNotifier.value = true;

      // 自动安装
      try {
        await OpenFilex.open(savePath);
      } catch (_) {
        try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); } catch (_) {}
      }
    } catch (e) {
      debugPrint('Download error: $e');
      // 下载失败，尝试浏览器下载
      try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); } catch (_) {}
      doneNotifier.value = true;
    }
  }
}
