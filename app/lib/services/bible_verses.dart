import 'dart:convert';

import 'package:http/http.dart' as http;

/// 一节经文
class BibleVerse {
  final int n;
  final String text;
  const BibleVerse({required this.n, required this.text});
}

/// 从站点经文库取当日经文正文。
/// 经文库：/bible/ckjv/<书卷号>.json（《中文英王钦定本》，CC BY-SA 3.0）。
/// 走 /api/asset 而不是静态路径——静态路径会被 Cloudflare 托管验证拦成 403。
class BibleVerses {
  static const _base = 'https://www.zhuzhouchurch.com/api/asset?p=bible/ckjv/';
  static Map<String, String>? _index;
  static final Map<String, Map<String, dynamic>> _books = {};

  static Future<Map<String, String>?> _loadIndex() async {
    if (_index != null) return _index;
    try {
      final r = await http.get(Uri.parse('${_base}index.json')).timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final books = j['books'] as Map<String, dynamic>? ?? {};
      final map = <String, String>{};
      books.forEach((k, v) {
        final file = (v as Map<String, dynamic>)['file'];
        if (file is String) map[k] = file;
      });
      if (map.isEmpty) return null;
      _index = map;
      return map;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _loadBook(String file) async {
    if (_books.containsKey(file)) return _books[file];
    try {
      final r = await http.get(Uri.parse('$_base$file')).timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      _books[file] = j;
      return j;
    } catch (_) {
      return null;
    }
  }

  /// 解析「哥林多后书1：15～24」这类经文范围
  static (String, int, int, int)? parseReading(String reading) {
    final t = reading.replaceAllMapped(
        RegExp(r'[０-９]'), (m) => String.fromCharCode(m.group(0)!.runes.first - 0xFEE0));
    final m = RegExp(r'^([^0-9]+)(\d+)[:：](\d+)(?:\s*[～~\-－—]\s*(\d+))?').firstMatch(t);
    if (m == null) return null;
    final book = m.group(1)!.replaceAll(RegExp(r'\s+'), '');
    final ch = int.parse(m.group(2)!);
    final start = int.parse(m.group(3)!);
    final end = m.group(4) != null ? int.parse(m.group(4)!) : start;
    return (book, ch, start, end < start ? start : end);
  }

  /// 取当日经文；取不到返回 null
  static Future<List<BibleVerse>?> fetchFor(String reading) async {
    final p = parseReading(reading);
    if (p == null) return null;
    final index = await _loadIndex();
    if (index == null) return null;
    final file = index[p.$1];
    if (file == null) return null;
    final book = await _loadBook(file);
    if (book == null) return null;
    final ch = book['${p.$2}'] as Map<String, dynamic>?;
    if (ch == null) return null;
    final out = <BibleVerse>[];
    for (var v = p.$3; v <= p.$4; v++) {
      final t = ch['$v'];
      if (t is String) out.add(BibleVerse(n: v, text: t));
    }
    return out.isEmpty ? null : out;
  }
}
