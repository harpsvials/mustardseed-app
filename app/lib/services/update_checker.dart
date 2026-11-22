import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';

/// 一次版本检查的结果（关于页与启动弹窗共用）
class UpdateCheckInfo {
  final String current;
  final String? latest;
  final String? apkUrl;
  final bool hasUpdate;
  final String? error;

  const UpdateCheckInfo({
    required this.current,
    this.latest,
    this.apkUrl,
    this.hasUpdate = false,
    this.error,
  });

  String get summary {
    if (error != null) return error!;
    if (latest == null) return '暂时读不到版本信息';
    return hasUpdate ? '发现新版本 $latest' : '已是最新版本';
  }
}

/// GitHub Releases 更新检测：tag 为 vYYYY.MM.DD.HHMM 时间格式
/// 比本地新 → 引导下载 APK 并触发系统安装（Android）
class UpdateChecker {
  static const _repo =
      'https://api.github.com/repos/harpsvials/mustardseed-app/releases/latest';
  // 弱网/国内网络下 api.github.com 不可达时的兜底源（version.json 由 CI 每次构建后自动更新）
  // 走自己域名的 /api/data：静态路径会被 Cloudflare 验证拦成 403，/api/* 不受影响
  static const _rawVersion = 'https://zhuzhouchurch.com/api/data?f=version.json';
  static const _fallback =
      'https://github.com/harpsvials/mustardseed-app/releases/latest';

  static const _installerChannel = MethodChannel('mustardseed/installer');

  /// 当前安装版本，读不到时返回空串
  static Future<String> currentVersion() async {
    try {
      return (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      return '';
    }
  }

  /// 依次查各源，返回完整状态（关于页用来显示「当前 / 最新 / 结果」）
  static Future<UpdateCheckInfo> probe() async {
    final current = await currentVersion();
    final localNum =
        int.tryParse(current.replaceFirst(RegExp(r'^v'), '').replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    String? error;
    for (final src in [_rawVersion, _repo]) {
      try {
        final res = await http.get(Uri.parse(src), headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'mustardseed-app',
          'cache-control': 'no-store',
        }).timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) {
          error = '版本服务返回 ${res.statusCode}';
          continue;
        }
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final isApi = src == _repo;
        final tag =
            (isApi ? (data['tag_name'] ?? '') : (data['version'] ?? '')).toString();
        if (tag.isEmpty) {
          error = '版本号为空';
          continue;
        }
        final remoteNum =
            int.tryParse(tag.replaceFirst(RegExp(r'^v'), '').replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        String? apkUrl;
        if (isApi) {
          final assets = data['assets'] as List?;
          if (assets != null) {
            for (final a in assets) {
              final m = a?['name']?.toString() ?? '';
              if (m.endsWith('.apk')) {
                apkUrl = a?['browser_download_url']?.toString();
                break;
              }
            }
          }
        } else {
          apkUrl = data['apk']?.toString();
        }
        var url = (apkUrl ?? _fallback).toString();
        // Android 一律走自家域名的 /api/apk：Release 直链在国内只有几十 KB/s。
        if (Platform.isAndroid) url = 'https://zhuzhouchurch.com/api/apk';
        final hasUpdate = localNum > 0 && remoteNum > localNum;
        return UpdateCheckInfo(
          current: current,
          latest: tag,
          apkUrl: url,
          hasUpdate: hasUpdate,
          error: localNum == 0 ? '读不到本机版本号' : null,
        );
      } catch (e) {
        error = '连不上版本服务';
      }
    }
    return UpdateCheckInfo(current: current, error: error ?? '连不上版本服务');
  }

  /// 返回 [tag, 下载地址]，无更新或失败返回 null
  static Future<(String, String)?> check() async {
    final info = await probe();
    if (!info.hasUpdate || info.latest == null || info.apkUrl == null) return null;
    return (info.latest!, info.apkUrl!);
  }

  /// 弹窗询问，确认后 Android 直接下载并引导安装，iOS 打开 Release 页面
  static Future<void> showIfAny(BuildContext context) async {
    final info = await probe();
    if (info.hasUpdate && context.mounted) {
      await showUpdateDialog(context, info);
    }
  }

  static Future<void> showUpdateDialog(BuildContext context, UpdateCheckInfo info) async {
    if (!context.mounted) return;
    final tag = info.latest ?? '';
    final url = info.apkUrl ?? _fallback;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppColors.lineStrong),
        ),
        title: Text(
          '发现新版本',
          style: TextStyle(color: AppColors.cream, fontWeight: FontWeight.w700),
        ),
        content: Text(
          '最新版本 $tag 已发布（当前 ${info.current}），是否立即下载并更新？\n'
          '安装包约 86 MB，建议在 Wi-Fi 下进行。',
          style: TextStyle(color: AppColors.cream, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('暂不', style: TextStyle(color: AppColors.creamFaint)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (Platform.isAndroid) {
                await _downloadAndInstall(context, url, tag);
              } else {
                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              }
            },
            child: Text('立即更新', style: TextStyle(color: AppColors.mustard)),
          ),
        ],
      ),
    );
  }

  /// 下载 APK 到缓存目录并用系统安装器安装。边下边写盘，带进度，避免 86 MB 全塞内存。
  static Future<void> _downloadAndInstall(
      BuildContext context, String apkUrl, String tag) async {
    final dir = await getApplicationCacheDirectory();
    final target = '${dir.path}/update/update.apk';
    final progress = ValueNotifier<double>(0);
    final receivedText = ValueNotifier<String>('0.0 MB');
    final totalText = ValueNotifier<String>('');

    if (context.mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.bgRaised,
          content: ListenableBuilder(
            listenable: Listenable.merge([progress, receivedText, totalText]),
            builder: (_, __) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('正在下载更新 $tag…', style: TextStyle(color: AppColors.cream)),
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: progress.value <= 0 ? null : progress.value,
                  backgroundColor: AppColors.lineStrong,
                  color: AppColors.mustard,
                  minHeight: 6,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(progress.value * 100).toStringAsFixed(0)}%  '
                  '${receivedText.value}${totalText.value}',
                  style: TextStyle(fontSize: 12.5, color: AppColors.creamFaint),
                ),
                const SizedBox(height: 6),
                Text(
                  '下载期间请不要锁屏，完成后会自动打开安装器。',
                  style: TextStyle(fontSize: 11.5, color: AppColors.creamFaint),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(apkUrl));
      req.headers['User-Agent'] = 'mustardseed-app';
      final res = await client
          .send(req)
          .timeout(const Duration(seconds: 40));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final total = res.contentLength ?? 0;
      final file = await File(target).create(recursive: true);
      final sink = file.openWrite();
      var received = 0;
      await for (final chunk in res.stream.timeout(const Duration(seconds: 90))) {
        sink.add(chunk);
        received += chunk.length;
        receivedText.value = '${(received / 1048576).toStringAsFixed(1)} MB';
        if (total > 0) {
          progress.value = received / total;
          totalText.value = ' / ${(total / 1048576).toStringAsFixed(1)} MB';
        }
      }
      await sink.flush();
      await sink.close();
      progress.value = 1;

      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      await _installWithPermission(context, target);
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下载中断：${e.toString().split('\n').first}',
                style: TextStyle(color: AppColors.cream)),
            backgroundColor: AppColors.bgRaised,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: '用浏览器下载',
              textColor: AppColors.mustard,
              onPressed: () => launchUrl(Uri.parse(apkUrl),
                  mode: LaunchMode.externalApplication),
            ),
          ),
        );
      }
    } finally {
      client.close();
    }
  }

  /// 调用安装器；若系统未允许「安装未知应用」，打开设置并在用户返回时自动重试
  static Future<void> _installWithPermission(
      BuildContext context, String path) async {
    var finished = false;
    AppLifecycleListener? listener;

    Future<String?> tryInstall() async {
      try {
        return await _installerChannel.invokeMethod<String>('install', {'path': path});
      } catch (e) {
        return 'error:${e.toString()}';
      }
    }

    listener = AppLifecycleListener(onResume: () async {
      if (finished) return;
      final st = await tryInstall();
      if (st == 'ok') {
        finished = true;
        listener?.dispose();
      }
    });

    final first = await tryInstall();
    if (first == 'ok') {
      finished = true;
      listener.dispose();
      return;
    }
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppColors.lineStrong),
        ),
        title: Text('还差一步就能安装',
            style: TextStyle(color: AppColors.cream, fontWeight: FontWeight.w700)),
        content: Text(
          '系统需要你允许本应用「安装未知应用」。点下面的按钮去开启，'
          '授权后返回本应用会自动继续安装；安装包已经下载好，不用重新下载。',
          style: TextStyle(color: AppColors.cream, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('取消', style: TextStyle(color: AppColors.creamFaint)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await _installerChannel.invokeMethod('settings');
              } catch (_) {}
            },
            child: Text('去开启', style: TextStyle(color: AppColors.mustard)),
          ),
        ],
      ),
    );
  }
}
