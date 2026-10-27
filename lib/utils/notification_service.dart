// lib/utils/notification_service.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/player_progress.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (kIsWeb) return; // Web safe guard
    if (_initialized) return;
    
    tz.initializeTimeZones();
    final tzName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzName));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(settings: settings);

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(const AndroidNotificationChannel(
      'recap', 'Weekly Recap',
      description: 'A gentle summary of your week.',
      importance: Importance.defaultImportance,
    ));
    await androidImpl?.createNotificationChannel(const AndroidNotificationChannel(
      'welcome', 'Welcome Back',
      description: 'A one-time nudge if you have been away.',
      importance: Importance.low,
    ));

    _initialized = true;
  }

  static Future<void> requestPermission() async {
    if (kIsWeb) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: false, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }

  static Future<void> scheduleWeeklyRecap(PlayerProgress p) async {
    if (kIsWeb) return; // Web safe guard
    await _plugin.cancel(id: 10);
    if (!p.remindersEnabled) return;

    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, 18, 0);
    while (next.weekday != DateTime.sunday || next.isBefore(now)) {
      next = next.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: 10,
      title: 'Your week with ${p.dinoName ?? "Rex"}',
      body: 'Tap to see your progress. No rush — whenever you want. 🍫',
      scheduledDate: next,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails('recap', 'Weekly Recap'),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  static Future<void> scheduleWelcomeBack(PlayerProgress p) async {
    if (kIsWeb) return; // Web safe guard
    await _plugin.cancel(id: 11);
    if (!p.remindersEnabled) return;
    if (p.lastPlayedAt == null) return;

    final lastPlayed = DateTime.tryParse(p.lastPlayedAt!);
    if (lastPlayed == null) return;

    final fireAt = lastPlayed.add(const Duration(days: 5));
    if (fireAt.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      id: 11,
      title: "Whenever you're ready",
      body: 'The chocolates are still here 🍫',
      scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails('welcome', 'Welcome Back'),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}