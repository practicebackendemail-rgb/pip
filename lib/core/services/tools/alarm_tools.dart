import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import '../../domain/pip_tool.dart';
import 'reminder_tool.dart';
import 'schedule_store.dart';

const _alarmExtra = 'android.intent.extra.alarm';

/// Android's Calendar.SUNDAY = 1 … SATURDAY = 7; ours is Monday = 1 … Sunday = 7.
List<int> toAndroidDays(List<int> days) => [for (final d in days) d == 7 ? 1 : d + 1];

/// Sets a real alarm. On Android it goes into the phone's Clock app (rings,
/// snoozes, survives Do Not Disturb like any alarm). Elsewhere there is no
/// alarm API, so it falls back to a Pip notification and says so.
class SetAlarmTool extends PipTool {
  /// Test seam for launching the Android intent.
  final Future<void> Function(AndroidIntent intent) launch;

  SetAlarmTool({Future<void> Function(AndroidIntent intent)? launch})
      : launch = launch ?? ((i) => i.launch()),
        super(
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

  bool get _android => !kIsWeb && Platform.isAndroid;

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final time = (args['time'] as String?)?.trim() ?? '';
    final clock = parseClockTime(time);
    if (clock == null) return {'error': 'I need a clock time like "6:30am".'};
    final label = ((args['label'] as String?)?.trim().isNotEmpty ?? false) ? (args['label'] as String).trim() : 'Pip alarm';
    final days = parseDays(args['repeat'] as String?);
    final at = resolveWhen(time: time)!;
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000 % 0x7fffffff;

    if (_android) {
      try {
        await launch(AndroidIntent(
          action: 'android.intent.action.SET_ALARM',
          arguments: <String, dynamic>{
            '$_alarmExtra.HOUR': clock.$1,
            '$_alarmExtra.MINUTES': clock.$2,
            '$_alarmExtra.MESSAGE': label,
            '$_alarmExtra.SKIP_UI': true,
            if (days.isNotEmpty) '$_alarmExtra.DAYS': toAndroidDays(days),
          },
        ));
      } catch (e) {
        return {'error': "Couldn't open the Clock app to set the alarm: $e"};
      }
      await ScheduleStore.add(ScheduledItem(id: id, kind: 'alarm', title: label, at: at, days: days, inClockApp: true));
      return {'status': 'created', 'kind': 'alarm', 'id': id, 'label': label, 'time': at.toIso8601String(), 'repeat': days};
    }

    final persistence = await ReminderTool.scheduleNotification(id: id, title: '⏰ $label', at: at);
    await ScheduleStore.add(ScheduledItem(id: id, kind: 'alarm', title: label, at: at, days: days));
    return {
      'status': 'created',
      'kind': 'alarm',
      'id': id,
      'label': label,
      'time': at.toIso8601String(),
      'note': persistence == 'while_app_open'
          ? 'This device has no alarm clock API, so this is a Pip notification that works while Pip is running.'
          : 'This device has no alarm clock API, so this is a notification, not a ringing alarm.',
      if (days.isNotEmpty) 'repeat_note': 'Repeats are only supported for Clock-app alarms on Android.',
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
          {'id': i.id, 'kind': i.kind, 'title': i.title, 'time': i.at.toIso8601String(), if (i.repeats) 'repeat_days': i.days},
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
      // Android only lets the Clock app delete its alarms; this opens it on
      // the matching alarm for the user to dismiss.
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
    await ReminderTool.cancelNotification(item.id);
    await ScheduleStore.remove(item.id);
    return {'status': 'cancelled', 'title': item.title};
  }
}
