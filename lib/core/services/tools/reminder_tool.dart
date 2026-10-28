import '../../domain/pip_tool.dart';
import '../pip_notification_service.dart';
import 'schedule_store.dart';

/// Reminders: a notification at a given time that survives the app closing
/// (Android and iOS). On Windows it is an in-app timer while Pip runs.
class ReminderTool extends PipTool {
  const ReminderTool()
      : super(
          name: 'set_reminder',
          description: 'Remind the user about something at a time. Give "time" for a clock time '
              '(e.g. "7:30 pm"), or "at_iso" for a full date and time, or "delay_seconds" for "in N minutes". '
              'Add "repeat" for a recurring reminder.',
          confirmationLevel: ToolConfirmationLevel.level2ReportAfter,
          parameters: const [
            ToolParameterSpec(
                name: 'title',
                type: 'string',
                description: 'What to remind about. Leave out if the user did not say ("remind me in 20 min").',
                isRequired: false),
            ToolParameterSpec(
                name: 'time', type: 'string', description: 'Clock time today/tomorrow, e.g. "16:00" or "7am".', isRequired: false),
            ToolParameterSpec(
                name: 'at_iso', type: 'string', description: 'Exact local date-time, ISO-8601.', isRequired: false),
            ToolParameterSpec(
                name: 'delay_seconds', type: 'integer', description: 'Seconds from now.', isRequired: false),
            ToolParameterSpec(
                name: 'repeat',
                type: 'string',
                description: 'Optional repeat: "weekdays", "weekends", "daily", or days like "mon,wed,fri".',
                isRequired: false),
          ],
        );

  /// Sets up notifications and asks for permission to show them.
  static Future<void> ensureInitialized() async {
    await PipNotificationService.init();
    await PipNotificationService.requestPermissions();
  }

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final given = (args['title'] as String?)?.trim();
    final title = given == null || given.isEmpty ? 'Reminder' : given;
    final days = parseDays(args['repeat'] as String?);
    final at = resolveWhen(
      atIso: args['at_iso'] as String?,
      time: args['time'] as String?,
      delaySeconds: (args['delay_seconds'] as num?)?.toInt(),
    );
    if (at == null) return {'error': 'I need a time, like "7:30 pm" or "in 10 minutes".'};
    if (days.isEmpty && !at.isAfter(DateTime.now())) return {'error': 'That time has already passed.'};

    try {
      final item = ScheduledItem(id: newScheduleId(), kind: ScheduledItem.reminder, title: title, at: at, days: days);
      final persistence = await PipNotificationService.schedule(item);
      await ScheduleStore.add(item);
      return {
        'status': 'scheduled',
        'id': item.id,
        'title': title,
        'scheduled_time': (item.nextOccurrence() ?? at).toIso8601String(),
        if (days.isNotEmpty) 'repeat_days': days,
        'persistence': persistence,
        if (persistence == 'while_app_open') 'note': 'On Windows this works only while Pip is running.',
      };
    } catch (e) {
      return {'error': 'Failed to schedule reminder: $e'};
    }
  }
}
