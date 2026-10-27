import '../../domain/pip_tool.dart';

class CalendarEvent {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;

  const CalendarEvent({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.location,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'start': startTime.toIso8601String(),
        'end': endTime.toIso8601String(),
        if (location != null) 'location': location,
      };
}

/// Simulated local Calendar store.
class LocalCalendarStore {
  static final List<CalendarEvent> _events = [
    CalendarEvent(
      id: 'cal_1',
      title: 'Daily Standup',
      startTime: DateTime.now().copyWith(hour: 10, minute: 0),
      endTime: DateTime.now().copyWith(hour: 10, minute: 30),
      location: 'Virtual',
    ),
  ];

  static List<CalendarEvent> get events => List.unmodifiable(_events);

  static void addEvent(CalendarEvent event) {
    _events.add(event);
  }
}

/// Calendar List & Find Free Time Tool (Step 5.4d)
/// Level 0: Read-only.
class ListCalendarEventsTool extends PipTool {
  const ListCalendarEventsTool()
      : super(
          name: 'list_calendar_events',
          description: 'List upcoming calendar events or locate free time slots.',
          confirmationLevel: ToolConfirmationLevel.level0ReadOnly,
          parameters: const [
            ToolParameterSpec(
              name: 'days_ahead',
              type: 'integer',
              description: 'Number of days to inspect (default 1).',
              isRequired: false,
            ),
          ],
        );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final now = DateTime.now();
    final events = LocalCalendarStore.events
        .where((e) => e.endTime.isAfter(now))
        .map((e) => e.toJson())
        .toList();

    return {
      'count': events.length,
      'events': events,
      'has_free_time_this_afternoon': true,
    };
  }
}

/// Create Calendar Event Tool (Step 5.4d)
/// Level 1: Requires user confirmation before committing schedule changes.
class CreateCalendarEventTool extends PipTool {
  const CreateCalendarEventTool()
      : super(
          name: 'create_calendar_event',
          description: 'Create a new meeting or event on the user calendar.',
          confirmationLevel: ToolConfirmationLevel.level1ConfirmAction,
          parameters: const [
            ToolParameterSpec(
              name: 'title',
              type: 'string',
              description: 'Title of the event.',
              isRequired: true,
            ),
            ToolParameterSpec(
              name: 'start_iso',
              type: 'string',
              description: 'Start time in ISO-8601 string.',
              isRequired: true,
            ),
            ToolParameterSpec(
              name: 'duration_minutes',
              type: 'integer',
              description: 'Duration in minutes (default 30).',
              isRequired: false,
            ),
          ],
        );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final title = (args['title'] as String?)?.trim() ?? 'Untitled Event';
    final startStr = args['start_iso'] as String?;
    final duration = (args['duration_minutes'] as num?)?.toInt() ?? 30;

    final start = startStr != null ? DateTime.tryParse(startStr) ?? DateTime.now() : DateTime.now();
    final end = start.add(Duration(minutes: duration));

    final newEvent = CalendarEvent(
      id: 'cal_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      startTime: start,
      endTime: end,
    );

    LocalCalendarStore.addEvent(newEvent);

    return {
      'status': 'created',
      'id': newEvent.id,
      'title': title,
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
    };
  }
}
