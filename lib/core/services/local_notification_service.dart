import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  int _counter = 0;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'vyooo_high_importance',
    'Vyooo Alerts',
    description: 'Realtime alerts for likes, comments, follows and more.',
    importance: Importance.max,
  );

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(
      settings: settings,
    );
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_channel);
    await androidImpl?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _initialized = true;
  }

  Future<void> show({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    await init();
    final id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 20) +
        (_counter++ % 1024);
    const android = AndroidNotificationDetails(
      'vyooo_high_importance',
      'Vyooo Alerts',
      channelDescription: 'Realtime alerts for likes, comments, follows and more.',
      importance: Importance.max,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: android,
        iOS: ios,
      ),
    );
  }
}
