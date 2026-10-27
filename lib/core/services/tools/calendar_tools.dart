import 'dart:io';
import 'package:device_calendar_plus/device_calendar_plus.dart';
import '../../domain/pip_tool.dart';

/// Platform-native Calendar Service backed by device_calendar_plus
class DeviceCalendarService {
  final DeviceCalendar _plugin;

  DeviceCalendarService({DeviceCalendar? plugin})
      : _plugin = plugin ?? DeviceCalendar();

  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  Future<CalendarPermissionStatus> checkPermission() async {
    if (!isSupported) return CalendarPermissionStatus.denied;
    return await _plugin.hasPermissions();
  }

  Future<CalendarPermissionStatus> requestPermission() async {
    if (!isSupported) return CalendarPermissionStatus.denied;
    return await _plugin.requestPermissions();
  }

  Future<List<Calendar>> getWritableCalendars() async {
    if (!isSupported) return [];
    final calendars = await _plugin.listCalendars();
    return calendars.where((c) => !c.readOnly).toList();
  }

  Future<List<Event>> getEvents(DateTime start, DateTime end) async {
    if (!isSupported) return [];
    return await _plugin.listEvents(start, end);
  }

  Future<String?> createEvent({
    required String title,
    required DateTime start,
    required DateTime end,
    String? calendarId,
  }) async {
    if (!isSupported) return null;
    String? targetCalId = calendarId;
    if (targetCalId == null) {
      final writable = await getWritableCalendars();
      if (writable.isEmpty) return null;
      final primary = writable.firstWhere((c) => c.isPrimary, orElse: () => writable.first);
      targetCalId = primary.id;
    }

    return await _plugin.createEvent(
      calendarId: targetCalId,
      title: title,
      startDate: start,
      endDate: end,
    );
  }
}

/// Calendar List & Find Free Time Tool
class ListCalendarEventsTool extends PipTool {
  final DeviceCalendarService calendarService;

  ListCalendarEventsTool({DeviceCalendarService? calendarService})
      : calendarService = calendarService ?? DeviceCalendarService(),
        super(
          name: 'list_calendar_events',
          description: 'List upcoming platform calendar events or locate free time slots.',
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
    if (!calendarService.isSupported) {
      return {'error': 'Calendar is not available on this platform'};
    }

    var perm = await calendarService.checkPermission();
    if (perm == CalendarPermissionStatus.notDetermined) {
      perm = await calendarService.requestPermission();
    }

    if (perm != CalendarPermissionStatus.granted && perm != CalendarPermissionStatus.writeOnly) {
      return {'error': 'Calendar permission was denied or restricted'};
    }

    final daysAhead = (args['days_ahead'] as num?)?.toInt() ?? 1;
    final now = DateTime.now();
    final end = now.add(Duration(days: daysAhead));

    try {
      final events = await calendarService.getEvents(now, end);
      final mapped = events.map((e) => {
        'id': e.eventId,
        'title': e.title,
        'start': e.startDate.toIso8601String(),
        'end': e.endDate.toIso8601String(),
        'isAllDay': e.isAllDay,
      }).toList();

      return {
        'count': mapped.length,
        'events': mapped,
        'has_free_time_this_afternoon': _computeHasFreeTimeAfternoon(events, now),
      };
    } catch (e) {
      return {'error': 'Failed to list platform calendar events: $e'};
    }
  }

  bool _computeHasFreeTimeAfternoon(List<Event> events, DateTime now) {
    final afternoonStart = DateTime(now.year, now.month, now.day, 13, 0);
    final afternoonEnd = DateTime(now.year, now.month, now.day, 17, 0);

    for (final e in events) {
      if (e.startDate.isBefore(afternoonEnd) && e.endDate.isAfter(afternoonStart)) {
        final durationMinutes = e.endDate.difference(e.startDate).inMinutes;
        if (durationMinutes > 180) return false;
      }
    }
    return true;
  }
}

/// Create Calendar Event Tool
class CreateCalendarEventTool extends PipTool {
  final DeviceCalendarService calendarService;

  CreateCalendarEventTool({DeviceCalendarService? calendarService})
      : calendarService = calendarService ?? DeviceCalendarService(),
        super(
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
    if (!calendarService.isSupported) {
      return {'error': 'Calendar is not available on this platform'};
    }

    var perm = await calendarService.checkPermission();
    if (perm == CalendarPermissionStatus.notDetermined) {
      perm = await calendarService.requestPermission();
    }

    if (perm != CalendarPermissionStatus.granted && perm != CalendarPermissionStatus.writeOnly) {
      return {'error': 'Calendar permission was denied or restricted'};
    }

    final title = (args['title'] as String?)?.trim() ?? 'Untitled Event';
    final startStr = args['start_iso'] as String?;
    final duration = (args['duration_minutes'] as num?)?.toInt() ?? 30;

    final start = startStr != null ? DateTime.tryParse(startStr) ?? DateTime.now() : DateTime.now();
    final end = start.add(Duration(minutes: duration));

    try {
      final eventId = await calendarService.createEvent(
        title: title,
        start: start,
        end: end,
      );

      if (eventId == null) {
        return {'error': 'No writable primary calendar found on device'};
      }

      return {
        'status': 'created',
        'id': eventId,
        'title': title,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      };
    } catch (e) {
      return {'error': 'Failed to create calendar event: $e'};
    }
  }
}
