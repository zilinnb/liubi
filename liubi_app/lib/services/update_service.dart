import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:dio/dio.dart';

class UpdateService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://liu.bi/api',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  static Future<void> checkUpdate(BuildContext context, {bool silent = false}) async {
    debugPrint('========== UpdateService.checkUpdate START ==========');
    debugPrint('silent=$silent');

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = packageInfo.version;
      final buildNumber = packageInfo.buildNumber;
      final currentCode = int.tryParse(buildNumber) ?? 0;
      final platform = Platform.isAndroid ? 'android' : 'ios';

      debugPrint('version=$version, buildNumber=$buildNumber, currentCode=$currentCode, platform=$platform');

      final url = '/version/check?platform=$platform&versionCode=$currentCode';
      debugPrint('Request URL: ${_dio.options.baseUrl}$url');

      final response = await _dio.get(url);
      debugPrint('Response statusCode: ${response.statusCode}');
      debugPrint('Response data: ${jsonEncode(response.data)}');

      final res = response.data;
      if (res == null) {
        debugPrint('ERROR: response.data is null');
        if (!silent && context.mounted) {
          _showResultDialog(context, success: false, msg: '服务器无响应');
        }
        return;
      }

      Map<String, dynamic> resMap;
      if (res is Map<String, dynamic>) {
        resMap = res;
      } else if (res is String) {
        resMap = jsonDecode(res) as Map<String, dynamic>;
      } else {
        debugPrint('ERROR: unexpected response type: ${res.runtimeType}');
        if (!silent && context.mounted) {
          _showResultDialog(context, success: false, msg: '数据格式异常');
        }
        return;
      }

      final code = resMap['code'];
      debugPrint('API code: $code');

      if (code != 200) {
        debugPrint('API returned non-200 code: $code');
        if (!silent && context.mounted) {
          _showResultDialog(context, success: false, msg: '服务器返回错误($code)');
        }
        return;
      }

      final data = resMap['data'];
      if (data == null) {
        debugPrint('data is null');
        if (!silent && context.mounted) {
          _showResultDialog(context, success: true, version: version, buildNumber: buildNumber);
        }
        return;
      }

      final hasUpdate = data['hasUpdate'];
      debugPrint('hasUpdate: $hasUpdate (type: ${hasUpdate.runtimeType})');

      if (hasUpdate == true) {
        debugPrint('>>> HAS UPDATE! <<<');
        if (context.mounted) {
          _showUpdateDialog(context, data, version, buildNumber);
        }
      } else {
        debugPrint('No update available');
        if (!silent && context.mounted) {
          _showResultDialog(context, success: true, version: version, buildNumber: buildNumber);
        }
      }
    } on DioException catch (e) {
      debugPrint('DioException: type=${e.type}, message=${e.message}');
      if (!silent && context.mounted) {
        _showResultDialog(context, success: false, msg: '网络请求失败');
      }
    } catch (e, stack) {
      debugPrint('Unknown error: $e\n$stack');
      if (!silent && context.mounted) {
        _showResultDialog(context, success: false, msg: '检查失败');
      }
    }

    debugPrint('========== UpdateService.checkUpdate END ==========');
  }

  // ============ 小红书风格弹窗 ============

  /// 结果弹窗 - 已是最新版本 / 检查失败
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
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
      pageBuilder: (_, __, ___) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 240,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 动画图标
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (_, value, child) {
                    return Transform.scale(scale: value, child: child);
                  },
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: success ? const Color(0xFFE8F8EE) : const Color(0xFFFFF0F0),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      success ? Icons.check_rounded : Icons.close_rounded,
                      size: 32,
                      color: success ? const Color(0xFF52C41A) : const Color(0xFFFF2442),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  success ? '已是最新版本' : (msg ?? '检查更新失败'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF222222)),
                ),
                if (success && version != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'v$version ($buildNumber)',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)),
                  ),
                ],
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(20),
                    ),
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

  /// 更新弹窗 - 小红书风格
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

    showGeneralDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      barrierLabel: '',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 500),
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.7, end: 1.0).animate(curved),
          child: FadeTransition(opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut), child: child),
        );
      },
      pageBuilder: (_, __, ___) => Center(
        child: Material(
          color: Colors.transparent,
          child: PopScope(
            canPop: !forceUpdate,
            child: Container(
              width: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 10))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 顶部渐变区域
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFF2442), Color(0xFFFF6B81), Color(0xFFFF8FA3)],
                      ),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        // 旋转动画图标
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutBack,
                          builder: (_, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Transform.rotate(angle: (1 - value) * 0.3, child: child),
                            );
                          },
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.rocket_launch_rounded, size: 36, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '发现新版本',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'v$versionName',
                            style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 更新内容区域
                  if (contentList.isNotEmpty)
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 160),
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(width: 3, height: 14, decoration: BoxDecoration(color: const Color(0xFFFF2442), borderRadius: BorderRadius.circular(2))),
                              const SizedBox(width: 8),
                              const Text('更新内容', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Flexible(
                            child: SingleChildScrollView(
                              child: Column(
                                children: contentList.asMap().entries.map((entry) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.only(top: 6, right: 8),
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF0F3),
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${entry.key + 1}',
                                            style: const TextStyle(fontSize: 10, color: Color(0xFFFF2442), fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 13, color: Color(0xFF555555), height: 1.5))),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // 包大小
                  if (packageSize.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(Icons.download_rounded, size: 12, color: const Color(0xFFCCCCCC)),
                          const SizedBox(width: 4),
                          Text(packageSize, style: const TextStyle(fontSize: 11, color: Color(0xFFCCCCCC))),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  // 按钮区域
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Row(
                      children: [
                        if (!forceUpdate)
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                alignment: Alignment.center,
                                child: const Text('稍后再说', style: TextStyle(fontSize: 14, color: Color(0xFF999999), fontWeight: FontWeight.w500)),
                              ),
                            ),
                          ),
                        if (!forceUpdate) const SizedBox(width: 12),
                        Expanded(
                          flex: forceUpdate ? 1 : 1,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              _doUpdate(context, downloadUrl, forceUpdate);
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

  /// 执行更新
  static Future<void> _doUpdate(BuildContext context, String url, bool forceUpdate) async {
    if (url.isEmpty) {
      debugPrint('Download URL is empty!');
      return;
    }
    debugPrint('Starting download: $url');

    if (!Platform.isAndroid) {
      try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); } catch (_) {}
      return;
    }

    _showDownloadDialog(context, url, forceUpdate);
  }

  /// 下载进度弹窗 - 小红书风格
  static void _showDownloadDialog(BuildContext context, String url, bool forceUpdate) {
    final progressNotifier = ValueNotifier<double>(0.0);
    final statusNotifier = ValueNotifier<String>('正在下载...');
    final doneNotifier = ValueNotifier<bool>(false);

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
      pageBuilder: (_, __, ___) => Center(
        child: Material(
          color: Colors.transparent,
          child: PopScope(
            canPop: false,
            child: Container(
              width: 260,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 下载动画图标
                  ValueListenableBuilder<bool>(
                    valueListenable: doneNotifier,
                    builder: (_, done, __) {
                      if (done) {
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.elasticOut,
                          builder: (_, value, child) => Transform.scale(scale: value, child: child),
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(color: Color(0xFFE8F8EE), shape: BoxShape.circle),
                            child: const Icon(Icons.check_circle_rounded, size: 36, color: Color(0xFF52C41A)),
                          ),
                        );
                      }
                      return Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0F3),
                          shape: BoxShape.circle,
                        ),
                        child: const CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation(Color(0xFFFF2442)),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<String>(
                    valueListenable: statusNotifier,
                    builder: (_, status, __) => Text(
                      status,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF222222)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 进度条
                  ValueListenableBuilder<double>(
                    valueListenable: progressNotifier,
                    builder: (_, progress, __) {
                      final p = progress.clamp(0.0, 1.0);
                      return Column(
                        children: [
                          Stack(
                            children: [
                              Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F0F0),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                                height: 8,
                                width: p > 0 ? 204 * p : 0,
                                decoration: BoxDecoration(
                                  gradient: p >= 1.0
                                      ? const LinearGradient(colors: [Color(0xFF52C41A), Color(0xFF73D13D)])
                                      : const LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF6B81)]),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            p > 0 ? '${(p * 100).toStringAsFixed(1)}%' : '准备中...',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: p >= 1.0 ? const Color(0xFF52C41A) : const Color(0xFFFF2442),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: doneNotifier,
                    builder: (_, done, __) => done
                        ? Column(children: [
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: double.infinity,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                alignment: Alignment.center,
                                child: const Text('关闭', style: TextStyle(fontSize: 14, color: Color(0xFF666666), fontWeight: FontWeight.w500)),
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
            statusNotifier.value = '正在下载... ${(received / total * 100).toStringAsFixed(0)}%';
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
      debugPrint('Download error: $e');
      statusNotifier.value = '下载失败';
      doneNotifier.value = true;
      try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); } catch (_) {}
    }
  }
}
