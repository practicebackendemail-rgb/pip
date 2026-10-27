import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'tools/schedule_store.dart';

/// How Pip's alarms and reminders look and sound.
class PipNotificationChannels {
  PipNotificationChannels._();

  static const String snoozeAction = 'snooze';
  static const String dismissAction = 'dismiss';
  static const int _flagInsistent = 4; // Android Notification.FLAG_INSISTENT: sound loops until handled

  static String title(ScheduledItem item) => item.isAlarm ? '⏰ ${item.title}' : 'Pip reminder';
  static String body(ScheduledItem item) => item.isAlarm ? 'Pip alarm' : item.title;

  static NotificationDetails detailsFor(ScheduledItem item) => item.isAlarm ? _alarm : _reminder;

  /// Rings through the alarm stream, loops until handled, and shows
  /// full-screen over the lock screen.
  static final NotificationDetails _alarm = NotificationDetails(
    android: AndroidNotificationDetails(
      'pip_alarms',
      'Pip Alarms',
      channelDescription: 'Alarms that ring until you snooze or dismiss them',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: NotificationVisibility.public,
      autoCancel: false,
      ongoing: true,
      additionalFlags: Int32List.fromList([_flagInsistent]),
      actions: const [
        AndroidNotificationAction(snoozeAction, 'Snooze 10 min'),
        AndroidNotificationAction(dismissAction, 'Dismiss'),
      ],
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    ),
    macOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
  );

  static const NotificationDetails _reminder = NotificationDetails(
    android: AndroidNotificationDetails(
      'pip_reminders',
      'Pip Reminders',
      channelDescription: 'Scheduled reminders from Pip',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      actions: [
        AndroidNotificationAction(snoozeAction, 'Snooze 10 min'),
        AndroidNotificationAction(dismissAction, 'Done'),
      ],
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    macOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
  );
}
