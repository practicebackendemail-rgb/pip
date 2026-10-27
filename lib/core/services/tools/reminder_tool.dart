import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../domain/pip_tool.dart';

/// Reminders & Timers Tool (Survives app lifecycle termination via zonedSchedule)
class ReminderTool extends PipTool {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  const ReminderTool()
      : super(
          name: 'set_reminder',
          description: 'Set a timed reminder or alert notification that persists across app close.',
          confirmationLevel: ToolConfirmationLevel.level2ReportAfter,
          parameters: const [
            ToolParameterSpec(
              name: 'title',
              type: 'string',
              description: 'The title of the reminder alert.',
              isRequired: true,
            ),
            ToolParameterSpec(
              name: 'delay_seconds',
              type: 'integer',
              description: 'Seconds from now to trigger the reminder (e.g. 60 for 1 minute).',
              isRequired: true,
            ),
          ],
        );

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

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _notificationsPlugin.initialize(settings: initSettings);

      if (!kIsWeb && Platform.isAndroid) {
        final androidImpl = _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidImpl?.requestNotificationsPermission();
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('Notification init warning: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final title = (args['title'] as String?)?.trim() ?? 'Reminder';
    final delay = (args['delay_seconds'] as num?)?.toInt() ?? 60;

    try {
      await ensureInitialized();
      final notifId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final scheduledDate = tz.TZDateTime.now(tz.local).add(Duration(seconds: delay));

      const androidDetails = AndroidNotificationDetails(
        'pip_reminders',
        'Pip Reminders',
        channelDescription: 'Scheduled reminders and alerts from Pip',
        importance: Importance.max,
        priority: Priority.high,
      );
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      // On Android and iOS, zonedSchedule survives app process termination
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
        await _notificationsPlugin.zonedSchedule(
          id: notifId,
          title: 'Pip Alert',
          body: title,
          scheduledDate: scheduledDate,
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );

        return {
          'status': 'scheduled',
          'id': notifId,
          'title': title,
          'trigger_in_seconds': delay,
          'scheduled_time': scheduledDate.toIso8601String(),
          'persistence': 'persistent_os_alarm',
        };
      } else {
        // Windows/Linux fallback timer with honest status disclosure
        Timer(Duration(seconds: delay), () {
          _notificationsPlugin.show(
            id: notifId,
            title: 'Pip Alert',
            body: title,
            notificationDetails: notificationDetails,
          );
        });

        return {
          'status': 'scheduled',
          'id': notifId,
          'title': title,
          'trigger_in_seconds': delay,
          'scheduled_time': scheduledDate.toIso8601String(),
          'persistence': 'in_app_timer',
          'note': 'works only while the app is open on desktop',
        };
      }
    } catch (e) {
      return {'error': 'Failed to schedule reminder: $e'};
    }
  }
}
