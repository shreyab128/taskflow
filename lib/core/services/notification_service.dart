
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (kIsWeb || _initialized) return;

    tz.initializeTimeZones();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(settings: settings);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await android?.requestNotificationsPermission();

    _initialized = true;
  }

  static Future<void> schedule({
    required String taskId,
    required String title,
    String? body,
    required DateTime reminderAt,
  }) async {
    if (kIsWeb) return;

    await initialize();

    if (!reminderAt.isAfter(DateTime.now())) return;

    final notificationId = taskId.hashCode & 0x7fffffff;

    await _plugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: body ?? 'Your task is due.',
      scheduledDate: tz.TZDateTime.from(reminderAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Task reminders',
          channelDescription: 'Notifications for your scheduled tasks',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> cancel(String taskId) async {
    if (kIsWeb) return;

    await initialize();

    await _plugin.cancel(
      id: taskId.hashCode & 0x7fffffff,
    );
  }
}
