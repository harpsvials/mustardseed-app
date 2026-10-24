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
    'https://harpsvials.github.io/mustardseed-app/notice.json',
    'https://raw.githubusercontent.com/harpsvials/mustardseed-app/main/notice.json',
    'https://cdn.jsdelivr.net/gh/harpsvials/mustardseed-app@main/notice.json',
  ];

  // 云端不可达时的内置兜底消息，保证每次打开都强制推送、消息不失效
  static const _fallbackTitle = '芥菜种教会';
  static const _fallbackMessage =
      '亲爱的弟兄姐妹，祝福您平安喜乐，身体健壮、凡事兴盛，正如你的灵魂兴盛一样。';

  static Future<Notice?> fetch() async {
    for (final url in _sources) {
      try {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final list = data['notices'] as List?;
          if (list == null || list.isEmpty) continue;
          final last = (list.last as Map).cast<String, dynamic>();
          final title = (last['title'] ?? '').toString();
          // notice.json 实际字段为 text；兼容 title/message 历史格式
          final message = (last['text'] ?? last['message'] ?? '').toString();
          if (title.isEmpty && message.isEmpty) continue;
          return Notice(
            id: last['id']?.toString(),
            title: title,
            message: message,
          );
        }
      } catch (_) {}
    }
    // 网络拉取全部失败时回退到内置消息，避免 iOS 等弱网环境收不到推送
    return const Notice(title: _fallbackTitle, message: _fallbackMessage);
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
