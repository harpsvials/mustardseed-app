import 'dart:convert';

import 'package:http/http.dart' as http;

/// 默想中的一小节：小标题 + 正文段 + 一个问题
class ReflectionSection {
  final String heading;
  final List<String> paragraphs;
  final String question;

  const ReflectionSection({
    required this.heading,
    required this.paragraphs,
    required this.question,
  });
}

/// 当日「默想」与「写给神的信」。
/// 数据在仓库根目录 qt-reflection.json，经 Worker /api/data 取回；
/// 只有 date 与当日经文一致时才显示，避免经文换了、默想还是旧的。
class QtReflection {
  final String date;
  final String dateLabel;
  final String title;
  final String titleEn;
  final String sourceUrl;
  final String sourceLabel;
  final List<ReflectionSection> sections;
  final String letter;

  const QtReflection({
    required this.date,
    required this.dateLabel,
    required this.title,
    required this.titleEn,
    required this.sourceUrl,
    required this.sourceLabel,
    required this.sections,
    required this.letter,
  });

  bool get isEmpty => sections.isEmpty && letter.isEmpty;

  String get titleLine {
    if (title.isNotEmpty && titleEn.isNotEmpty) return '$title（$titleEn）';
    return title.isNotEmpty ? title : titleEn;
  }

  factory QtReflection.fromJson(Map<String, dynamic> j) {
    final raw = j['reflection'];
    final sections = <ReflectionSection>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is! Map<String, dynamic>) continue;
        final ps = <String>[];
        final rawPs = e['paragraphs'];
        if (rawPs is List) {
          for (final p in rawPs) {
            if (p is String && p.isNotEmpty) ps.add(p);
          }
        }
        sections.add(ReflectionSection(
          heading: (e['heading'] ?? '').toString(),
          paragraphs: ps,
          question: (e['question'] ?? '').toString(),
        ));
      }
    }
    return QtReflection(
      date: (j['date'] ?? '').toString(),
      dateLabel: (j['dateLabel'] ?? j['date'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      titleEn: (j['titleEn'] ?? '').toString(),
      sourceUrl: (j['sourceUrl'] ?? '').toString(),
      sourceLabel: (j['sourceLabel'] ?? "Living Life · Today's QT").toString(),
      sections: sections,
      letter: (j['letter'] ?? '').toString(),
    );
  }

  // 走自家域名的 /api/data（Worker 路由），静态路径会被 Cloudflare 验证拦住。
  static const _sources = [
    'https://zhuzhouchurch.com/api/data?f=qt-reflection.json',
  ];

  static Future<QtReflection?> fetch() async {
    for (final url in _sources) {
      try {
        final res = await http
            .get(Uri.parse(url), headers: const {'cache-control': 'no-store'})
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final j = jsonDecode(res.body);
          if (j is Map<String, dynamic>) {
            final r = QtReflection.fromJson(j);
            if (!r.isEmpty) return r;
          }
        }
      } catch (_) {}
    }
    return null;
  }
}
