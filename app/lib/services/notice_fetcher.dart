import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme.dart';

class Notice {
  final String? id;
  final String title;
  final String message;

  const Notice({this.id, required this.title, required this.message});
}

/// notice.json 拉取：每次打开 App 强制推送，不失效
class NoticeFetcher {
  static const _sources = [
    'https://raw.githubusercontent.com/harpsvials/mustardseed-app/main/notice.json',
    'https://cdn.jsdelivr.net/gh/harpsvials/mustardseed-app@main/notice.json',
  ];

  static Future<Notice?> fetch() async {
    for (final url in _sources) {
      try {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final list = data['notices'] as List?;
          if (list == null || list.isEmpty) return null;
          final last = (list.last as Map).cast<String, dynamic>();
          final title = (last['title'] ?? '').toString();
          final message = (last['message'] ?? '').toString();
          if (title.isEmpty && message.isEmpty) return null;
          return Notice(
            id: last['id']?.toString(),
            title: title,
            message: message,
          );
        }
      } catch (_) {}
    }
    return null;
  }

  /// 弹窗展示通知（可复用已拉取结果，避免重复请求）
  static Future<void> showIfAny(BuildContext context, {Notice? cached}) async {
    final n = cached ?? await fetch();
    if (n == null || !context.mounted) return;
    final notice = n;
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.lineStrong),
        ),
        title: Row(
          children: [
            const Icon(Icons.notifications_active,
                color: AppColors.mustard, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                notice.title.isEmpty ? '通知' : notice.title,
                style: const TextStyle(
                  color: AppColors.cream,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          notice.message,
          style: const TextStyle(
            color: AppColors.cream,
            fontSize: 15,
            height: 1.7,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了',
                style: TextStyle(color: AppColors.mustard)),
          ),
        ],
      ),
    );
  }
}
