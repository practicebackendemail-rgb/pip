import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import '../../domain/pip_tool.dart';
import '../pip_notification_service.dart';
import 'schedule_store.dart';

const _alarmExtra = 'android.intent.extra.alarm';

/// Android's Calendar.SUNDAY = 1 … SATURDAY = 7; ours is Monday = 1 … Sunday = 7.
List<int> toAndroidDays(List<int> days) => [for (final d in days) d == 7 ? 1 : d + 1];

/// Sets an alarm that Pip owns: it rings through the alarm sound, shows
/// full-screen over the lock screen, repeats on chosen days, and appears on
/// the Alarms & reminders screen where it can be edited or switched off.
class SetAlarmTool extends PipTool {
  const SetAlarmTool()
      : super(
          name: 'set_alarm',
          description: 'Set a wake-up style alarm that rings at a clock time, optionally repeating. '
              'Use set_reminder instead for a gentle notification.',
          confirmationLevel: ToolConfirmationLevel.level2ReportAfter,
          parameters: const [
            ToolParameterSpec(name: 'time', type: 'string', description: 'Clock time, e.g. "6:30am" or "07:00".'),
            ToolParameterSpec(name: 'label', type: 'string', description: 'Alarm label.', isRequired: false),
            ToolParameterSpec(
                name: 'repeat',
                type: 'string',
                description: 'Optional repeat: "weekdays", "weekends", "daily", or days like "mon,wed,fri".',
                isRequired: false),
          ],
        );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final time = (args['time'] as String?)?.trim() ?? '';
    final clock = parseClockTime(time);
    if (clock == null) return {'error': 'I need a clock time like "6:30am".'};
    final label = ((args['label'] as String?)?.trim().isNotEmpty ?? false) ? (args['label'] as String).trim() : 'Pip alarm';
    final days = parseDays(args['repeat'] as String?);
    final item = ScheduledItem(
      id: newScheduleId(),
      kind: ScheduledItem.alarm,
      title: label,
      at: nextClockTime(clock.$1, clock.$2),
      days: days,
    );
    final persistence = await PipNotificationService.schedule(item);
    await ScheduleStore.add(item);
    final permissions = await PipNotificationService.permissions();
    return {
      'status': 'created',
      'kind': 'alarm',
      'id': item.id,
      'label': label,
      'time': (item.nextOccurrence() ?? item.at).toIso8601String(),
      'repeat': days,
      if (persistence == 'while_app_open') 'note': 'On this device the alarm rings only while Pip is running.',
      if (!permissions.exactAlarms)
        'warning': 'Exact alarms are off for Pip, so it may ring a few minutes late. '
            'Turn on "Alarms & reminders" for Pip in system settings.',
    };
  }
}

/// Lists the alarms and reminders Pip scheduled.
class ListRemindersTool extends PipTool {
  const ListRemindersTool()
      : super(
          name: 'list_reminders',
          description: 'List upcoming alarms and reminders that Pip set.',
          confirmationLevel: ToolConfirmationLevel.level0ReadOnly,
          parameters: const [],
        );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final items = await ScheduleStore.upcoming();
    return {
      'count': items.length,
      'items': [
        for (final i in items)
          {
            'id': i.id,
            'kind': i.kind,
            'title': i.title,
            'time': (i.nextOccurrence() ?? i.at).toIso8601String(),
            if (i.repeats) 'repeat_days': i.days,
            if (!i.enabled) 'enabled': false,
          },
      ],
      'note': 'Only alarms and reminders created by Pip are listed.',
    };
  }
}

/// Cancels an alarm or reminder Pip set, matched by id or title words.
class CancelReminderTool extends PipTool {
  final Future<void> Function(AndroidIntent intent) launch;

  CancelReminderTool({Future<void> Function(AndroidIntent intent)? launch})
      : launch = launch ?? ((i) => i.launch()),
        super(
          name: 'cancel_reminder',
          description: 'Cancel an alarm or reminder Pip set, by id or by words from its title.',
          confirmationLevel: ToolConfirmationLevel.level1ConfirmAction,
          parameters: const [
            ToolParameterSpec(name: 'query', type: 'string', description: 'Id or title words, e.g. "gym".'),
          ],
        );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final matches = await ScheduleStore.find('${args['query'] ?? ''}');
    if (matches.isEmpty) return {'error': "I couldn't find an alarm or reminder like that."};
    if (matches.length > 1) {
      return {
        'error': 'More than one matches. Which one?',
        'matches': [for (final m in matches) {'id': m.id, 'title': m.title, 'time': m.at.toIso8601String()}],
      };
    }
    final item = matches.single;
    if (item.inClockApp && !kIsWeb && Platform.isAndroid) {
      // Alarms older versions put in the Clock app can only be deleted
      // there; this opens it on the matching alarm for the user to dismiss.
      try {
        await launch(AndroidIntent(
          action: 'android.intent.action.DISMISS_ALARM',
          arguments: <String, dynamic>{
            '$_alarmExtra.SEARCH_MODE': 'android.label',
            '$_alarmExtra.MESSAGE': item.title,
          },
        ));
      } catch (e) {
        return {'error': "Couldn't open the Clock app: $e"};
      }
      await ScheduleStore.remove(item.id);
      return {'status': 'cancel_requested', 'title': item.title, 'note': 'The Clock app opened to confirm removing it.'};
    }
    await PipNotificationService.cancel(item);
    await ScheduleStore.remove(item.id);
    return {'status': 'cancelled', 'title': item.title};
  }
}
