import 'package:flutter/foundation.dart';

/// 双语本地化：zh / en
class AppLocale {
  AppLocale._();
  static const zh = 'zh';
  static const en = 'en';
  static const supported = [zh, en];

  static final ValueNotifier<String> current = ValueNotifier(zh);

  static void set(String locale) {
    if (supported.contains(locale) && locale != current.value) {
      current.value = locale;
    }
  }

  static String get value => current.value;

  /// 从 {zh, en} 字典取当前语言；未命中回退 zh，仍无则返回空串
  static String t(Map? dict) {
    if (dict == null) return '';
    final m = dict.cast<String, dynamic>();
    final v = m[value];
    if (v is String && v.isNotEmpty) return v;
    final z = m[zh];
    return z is String ? z : '';
  }
}
