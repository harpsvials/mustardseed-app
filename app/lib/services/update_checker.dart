import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';

/// GitHub Releases 更新检测：tag 为 vYYYY.MM.DD.HHMM 时间格式
class UpdateChecker {
  static const _repo = 'https://api.github.com/repos/harpsvials/mustardseed-app/releases/latest';

  /// 返回 [tag, url]，无更新或检查失败返回 null
  static Future<(String, String)?> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final local = info.version; // 构建时设为时间格式
      final res = await http
          .get(Uri.parse(_repo),
              headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final tag = (data['tag_name'] ?? '').toString();
      if (tag.isEmpty) return null;
      // 本地版本也以 vYYYY.MM.DD.HHMM 构建时，字符串比较即可
      final remoteKey = tag.replaceFirst(RegExp(r'^v'), '');
      final localKey = local.replaceFirst(RegExp(r'^v'), '');
      if (remoteKey.isEmpty || localKey.isEmpty) return null;
      final remoteNum =
          int.tryParse(remoteKey.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
      final localNum =
          int.tryParse(localKey.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
      if (remoteNum <= localNum) return null;
      final htmlUrl = (data['html_url'] ?? 'https://github.com/harpsvials/mustardseed-app/releases').toString();
      return (tag, htmlUrl);
    } catch (_) {
      return null;
    }
  }

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
          '最新版本 $tag 已发布，是否前往下载？',
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
              await launchUrl(Uri.parse(url),
                  mode: LaunchMode.externalApplication);
            },
            child: const Text('下载',
                style: TextStyle(color: AppColors.mustard)),
          ),
        ],
      ),
    );
  }
}
