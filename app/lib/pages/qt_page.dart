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

  // 只走自己域名的 /api/data：静态路径会被 Cloudflare 托管验证拦成 403，
  // 但走 Worker 路由的 /api/* 不受验证影响（网页与 App 同源，免 CORS）。
  // 不用 jsDelivr / raw：国内网络这两个域名会被重置或长时间打不开。
  static const _sources = [
    'https://www.zhuzhouchurch.com/api/data?f=qt-data.json',
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
  RpgData? _rpg;
  int _rpgIndex = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([QtData.fetch(), RpgData.fetch()]);
    if (!mounted) return;
    setState(() {
      _data = results[0] as QtData?;
      _rpg = results[1] as RpgData?;
      _rpgIndex = 0;
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
          if (!_loading && _rpg != null) _rpgCard(_rpg!),
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
                ? 'The Living Life today’s theme and reading in two stickers, then today’s RPG daily-verse cards — scripture and prayer.'
                : '《活泼的生命》今日主题与经文范围两枚贴纸，再加 RPG 每日经文两张卡片：经文与默想祷告。',
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

  // ── 第三块：RPG 每日经文卡片（只放图，保留最近 7 天） ──
  Widget _rpgCard(RpgData d) {
    final isEn = AppLocale.value == AppLocale.en;
    final item = d.items[_rpgIndex.clamp(0, d.items.length - 1)];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EAD3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2D3B2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isEn ? 'RPG · DAILY VERSE' : 'RPG · 每日经文',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: Color(0xFF8A4B1F),
                  ),
                ),
              ),
              if (d.updatedLabel.isNotEmpty)
                Text(
                  '${isEn ? 'Updated ' : '更新 '}${d.updatedLabel}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0x992A2313),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (item.hasVerse) ...[
            _rpgTag(isEn ? 'SCRIPTURE' : '经文'),
            const SizedBox(height: 7),
            _rpgShot(item.verseFor(d.base), 890 / 501, isEn),
            const SizedBox(height: 14),
            _rpgTag(isEn ? 'REFLECTION · PRAYER' : '默想 · 祷告'),
            const SizedBox(height: 7),
          ],
          _rpgShot(item.prayerFor(d.base), 1136 / 774, isEn),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  item.stamp,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0x992A2313),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _openSource(item.sourceUrl),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF8A5A16),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                ),
                child: Text(
                  isEn ? 'View original' : '查看原页',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: d.items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _rpgThumb(d, i),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isEn
                ? 'Two card images per day: scripture on top, reflection and prayer below. Images from RPG Revival Prayer Movement “RPG Daily Verse” (365 Revival Prayer Cards). Original images only, no reprint; all rights belong to the publisher.'
                : '每天两张卡片：上面是当日经文，下面是默想与祷告。原图取自 RPG 復興禱告總動員「每日經文」（365 復興禱告卡），只显示原图、不作转载，版权归原作者所有。',
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: AppColors.creamFaint,
            ),
          ),
        ],
      ),
    );
  }

  /// 小标签：经文 / 默想 · 祷告
  Widget _rpgTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x29B08A2A),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          letterSpacing: 1.2,
          color: Color(0xFF6A4A12),
        ),
      ),
    );
  }

  /// 一张卡片图，按原图比例留白，加载失败给一段提示
  Widget _rpgShot(String url, double ratio, bool isEn) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        color: const Color(0xFFFFFDF8),
        child: AspectRatio(
          aspectRatio: ratio,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (context, error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  isEn
                      ? 'This card image is unavailable right now. Tap “View original” to open the source page.'
                      : '暂时取不到这张卡片，点右下角「查看原页」到源站看。',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0x992A2313),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rpgThumb(RpgData d, int i) {
    final it = d.items[i];
    final selected = i == _rpgIndex;
    return GestureDetector(
      onTap: () => setState(() => _rpgIndex = i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 92,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF8),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? const Color(0xFFE0AE33) : const Color(0x33E2D3B2),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                child: Image.network(
                  it.prayerFor(d.base),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stack) => const Center(
                    child: Icon(Icons.image_not_supported_outlined, size: 18),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                it.dateLabel.replaceFirst(RegExp(r'^\d{4}年'), ''),
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0x992A2313),
                ),
              ),
            ),
          ],
        ),
      ),
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

/// RPG 每日经文的两张卡片：经文卡 + 默想祷告卡，只有图、日期与原页链接，不含 OCR 文字
class RpgItem {
  final String date;
  final String dateLabel;
  final String weekday;
  final String verseImage;
  final String verseImageUrl;
  final String prayerImage;
  final String prayerImageUrl;
  final String sourceUrl;
  final String title;

  const RpgItem({
    required this.date,
    required this.dateLabel,
    required this.weekday,
    required this.verseImage,
    required this.verseImageUrl,
    required this.prayerImage,
    required this.prayerImageUrl,
    required this.sourceUrl,
    required this.title,
  });

  factory RpgItem.fromJson(Map<String, dynamic> j) {
    // 兼容旧清单：只有 image / imageUrl（那张是默想祷告卡）
    final legacyImage = (j['image'] ?? '').toString();
    final legacyUrl = (j['imageUrl'] ?? '').toString();
    return RpgItem(
      date: (j['date'] ?? '').toString(),
      dateLabel: (j['dateLabel'] ?? j['date'] ?? '').toString(),
      weekday: (j['weekday'] ?? '').toString(),
      verseImage: (j['verseImage'] ?? '').toString(),
      verseImageUrl: (j['verseImageUrl'] ?? '').toString(),
      prayerImage: (j['prayerImage'] ?? legacyImage).toString(),
      prayerImageUrl: (j['prayerImageUrl'] ?? legacyUrl).toString(),
      sourceUrl: (j['sourceUrl'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
    );
  }

  /// 卡片下的日期行：2026年11月8日 · 星期日
  String get stamp => weekday.isEmpty ? dateLabel : '$dateLabel · $weekday';

  bool get hasVerse => verseImage.isNotEmpty || verseImageUrl.isNotEmpty;

  /// 优先清单里的绝对地址；缺失时按读取源拼相对路径
  String verseFor(String base) =>
      _abs(verseImageUrl.isNotEmpty ? verseImageUrl : '${base}images/rpg/$verseImage');

  String prayerFor(String base) =>
      _abs(prayerImageUrl.isNotEmpty ? prayerImageUrl : '${base}images/rpg/$prayerImage');

  /// 清单里的图片地址可能还写着旧基址（github.io / jsDelivr），
  /// 统一截到 images/ 之后的相对路径，改走 /api/asset 取图。
  static const _assetBase = 'https://www.zhuzhouchurch.com/api/asset?p=';

  static String _abs(String url) {
    final i = url.indexOf('images/');
    if (i >= 0) return _assetBase + url.substring(i);
    final j = url.indexOf('mp3/');
    if (j >= 0) return _assetBase + url.substring(j);
    return url;
  }
}

/// RPG 每日经文清单：与网站同源，读 rpg-data.json（Actions 每日抓取、只留 7 天）
class RpgData {
  final String updatedLabel;
  final List<RpgItem> items;
  final String base;

  const RpgData({
    required this.updatedLabel,
    required this.items,
    required this.base,
  });

  // 同 QtData：只走自己域名的 /api/data
  static const _sources = [
    'https://www.zhuzhouchurch.com/api/data?f=rpg-data.json',
  ];

  /// 依次尝试各源，全部失败或清单为空返回 null
  static Future<RpgData?> fetch() async {
    for (final url in _sources) {
      try {
        final res = await http
            .get(Uri.parse(url), headers: const {'cache-control': 'no-store'})
            .timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) continue;
        final j = jsonDecode(res.body);
        if (j is! Map<String, dynamic>) continue;
        final raw = j['items'];
        if (raw is! List) continue;
        final items = raw
            .whereType<Map<String, dynamic>>()
            .map(RpgItem.fromJson)
            .where((e) => e.prayerImage.isNotEmpty || e.prayerImageUrl.isNotEmpty)
            .toList();
        if (items.isEmpty) continue;
        final base = url.substring(0, url.lastIndexOf('/') + 1);
        return RpgData(
          updatedLabel: (j['updatedLabel'] ?? j['updated'] ?? '').toString(),
          items: items,
          base: base,
        );
      } catch (_) {}
    }
    return null;
  }
}
