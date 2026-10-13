import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/database.dart';

/// Notifications locales des rappels de tâches. ID de notification = ID de tâche.
class Reminders {
  Reminders._(this._plugin);

  /// Implémentation sans effet (tests, plateformes non supportées).
  factory Reminders.noop() = _NoopReminders;

  final FlutterLocalNotificationsPlugin? _plugin;
  bool _exact = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Rappels',
      channelDescription: 'Rappels des tâches',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static Future<Reminders> init() async {
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Fuseau inconnu : on reste en UTC.
    }
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    return Reminders._(plugin);
  }

  /// Demandé au premier rappel programmé, pas au lancement.
  Future<void> requestPermissions() async {
    final android = _plugin!.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
      _exact = await android.canScheduleExactNotifications() ?? false;
      if (!_exact) {
        await android.requestExactAlarmsPermission();
        _exact = await android.canScheduleExactNotifications() ?? false;
      }
    }
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Programme (ou annule) le rappel d'une tâche selon son état.
  Future<void> sync(Task task) async {
    await cancel(task.id);
    final at = task.reminderAt;
    if (task.isDone || at == null || !at.isAfter(DateTime.now())) return;
    await requestPermissions();
    await _plugin!.zonedSchedule(
      id: task.id,
      title: 'Rappel',
      body: task.title,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: _details,
      androidScheduleMode: _exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancel(int taskId) => _plugin!.cancel(id: taskId);

  /// Au démarrage : reprogramme tous les rappels à venir.
  Future<void> resyncAll(List<Task> tasks) async {
    await _plugin!.cancelAll();
    for (final task in tasks) {
      final at = task.reminderAt;
      if (!task.isDone && at != null && at.isAfter(DateTime.now())) {
        await sync(task);
      }
    }
  }
}

class _NoopReminders extends Reminders {
  _NoopReminders() : super._(null);
  @override
  Future<void> requestPermissions() async {}
  @override
  Future<void> sync(Task task) async {}
  @override
  Future<void> cancel(int taskId) async {}
  @override
  Future<void> resyncAll(List<Task> tasks) async {}
}
