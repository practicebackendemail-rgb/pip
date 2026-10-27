import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../domain/pip_tool.dart';

/// Reminders & Timers Tool (Step 5.4a)
class ReminderTool extends PipTool {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  const ReminderTool()
      : super(
          name: 'set_reminder',
          description: 'Set a timed reminder or alert notification.',
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

  static Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );
      await _notificationsPlugin.initialize(settings: initSettings);
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
      await _ensureInitialized();
      final notifId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      const androidDetails = AndroidNotificationDetails(
        'pip_reminders',
        'Pip Reminders',
        importance: Importance.max,
        priority: Priority.high,
      );
      const notificationDetails = NotificationDetails(android: androidDetails);

      Future.delayed(Duration(seconds: delay), () {
        _notificationsPlugin.show(
          id: notifId,
          title: 'Pip Alert',
          body: title,
          notificationDetails: notificationDetails,
        );
      });

      return {
        'status': 'scheduled',
        'title': title,
        'trigger_in_seconds': delay,
      };
    } catch (e) {
      return {'error': 'Failed to schedule reminder: $e'};
    }
  }
}
