import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 通知栏级系统推送：每次启动从 notice.json 拉取消息并以系统通知展示
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _inited = false;

  static const _channelId = 'mustardseed_notice';
  static const _channelName = '教会消息';
  static const _channelDesc = '芥菜种教会推送消息';

  /// 初始化通知插件并请求权限（Android 13+ 需要 POST_NOTIFICATIONS）
  Future<void> init() async {
    if (_inited) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
    _inited = true;
  }

  /// 请求系统通知权限（Android 首次弹窗）
  Future<bool> requestPermission() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } catch (_) {}
    return false;
  }

  /// 展示一条系统通知栏通知（同一 id 每次覆盖刷新）
  Future<void> show(String title, String body) async {
    if (!_inited) await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    try {
      await _plugin.show(
        id: 1001,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (_) {}
  }
}
