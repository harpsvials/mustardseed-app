import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

/// appdata.json 数据模型 + 加载器（内置 assets + GitHub 远程覆盖）
class AppData {
  final Map<String, dynamic> raw;
  final Map<String, dynamic> ui;
  final Map<String, dynamic> home;
  final Map<String, dynamic> nav;
  final Map<String, dynamic> footer;
  final List<Sermon> sermons;
  final List<Topic> topics;
  final List<Period> periods;
  final List<Section> about;
  final List<Section> privacy;
  final Map<String, dynamic> guestbook;
  final Map<String, dynamic> prayer;
  final Map<String, dynamic> testify;

  /// 原始章节元数据（hero 标题等）
  Map<String, dynamic> get sermonsMeta =>
      (raw['sermons'] as Map?)?.cast<String, dynamic>() ?? {};
  Map<String, dynamic> get discussionMeta =>
      (raw['discussion'] as Map?)?.cast<String, dynamic>() ?? {};
  Map<String, dynamic> get testimoniesMeta =>
      (raw['testimonies'] as Map?)?.cast<String, dynamic>() ?? {};

  AppData._(this.raw)
      : ui = (raw['ui'] as Map?)?.cast<String, dynamic>() ?? {},
        home = (raw['home'] as Map?)?.cast<String, dynamic>() ?? {},
        nav = (raw['nav'] as Map?)?.cast<String, dynamic>() ?? {},
        footer = (raw['footer'] as Map?)?.cast<String, dynamic>() ?? {},
        sermons = ((raw['sermons']?['list'] as List?) ?? [])
            .map((e) => Sermon.fromJson(e as Map<String, dynamic>))
            .toList(),
        topics = ((raw['discussion']?['topics'] as List?) ?? [])
            .map((e) => Topic.fromJson(e as Map<String, dynamic>))
            .toList(),
        periods = ((raw['testimonies']?['periods'] as List?) ?? [])
            .map((e) => Period.fromJson(e as Map<String, dynamic>))
            .toList(),
        about = ((raw['about']?['sections'] as List?) ?? [])
            .map((e) => Section.fromJson(e as Map<String, dynamic>))
            .toList(),
        privacy = ((raw['privacy']?['sections'] as List?) ?? [])
            .map((e) => Section.fromJson(e as Map<String, dynamic>))
            .toList(),
        guestbook = (raw['guestbook'] as Map?)?.cast<String, dynamic>() ?? {},
        prayer = (raw['prayer'] as Map?)?.cast<String, dynamic>() ?? {},
        testify = (raw['testify'] as Map?)?.cast<String, dynamic>() ?? {};

  static AppData fromJson(Map<String, dynamic> json) => AppData._(json);

  /// 剥离字符串中的 HTML 标签（如 <small>、<strong> 等），防止被当成文字显示
  static String clean(String s) => s.replaceAll(RegExp(r'<[^>]+>'), '');

  /// 容错转换：String → {zh,en} 同文；Map → cast；null/其他 → null
  static Map<String, dynamic>? strMap(dynamic v) {
    if (v == null) return null;
    if (v is Map) {
      return (v as Map).map<String, dynamic>((k, val) => MapEntry(
            k.toString(),
            val is String ? clean(val) : val,
          ));
    }
    if (v is String && v.isNotEmpty) return {'zh': clean(v), 'en': clean(v)};
    return null;
  }

  /// 合并 zh/en 双语字段（缺失一侧用另一侧补齐）
  static Map<String, dynamic>? biMap(Map? zh, Map? en, String key) {
    final zv = zh?[key];
    final ev = en?[key];
    if (zv is String && ev is String) return {'zh': zv, 'en': ev};
    return strMap(zv) ?? strMap(ev);
  }

  /// 从内置 assets 加载（同步基线）
  static Future<AppData> loadBuiltIn() async {
    final s = await rootBundle.loadString('assets/appdata.json');
    return AppData.fromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  /// 从 GitHub 拉取最新内容；失败返回 null（调用方回退内置）
  static Future<AppData?> fetchRemote() async {
    const sources = [
      'https://harpsvials.github.io/mustardseed-app/appdata/appdata.json',
      'https://raw.githubusercontent.com/harpsvials/mustardseed-app/main/appdata/appdata.json',
      'https://cdn.jsdelivr.net/gh/harpsvials/mustardseed-app@main/appdata/appdata.json',
    ];
    for (final url in sources) {
      try {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          return AppData.fromJson(
              jsonDecode(res.body) as Map<String, dynamic>);
        }
      } catch (_) {}
    }
    return null;
  }
}

class Sermon {
  final String id;
  final int no;
  final String slug;
  final Map<String, dynamic> title;
  final Map<String, dynamic>? verse;
  final Map<String, dynamic>? verseText;
  final Map<String, dynamic>? verseRef;
  final Map<String, dynamic>? summary;
  final List<String> tags;
  final List<Chapter> body;
  final Questions? questions;

  Sermon({
    required this.id,
    required this.no,
    required this.slug,
    required this.title,
    this.verse,
    this.verseText,
    this.verseRef,
    this.summary,
    required this.tags,
    required this.body,
    this.questions,
  });

  factory Sermon.fromJson(Map<String, dynamic> j) => Sermon(
        id: (j['id'] ?? '').toString(),
        no: (j['no'] is int) ? j['no'] as int : int.tryParse('${j['no']}') ?? 0,
        slug: (j['slug'] ?? '').toString(),
        title: AppData.strMap(j['title']) ?? {},
        verse: AppData.strMap(j['verse']),
        verseText: AppData.strMap(j['verseText']),
        verseRef: AppData.strMap(j['verseRef']),
        summary: AppData.strMap(j['summary']),
        tags: (j['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
        body: (j['body'] as List?)
                ?.map((e) => Chapter.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        questions: j['questions'] == null
            ? null
            : Questions.fromJson(j['questions'] as Map<String, dynamic>),
      );
}

class Chapter {
  final String id;
  final Map<String, dynamic>? title;
  final List<Block> blocks;

  Chapter({required this.id, this.title, required this.blocks});

  factory Chapter.fromJson(Map<String, dynamic> j) => Chapter(
        id: (j['id'] ?? '').toString(),
        title: AppData.strMap(j['title']),
        blocks: (j['blocks'] as List?)
                ?.map((e) => Block.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class Block {
  final String type; // p / verse / question
  final String? zh;
  final String? en;
  final Map<String, dynamic>? label; // verse 用 {zh,en}
  final Map<String, dynamic>? text; // verse 用 {zh,en}

  Block({required this.type, this.zh, this.en, this.label, this.text});

  factory Block.fromJson(Map<String, dynamic> j) {
    final t = (j['type'] ?? 'p').toString();
    if (t == 'verse') {
      final zh = (j['zh'] as Map?)?.cast<String, dynamic>();
      final en = (j['en'] as Map?)?.cast<String, dynamic>();
      return Block(
        type: t,
        label: AppData.biMap(zh, en, 'label'),
        text: AppData.biMap(zh, en, 'text'),
      );
    }
    return Block(
        type: t,
        zh: j['zh'] == null ? null : AppData.clean(j['zh'].toString()),
        en: j['en'] == null ? null : AppData.clean(j['en'].toString()));
  }
}

class Questions {
  final Map<String, dynamic>? tag;
  final Map<String, dynamic>? title;
  final Map<String, dynamic>? text;

  Questions({this.tag, this.title, this.text});

  factory Questions.fromJson(Map<String, dynamic> j) => Questions(
        tag: AppData.strMap(j['tag']),
        title: AppData.strMap(j['title']),
        text: AppData.strMap(j['text']),
      );
}

class Topic {
  final Map<String, dynamic> label;
  final Map<String, dynamic> q;
  final Map<String, dynamic>? prompt;

  Topic({required this.label, required this.q, this.prompt});

  factory Topic.fromJson(Map<String, dynamic> j) => Topic(
        label: AppData.strMap(j['label']) ?? {},
        q: AppData.strMap(j['q']) ?? {},
        prompt: AppData.strMap(j['prompt']),
      );
}

class Period {
  final String id;
  final Map<String, dynamic> period;
  final Map<String, dynamic>? sub;
  final List<Map<String, dynamic>> paras;

  Period({
    required this.id,
    required this.period,
    this.sub,
    required this.paras,
  });

  factory Period.fromJson(Map<String, dynamic> j) => Period(
        id: (j['id'] ?? '').toString(),
        period: AppData.strMap(j['period']) ?? {},
        sub: AppData.strMap(j['sub']),
        paras: (j['paras'] as List?)
                ?.map((e) => AppData.strMap(e) ?? <String, dynamic>{})
                .toList() ??
            [],
      );
}

class Section {
  final String id;
  final List<Map<String, dynamic>> blocks;

  Section({required this.id, required this.blocks});

  factory Section.fromJson(Map<String, dynamic> j) => Section(
        id: (j['id'] ?? '').toString(),
        blocks: (j['blocks'] as List?)
                ?.map((e) => AppData.strMap(e) ?? <String, dynamic>{})
                .toList() ??
            [],
      );
}
