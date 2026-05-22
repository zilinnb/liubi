import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:dio/dio.dart';

class UpdateService {
  // 全新独立的Dio实例，不依赖ApiService，避免任何拦截器干扰
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://liu.bi/api',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  /// 检查更新
  /// [silent] = true: 进入app自动检查，有更新才弹窗，无更新不弹
  /// [silent] = false: 用户手动点击"检查更新"，无论结果都弹窗
  static Future<void> checkUpdate(BuildContext context, {bool silent = false}) async {
    debugPrint('========== UpdateService.checkUpdate START ==========');
    debugPrint('silent=$silent');

    try {
      // 1. 获取当前版本信息
      final packageInfo = await PackageInfo.fromPlatform();
      final appName = packageInfo.appName;
      final version = packageInfo.version;
      final buildNumber = packageInfo.buildNumber;
      final currentCode = int.tryParse(buildNumber) ?? 0;
      final platform = Platform.isAndroid ? 'android' : 'ios';

      debugPrint('appName=$appName, version=$version, buildNumber=$buildNumber, currentCode=$currentCode, platform=$platform');

      // 2. 请求版本检查接口
      final url = '/version/check?platform=$platform&versionCode=$currentCode';
      debugPrint('Request URL: ${_dio.options.baseUrl}$url');

      final response = await _dio.get(url);
      debugPrint('Response statusCode: ${response.statusCode}');
      debugPrint('Response data type: ${response.data.runtimeType}');
      debugPrint('Response data: ${jsonEncode(response.data)}');

      // 3. 解析响应
      final res = response.data;
      if (res == null) {
        debugPrint('ERROR: response.data is null');
        if (!silent && context.mounted) {
          _showDialog(context, failed: true, msg: '服务器无响应');
        }
        return;
      }

      // 确保是Map
      Map<String, dynamic> resMap;
      if (res is Map<String, dynamic>) {
        resMap = res;
      } else if (res is String) {
        resMap = jsonDecode(res) as Map<String, dynamic>;
      } else {
        debugPrint('ERROR: unexpected response type: ${res.runtimeType}');
        if (!silent && context.mounted) {
          _showDialog(context, failed: true, msg: '数据格式异常');
        }
        return;
      }

      final code = resMap['code'];
      debugPrint('API code: $code');

      if (code != 200) {
        debugPrint('API returned non-200 code: $code, msg: ${resMap['msg']}');
        if (!silent && context.mounted) {
          _showDialog(context, failed: true, msg: '服务器返回错误($code)');
        }
        return;
      }

      final data = resMap['data'];
      if (data == null) {
        debugPrint('data is null, showing no update');
        if (!silent && context.mounted) {
          _showDialog(context, noUpdate: true, version: version, buildNumber: buildNumber);
        }
        return;
      }

      final hasUpdate = data['hasUpdate'];
      debugPrint('hasUpdate: $hasUpdate (type: ${hasUpdate.runtimeType})');

      if (hasUpdate == true) {
        debugPrint('>>> HAS UPDATE! Showing update dialog <<<');
        if (context.mounted) {
          _showUpdateDialog(context, data, version, buildNumber);
        }
      } else {
        debugPrint('No update available');
        if (!silent && context.mounted) {
          _showDialog(context, noUpdate: true, version: version, buildNumber: buildNumber);
        }
      }
    } on DioException catch (e) {
      debugPrint('DioException: type=${e.type}, message=${e.message}');
      debugPrint('DioException response: ${e.response?.data}');
      debugPrint('DioException statusCode: ${e.response?.statusCode}');
      if (!silent && context.mounted) {
        _showDialog(context, failed: true, msg: '网络请求失败: ${e.type.name}');
      }
    } catch (e, stack) {
      debugPrint('Unknown error: $e');
      debugPrint('Stack: $stack');
      if (!silent && context.mounted) {
        _showDialog(context, failed: true, msg: '检查失败: $e');
      }
    }

    debugPrint('========== UpdateService.checkUpdate END ==========');
  }

  /// 简单对话框 - 无更新 / 检查失败
  static void _showDialog(BuildContext context, {
    bool noUpdate = false,
    bool failed = false,
    String? msg,
    String? version,
    String? buildNumber,
  }) {
    final icon = noUpdate ? Icons.check_circle_outline : Icons.error_outline;
    final iconColor = noUpdate ? const Color(0xFF52C41A) : const Color(0xFFFF2442);
    final title = noUpdate ? '已是最新版本' : (msg ?? '检查更新失败');
    final subtitle = noUpdate && version != null ? '当前版本: v$version ($buildNumber)' : null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: iconColor),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('确定', style: TextStyle(color: Color(0xFFFF2442))),
          ),
        ],
      ),
    );
  }

  /// 更新对话框
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

    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (ctx) => PopScope(
        canPop: !forceUpdate,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: EdgeInsets.zero,
          title: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                const Icon(Icons.system_update, size: 36, color: Colors.white),
                const SizedBox(height: 8),
                const Text('发现新版本', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 4),
                Text('v$versionName', style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (contentList.isNotEmpty) ...[
                const Text('更新内容:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ...contentList.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(margin: const EdgeInsets.only(top: 7, right: 6), width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFFFF2442), shape: BoxShape.circle)),
                      Expanded(child: Text(item, style: const TextStyle(fontSize: 12, color: Color(0xFF666666), height: 1.4))),
                    ],
                  ),
                )),
              ],
              if (packageSize.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('安装包大小: $packageSize', style: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB))),
              ],
            ],
          ),
          actions: [
            if (!forceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('稍后再说', style: TextStyle(color: Color(0xFF999999))),
              ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _doUpdate(context, downloadUrl, forceUpdate);
              },
              child: const Text('立即更新', style: TextStyle(color: Color(0xFFFF2442), fontWeight: FontWeight.w600)),
            ),
          ],
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

  /// 下载进度对话框
  static void _showDownloadDialog(BuildContext context, String url, bool forceUpdate) {
    final progressNotifier = ValueNotifier<double>(0.0);
    final statusNotifier = ValueNotifier<String>('正在下载...');
    final doneNotifier = ValueNotifier<bool>(false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.system_update, size: 40, color: Color(0xFFFF2442)),
              const SizedBox(height: 12),
              ValueListenableBuilder<String>(
                valueListenable: statusNotifier,
                builder: (_, status, __) => Text(status, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<double>(
                valueListenable: progressNotifier,
                builder: (_, progress, __) {
                  final p = progress.clamp(0.0, 1.0);
                  return Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: p > 0 ? p : null,
                          minHeight: 8,
                          backgroundColor: const Color(0xFFF0F0F0),
                          valueColor: AlwaysStoppedAnimation(p >= 1.0 ? const Color(0xFF52C41A) : const Color(0xFFFF2442)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(p > 0 ? '${(p * 100).toStringAsFixed(1)}%' : '准备中...', style: const TextStyle(fontSize: 14, color: Color(0xFF999999))),
                    ],
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: doneNotifier,
                builder: (_, done, __) => done
                    ? Column(children: [
                        const SizedBox(height: 12),
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
                      ])
                    : const SizedBox.shrink(),
              ),
            ],
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
        statusNotifier.value = '下载失败: 无法获取存储目录';
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
