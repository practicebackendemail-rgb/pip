import 'package:equatable/equatable.dart';
import '../../../core/services/tools/schedule_store.dart';
import '../../../models/task_model.dart';

enum TimelineKind { alarm, reminder, event }

/// Something at a time today: an alarm, a reminder or a calendar event.
class TimelineItem extends Equatable {
  final DateTime at;
  final TimelineKind kind;
  final String title;
  final Duration? length;
  final bool isPast;

  const TimelineItem({required this.at, required this.kind, required this.title, this.length, this.isPast = false});

  @override
  List<Object?> get props => [at, kind, title, length, isPast];
}

/// A calendar event, reduced to what the briefing needs.
class BriefEvent {
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;

  const BriefEvent({required this.title, required this.start, required this.end, this.allDay = false});
}

/// One email from the inbox digest.
class BriefEmail extends Equatable {
  final String from;
  final String subject;

  const BriefEmail({required this.from, required this.subject});

  /// Parses EmailService's "From: x | Subject: y" lines.
  static BriefEmail parse(String line) {
    final m = RegExp(r'From:\s*(.*?)\s*\|\s*Subject:\s*(.*)').firstMatch(line);
    return m == null ? BriefEmail(from: '', subject: line.trim()) : BriefEmail(from: m.group(1)!, subject: m.group(2)!);
  }

  @override
  List<Object?> get props => [from, subject];
}

/// Your day, built from Pip's own data (not written by the model), so it
/// appears instantly and never drops or invents an item.
class DayBriefing extends Equatable {
  final DateTime date;
  final List<TaskItem> overdue;
  final List<TaskItem> openTasks; // not overdue; due today first
  final List<TimelineItem> timeline;
  final List<BriefEmail> emails;
  final List<String> importantNotifications;

  const DayBriefing({
    required this.date,
    this.overdue = const [],
    this.openTasks = const [],
    this.timeline = const [],
    this.emails = const [],
    this.importantNotifications = const [],
  });

  /// Open tasks due today or earlier.
  int get dueCount => overdue.length + openTasks.where((t) => isDueOn(t, date)).length;

  /// "Needs you now" shows only when something does.
  bool get hasUrgent => overdue.isNotEmpty || importantNotifications.isNotEmpty;

  bool get isEmpty => overdue.isEmpty && openTasks.isEmpty && timeline.isEmpty && emails.isEmpty;

  static bool isDueOn(TaskItem t, DateTime day) {
    final d = t.dueDate;
    return d != null && d.year == day.year && d.month == day.month && d.day == day.day;
  }

  static DayBriefing build({
    required DateTime now,
    required List<TaskItem> tasks,
    List<ScheduledItem> schedule = const [],
    List<BriefEvent> events = const [],
    List<String> emailLines = const [],
    List<String> notifications = const [],
  }) {
    final startOfToday = DateTime(now.year, now.month, now.day);
    final open = tasks.where((t) => !t.isCompleted).toList();
    final overdue = open.where((t) => t.dueDate != null && t.dueDate!.isBefore(startOfToday)).toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    final rest = open.where((t) => !overdue.contains(t)).toList()
      ..sort((a, b) {
        // Dated tasks first, soonest first; undated keep their order.
        if (a.dueDate == null) return b.dueDate == null ? 0 : 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });

    return DayBriefing(
      date: startOfToday,
      overdue: overdue,
      openTasks: rest,
      timeline: _timeline(now, startOfToday, schedule, events),
      emails: emailLines.map(BriefEmail.parse).toList(),
      importantNotifications: notifications,
    );
  }

  static List<TimelineItem> _timeline(
      DateTime now, DateTime today, List<ScheduledItem> schedule, List<BriefEvent> events) {
    bool isToday(DateTime d) => d.year == today.year && d.month == today.month && d.day == today.day;
    final items = <TimelineItem>[
      for (final s in schedule.where((s) => s.enabled && !s.inClockApp))
        // Repeating items ring today if today is one of their days.
        if (s.repeats ? s.days.contains(today.weekday) : isToday(s.at))
          TimelineItem(
            at: DateTime(today.year, today.month, today.day, s.at.hour, s.at.minute),
            kind: s.isAlarm ? TimelineKind.alarm : TimelineKind.reminder,
            title: s.title,
          ),
      for (final e in events.where((e) => !e.allDay && isToday(e.start)))
        TimelineItem(at: e.start, kind: TimelineKind.event, title: e.title, length: e.end.difference(e.start)),
    ];
    return [
      for (final i in items..sort((a, b) => a.at.compareTo(b.at)))
        TimelineItem(at: i.at, kind: i.kind, title: i.title, length: i.length, isPast: i.at.isBefore(now)),
    ];
  }

  @override
  List<Object?> get props => [date, overdue, openTasks, timeline, emails, importantNotifications];
}
