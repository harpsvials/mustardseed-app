import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';

/// GitHub Releases 更新检测：tag 为 vYYYY.MM.DD.HHMM 时间格式
/// 比本地新 → 引导下载 APK 并触发系统安装（Android）
class UpdateChecker {
  static const _repo =
      'https://api.github.com/repos/harpsvials/mustardseed-app/releases/latest';
  // 弱网/国内网络下 api.github.com 不可达时的兜底源（version.json 由 CI 每次构建后自动更新）
  static const _rawVersion =
      'https://harpsvials.github.io/mustardseed-app/version.json';
  static const _jsdelivrVersion =
      'https://cdn.jsdelivr.net/gh/harpsvials/mustardseed-app@main/version.json';
  static const _fallback =
      'https://github.com/harpsvials/mustardseed-app/releases/latest';

  static const _installerChannel = MethodChannel('mustardseed/installer');

  /// 返回 [tag, 下载地址]（APK 直链优先，Release 页面兜底），无更新或失败返回 null
  static Future<(String, String)?> check() async {
    final info = await PackageInfo.fromPlatform();
    final local = info.version;
    // 多源依次尝试：GitHub API → raw → jsDelivr，任一成功即可
    for (final src in [_repo, _rawVersion, _jsdelivrVersion]) {
      try {
        final res = await http
            .get(
                Uri.parse(src),
                headers: {
                  'Accept': 'application/vnd.github+json',
                  'User-Agent': 'mustardseed-app',
                })
            .timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) continue;
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final isApi = src == _repo;
        final tag = (isApi
                ? (data['tag_name'] ?? '')
                : (data['version'] ?? ''))
            .toString();
        if (tag.isEmpty) continue;
        // 本地版本也以 vYYYY.MM.DD.HHMM 构建时，字符串比较即可
        final remoteKey = tag.replaceFirst(RegExp(r'^v'), '');
        final localKey = local.replaceFirst(RegExp(r'^v'), '');
        if (remoteKey.isEmpty || localKey.isEmpty) continue;
        final remoteNum =
            int.tryParse(remoteKey.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        final localNum =
            int.tryParse(localKey.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        if (remoteNum <= localNum) return null;
        // 优先取 APK 安装包直链
        String? apkUrl;
        String? pageUrl;
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
          pageUrl = data['html_url']?.toString();
        } else {
          apkUrl = data['apk']?.toString();
          pageUrl = data['url']?.toString();
        }
        final url = (apkUrl ?? pageUrl ?? _fallback).toString();
        return (tag, url);
      } catch (_) {
        // 该源失败，继续尝试下一个源
      }
    }
    return null;
  }

  /// 弹窗询问，确认后 Android 直接下载并引导安装，iOS 打开 Release 页面
  static Future<void> showIfAny(BuildContext context) async {
    final result = await check();
    if (result == null || !context.mounted) return;
    final (tag, url) = result;
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.lineStrong),
        ),
        title: const Text(
          '发现新版本',
          style: TextStyle(color: AppColors.cream, fontWeight: FontWeight.w700),
        ),
        content: Text(
          '最新版本 $tag 已发布，是否立即下载并更新？',
          style: const TextStyle(color: AppColors.cream, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                const Text('暂不', style: TextStyle(color: AppColors.creamFaint)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (Platform.isAndroid && url.endsWith('.apk')) {
                await _downloadAndInstall(context, url);
              } else {
                await launchUrl(Uri.parse(url),
                    mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('立即更新',
                style: TextStyle(color: AppColors.mustard)),
          ),
        ],
      ),
    );
  }

  /// 下载 APK 到缓存目录并用系统安装器安装
  static Future<void> _downloadAndInstall(
      BuildContext context, String apkUrl) async {
    final dir = await getApplicationCacheDirectory();
    final target = '${dir.path}/update/update.apk';
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          backgroundColor: AppColors.bgRaised,
          content: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.mustard,
                ),
              ),
              SizedBox(width: 18),
              Text('正在下载更新…',
                  style: TextStyle(color: AppColors.cream)),
            ],
          ),
        ),
      );
    }
    try {
      final res = await http
          .get(Uri.parse(apkUrl),
              headers: {'User-Agent': 'mustardseed-app'})
          .timeout(const Duration(minutes: 5));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final file = await File(target).create(recursive: true);
      await file.writeAsBytes(res.bodyBytes, flush: true);
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      await _installerChannel.invokeMethod('install', {'path': target});
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('下载失败，请稍后重试',
                style: TextStyle(color: AppColors.cream)),
            backgroundColor: AppColors.bgRaised,
          ),
        );
      }
      // 下载失败时兜底打开 Release 页面
      await launchUrl(Uri.parse(apkUrl),
          mode: LaunchMode.externalApplication);
    }
  }
}
