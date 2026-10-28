import 'activity_entry.dart';

/// Turns a successful tool run into an activity entry, or null when the tool
/// only looked something up (lists, searches, the time) or failed.
/// Pure, so the log's wording and undo support are unit-tested.
ActivityEntry? describeToolActivity(
  String tool,
  Map<String, dynamic> args,
  Map<String, dynamic> result, {
  DateTime? now,
}) {
  if (result.containsKey('error')) return null;
  final at = now ?? DateTime.now();
  final id = '${at.microsecondsSinceEpoch}-$tool';
  String s(Object? v) => '${v ?? ''}'.trim();
  ActivityEntry entry(ActivityKind kind, String title, {String? detail, ActivityUndo? undo}) =>
      ActivityEntry(id: id, kind: kind, title: title, detail: detail, at: at, undo: undo);
  ActivityUndo? schedule() => result['id'] == null ? null : ActivityUndo('schedule', s(result['id']));

  switch (tool) {
    case 'set_alarm':
      final when = DateTime.tryParse(s(result['time']));
      final repeat = (result['repeat'] as List?)?.isNotEmpty == true ? ', repeating' : '';
      return entry(ActivityKind.alarm, 'Set alarm ${when == null ? '' : _clock(when)}$repeat'.trim(),
          detail: s(result['label']).isEmpty ? null : s(result['label']), undo: schedule());
    case 'set_reminder':
      final when = DateTime.tryParse(s(result['scheduled_time']));
      return entry(ActivityKind.reminder, "Reminder: ${s(result['title'])}",
          detail: when == null ? null : 'for ${_clock(when)}', undo: schedule());
    case 'cancel_reminder':
      return entry(ActivityKind.reminder, "Cancelled '${s(result['title'])}'");
    case 'create_task':
      return entry(ActivityKind.task, "Added task '${s(result['title'])}'",
          detail: s(result['project']).isEmpty ? null : s(result['project']),
          undo: result['id'] == null ? null : ActivityUndo('task', s(result['id'])));
    case 'complete_task':
      return entry(ActivityKind.task, 'Completed a task', detail: s(args['query']));
    case 'create_calendar_event':
      return entry(ActivityKind.calendar, "Added '${s(result['title'])}' to your calendar");
    case 'send_email':
      return entry(ActivityKind.email, 'Sent email to ${s(result['recipient'])}', detail: s(result['subject']));
    case 'draft_email':
      return entry(ActivityKind.email, 'Drafted an email to ${s(args['recipient'])}', detail: 'Not sent');
    case 'save_note':
      return entry(ActivityKind.note, 'Saved a note', detail: s(args['content']));
    case 'learn_user_fact':
    case 'add_assistant_rule':
      return entry(ActivityKind.memory, 'Remembered something about you', detail: s(args['value'] ?? args['instruction']));
  }
  return null; // read-only tools: list_*, search_*, get_*, read_*
}

String _clock(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute == 0 ? '' : ':${d.minute.toString().padLeft(2, '0')}';
  return '$h$m ${d.hour < 12 ? 'AM' : 'PM'}';
}
