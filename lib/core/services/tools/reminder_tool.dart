import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../domain/pip_tool.dart';
import 'schedule_store.dart';

/// Reminders: a notification at a given time that survives the app closing
/// (Android and iOS). On Windows it is an in-app timer while Pip runs.
class ReminderTool extends PipTool {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;
  static final Map<int, Timer> _desktopTimers = {};

  const ReminderTool()
      : super(
          name: 'set_reminder',
          description: 'Remind the user about something at a time. Give "time" for a clock time '
              '(e.g. "7:30 pm"), or "at_iso" for a full date and time, or "delay_seconds" for "in N minutes".',
          confirmationLevel: ToolConfirmationLevel.level2ReportAfter,
          parameters: const [
            ToolParameterSpec(name: 'title', type: 'string', description: 'What to remind about.', isRequired: true),
            ToolParameterSpec(
                name: 'time', type: 'string', description: 'Clock time today/tomorrow, e.g. "16:00" or "7am".', isRequired: false),
            ToolParameterSpec(
                name: 'at_iso', type: 'string', description: 'Exact local date-time, ISO-8601.', isRequired: false),
            ToolParameterSpec(
                name: 'delay_seconds', type: 'integer', description: 'Seconds from now.', isRequired: false),
          ],
        );

  static bool get _persistent => !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  static Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    try {
      tz.initializeTimeZones();
      try {
        final tzInfo = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
      } catch (e) {
        debugPrint('FlutterTimezone fallback to UTC: $e');
        tz.setLocalLocation(tz.getLocation('UTC'));
      }

      const darwin = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: darwin,
          macOS: darwin,
        ),
      );
      if (!kIsWeb && Platform.isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('Notification init warning: $e');
    }
  }

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'pip_reminders',
      'Pip Reminders',
      channelDescription: 'Scheduled reminders and alerts from Pip',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    macOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
  );

  /// Schedules a notification for [at]. Returns how long it will persist.
  static Future<String> scheduleNotification({required int id, required String title, required DateTime at}) async {
    await ensureInitialized();
    if (_persistent) {
      await _plugin.zonedSchedule(
        id: id,
        title: 'Pip',
        body: title,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return 'persistent';
    }
    _desktopTimers[id]?.cancel();
    _desktopTimers[id] = Timer(at.difference(DateTime.now()), () {
      _desktopTimers.remove(id);
      _plugin.show(id: id, title: 'Pip', body: title, notificationDetails: _details);
    });
    return 'while_app_open';
  }

  static Future<void> cancelNotification(int id) async {
    _desktopTimers.remove(id)?.cancel();
    try {
      await ensureInitialized();
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('Cancel notification $id failed: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final title = (args['title'] as String?)?.trim();
    final at = resolveWhen(
      atIso: args['at_iso'] as String?,
      time: args['time'] as String?,
      delaySeconds: (args['delay_seconds'] as num?)?.toInt(),
    );
    if (title == null || title.isEmpty) return {'error': 'What should I remind you about?'};
    if (at == null) return {'error': 'I need a time, like "7:30 pm" or "in 10 minutes".'};
    if (!at.isAfter(DateTime.now())) return {'error': 'That time has already passed.'};

    try {
      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000 % 0x7fffffff;
      final persistence = await scheduleNotification(id: id, title: title, at: at);
      await ScheduleStore.add(ScheduledItem(id: id, kind: 'reminder', title: title, at: at));
      return {
        'status': 'scheduled',
        'id': id,
        'title': title,
        'scheduled_time': at.toIso8601String(),
        'persistence': persistence,
        if (persistence == 'while_app_open') 'note': 'On Windows this works only while Pip is running.',
      };
    } catch (e) {
      return {'error': 'Failed to schedule reminder: $e'};
    }
  }
}
