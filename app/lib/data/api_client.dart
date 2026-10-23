import 'dart:convert';
import 'package:http/http.dart' as http;

/// 留言 / 祷告墙 API（直连 zhuzhouchurch.com）
class ApiClient {
  static const base = 'https://zhuzhouchurch.com/api';

  static Future<List<Map<String, dynamic>>> fetchComments(
      {String? page}) async {
    final uri = page == null
        ? Uri.parse('$base/comments')
        : Uri.parse('$base/comments').replace(queryParameters: {'page': page});
    try {
      final res =
          await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['ok'] == true) {
          return (data['items'] as List?)
                  ?.map((e) => (e as Map).cast<String, dynamic>())
                  .toList() ??
              [];
        }
      }
    } catch (_) {}
    return [];
  }

  /// 提交留言；返回 null=成功，否则返回错误提示
  static Future<String?> postComment({
    required String name,
    required String content,
    String? page,
  }) async {
    final body = <String, dynamic>{'name': name, 'content': content};
    if (page != null) body['page'] = page;
    try {
      final res = await http
          .post(Uri.parse('$base/comments'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['error'] != null) return data['error'].toString();
        if (data['ok'] == true) return null;
        return data['message']?.toString() ?? '提交失败，请稍后再试';
      }
      return '网络错误（${res.statusCode}），请稍后再试';
    } catch (_) {
      return '网络连接失败，请检查网络';
    }
  }

  static Future<List<Map<String, dynamic>>> fetchPrayers() async {
    try {
      final res =
          await http.get(Uri.parse('$base/prayers')).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['ok'] == true) {
          return (data['items'] as List?)
                  ?.map((e) => (e as Map).cast<String, dynamic>())
                  .toList() ??
              [];
        }
      }
    } catch (_) {}
    return [];
  }

  static Future<String?> postPrayer({
    required String name,
    required String content,
  }) async {
    try {
      final res = await http
          .post(Uri.parse('$base/prayers'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'name': name, 'content': content}))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['error'] != null) return data['error'].toString();
        if (data['ok'] == true) return null;
        return data['message']?.toString() ?? '提交失败，请稍后再试';
      }
      return '网络错误（${res.statusCode}），请稍后再试';
    } catch (_) {
      return '网络连接失败，请检查网络';
    }
  }
}
