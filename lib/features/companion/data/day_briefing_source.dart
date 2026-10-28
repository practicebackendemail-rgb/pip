import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/email_service.dart';
import '../../../core/services/task_provider.dart';
import '../../../core/services/tools/calendar_tools.dart';
import '../../../core/services/tools/schedule_store.dart';
import '../../notifications/data/notification_inbox.dart';
import '../domain/day_briefing.dart';

/// Gathers today's data for the briefing. Every source is optional: no
/// calendar permission, no email account or no notification access just
/// leaves that section out, and never blocks the rest.
class DayBriefingSource {
  final TaskProvider tasks;
  final EmailService email;
  final DeviceCalendarService calendar;

  DayBriefingSource({required this.tasks, required this.email, DeviceCalendarService? calendar})
      : calendar = calendar ?? DeviceCalendarService();

  /// Everything except email (fast, all on-device).
  Future<DayBriefing> local({DateTime? now}) async {
    final t = now ?? DateTime.now();
    final (schedule, events, notifications) = await (
      _safe(ScheduleStore.upcoming, const <ScheduledItem>[]),
      _safe(() => _events(t), const <BriefEvent>[]),
      _safe(() => NotificationInbox.instance.briefingLines(max: 3), const <String>[]),
    ).wait;
    return DayBriefing.build(
      now: t,
      tasks: tasks.allTasks,
      schedule: schedule,
      events: events,
      notifications: notifications,
    );
  }

  /// Email needs the network, so it's added after the rest is on screen.
  Future<List<String>> emailLines() => _safe(email.fetchUnreadSummaries, const <String>[]);

  Future<List<BriefEvent>> _events(DateTime now) async {
    // Only read the calendar if already allowed: the briefing never pops a
    // permission prompt.
    if (await calendar.checkPermission() != CalendarPermissionStatus.granted) return const [];
    final start = DateTime(now.year, now.month, now.day);
    final events = await calendar.getEvents(start, start.add(const Duration(days: 1)));
    return [for (final e in events) BriefEvent(title: e.title, start: e.startDate, end: e.endDate, allDay: e.isAllDay)];
  }

  static Future<T> _safe<T>(Future<T> Function() load, T fallback) async {
    try {
      return await load();
    } catch (e) {
      debugPrint('Briefing source failed (skipped): $e');
      return fallback;
    }
  }
}
