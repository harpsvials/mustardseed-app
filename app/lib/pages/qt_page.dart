import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../i18n.dart';
import '../theme.dart';

/// 今日灵修快照：与网站同源，读 qt-data.json（由 GitHub Actions 每日抓取生成）
class QtData {
  final String date;
  final String dateLabel;
  final String weekday;
  final String topic;
  final String subtitle;
  final String reading;
  final String sourceUrl;
  final String updatedLabel;

  const QtData({
    required this.date,
    required this.dateLabel,
    required this.weekday,
    required this.topic,
    required this.subtitle,
    required this.reading,
    required this.sourceUrl,
    required this.updatedLabel,
  });

  factory QtData.fromJson(Map<String, dynamic> j) => QtData(
        date: (j['date'] ?? '').toString(),
        dateLabel: (j['dateLabel'] ?? j['date'] ?? '').toString(),
        weekday: (j['weekday'] ?? '').toString(),
        topic: (j['topic'] ?? '').toString(),
        subtitle: (j['subtitle'] ?? '').toString(),
        reading: (j['reading'] ?? '').toString(),
        sourceUrl: (j['sourceUrl'] ?? '').toString(),
        updatedLabel: (j['updatedLabel'] ?? j['updated'] ?? '').toString(),
      );

  /// 贴纸上的日期行：2026年11月8日 · 星期日
  String get stamp {
    final tail = weekday.isEmpty ? '' : ' · $weekday';
    return '$dateLabel$tail';
  }

  static const _sources = [
    'https://harpsvials.github.io/mustardseed-app/qt-data.json',
    'https://raw.githubusercontent.com/harpsvials/mustardseed-app/main/qt-data.json',
    'https://cdn.jsdelivr.net/gh/harpsvials/mustardseed-app@main/qt-data.json',
  ];

  /// 依次尝试各源，全部失败返回 null
  static Future<QtData?> fetch() async {
    for (final url in _sources) {
      try {
        final res = await http
            .get(Uri.parse(url), headers: const {'cache-control': 'no-store'})
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final j = jsonDecode(res.body);
          if (j is Map<String, dynamic>) return QtData.fromJson(j);
        }
      } catch (_) {}
    }
    return null;
  }

  /// 台北今天（yyyy-mm-dd），用于判断快照是不是当天的
  static String taipeiToday() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }
}

class QtPage extends StatefulWidget {
  const QtPage({super.key});

  @override
  State<QtPage> createState() => _QtPageState();
}

class _QtPageState extends State<QtPage> {
  QtData? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await QtData.fetch();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.mustard,
      backgroundColor: AppColors.bgCard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          _hero(),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_data == null)
            _errorCard()
          else
            _sheet(_data!),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _hero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.bgRaised,
        border: Border(bottom: BorderSide(color: AppColors.lineStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppLocale.value == AppLocale.en ? 'Daily Devotion' : '今日灵修',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mustard,
                  letterSpacing: .5,
                  height: 1.2,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _loading ? null : _load,
                tooltip: '重新读取',
                icon: Icon(Icons.refresh, size: 20, color: AppColors.creamDim),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            AppLocale.value == AppLocale.en
                ? 'The Living Life · today’s theme and reading, two stickers, each stamped with its date.'
                : '《活泼的生命》每日灵修：今天的主题与经文范围，两枚贴纸各自标着日期。',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.creamDim,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lineStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '暂时读不到今天的内容',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.cream,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '可能是网络不通，或今天的快照还没生成。稍后点右上角刷新再试。',
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: AppColors.creamDim,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _load,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.mustard,
              foregroundColor: const Color(0xFF24301B),
            ),
            child: const Text('重新读取'),
          ),
        ],
      ),
    );
  }

  Widget _sheet(QtData d) {
    final isToday = d.date == QtData.taipeiToday();
    return Column(
      children: [
        if (!isToday)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.terra.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.terra.withValues(alpha: .45)),
            ),
            child: Text(
              '今天的内容还没更新，下面显示的是 ${d.dateLabel} 的话语。',
              style: TextStyle(
                fontSize: 14.5,
                height: 1.55,
                color: AppColors.terraSoft,
              ),
            ),
          ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.fromLTRB(18, 26, 18, 18),
          decoration: BoxDecoration(
            color: const Color(0xFFF4EAD3),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2D3B2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 贴纸一：今天的主题 ──
              Transform.rotate(
                angle: -1.3 * math.pi / 180,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0AE33),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(9),
                    ),
                    border: Border.all(color: const Color(0xFFFFF8E7), width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocale.value == AppLocale.en
                            ? 'TODAY’S THEME'
                            : '今天的主题',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: Color(0xB33A2E10),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        d.topic,
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          color: Color(0xFF2A2313),
                        ),
                      ),
                      if (d.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          d.subtitle,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: Color(0xFF9C4F28),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _StampLine(text: d.stamp, dark: false),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              // ── 贴纸二：经文范围（深绿胶带式横贴） ──
              Transform.rotate(
                angle: .9 * math.pi / 180,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF223A29),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocale.value == AppLocale.en
                            ? 'READING RANGE'
                            : '经文范围',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: Color(0x99F3EBD8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        d.reading,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: Color(0xFFF3EBD8),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _StampLine(text: d.stamp, dark: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Divider(color: const Color(0x332A2313), height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '资料更新于 ${d.updatedLabel}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0x992A2313),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _openSource(d.sourceUrl),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF8A5A16),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 36),
                    ),
                    child: const Text('查看原页', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Text(
            '仅摘录「今天的主题」与「经文范围」两行，全文与原页版权归推喇奴书房《活泼的生命》所有。',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.65,
              color: AppColors.creamFaint,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openSource(String url) async {
    if (url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

/// 贴纸上的日期行（虚线夹日期）
class _StampLine extends StatelessWidget {
  final String text;
  final bool dark;

  const _StampLine({required this.text, required this.dark});

  @override
  Widget build(BuildContext context) {
    final color = dark ? const Color(0x8CF3EBD8) : const Color(0x992A2313);
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: color.withValues(alpha: .45),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              letterSpacing: .4,
              color: color,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: color.withValues(alpha: .45),
          ),
        ),
      ],
    );
  }
}
