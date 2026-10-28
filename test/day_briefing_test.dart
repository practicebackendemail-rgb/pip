import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/localization/generated/app_localizations.dart';
import 'package:personal_assistant/core/services/tools/schedule_store.dart';
import 'package:personal_assistant/core/theme/pip_theme.dart';
import 'package:personal_assistant/features/companion/domain/day_briefing.dart';
import 'package:personal_assistant/features/companion/domain/pip_briefing.dart';
import 'package:personal_assistant/features/companion/presentation/widgets/briefing_sections.dart';
import 'package:personal_assistant/models/task_model.dart';

final now = DateTime(2026, 10, 28, 9, 30); // a Wednesday morning

TaskItem task(String id, {DateTime? due, bool done = false}) =>
    TaskItem(id: id, title: id, dueDate: due, isCompleted: done);

void main() {
  group('Building the day', () {
    final b = DayBriefing.build(
      now: now,
      tasks: [
        task('taxes', due: DateTime(2026, 10, 26)),
        task('deck', due: DateTime(2026, 10, 28, 17)),
        task('dentist'),
        task('insurance', due: DateTime(2026, 10, 30)),
        task('old', due: DateTime(2026, 10, 1), done: true),
      ],
      schedule: [
        ScheduledItem(id: 1, kind: 'alarm', title: 'Wake up', at: DateTime(2026, 1, 1, 6, 30), days: const [1, 2, 3, 4, 5]),
        ScheduledItem(id: 2, kind: 'reminder', title: 'Call mum', at: DateTime(2026, 10, 28, 17)),
        ScheduledItem(id: 3, kind: 'alarm', title: 'Weekend', at: DateTime(2026, 1, 1, 8), days: const [6, 7]),
        ScheduledItem(id: 4, kind: 'reminder', title: 'Off', at: DateTime(2026, 10, 28, 12), enabled: false),
      ],
      events: [BriefEvent(title: 'Design review', start: DateTime(2026, 10, 28, 10), end: DateTime(2026, 10, 28, 11))],
      emailLines: ['From: priya@x.com | Subject: Deck for 10:00?'],
    );

    test('overdue tasks are split out; done tasks are hidden', () {
      expect(b.overdue.map((t) => t.id), ['taxes']);
      expect(b.openTasks.map((t) => t.id), ['deck', 'insurance', 'dentist']); // dated first, undated last
      expect(b.dueCount, 2); // overdue + due today
      expect(b.hasUrgent, isTrue);
    });

    test("today's timeline: repeating alarms on their days, sorted, past ones marked", () {
      expect(b.timeline.map((i) => i.title), ['Wake up', 'Design review', 'Call mum']);
      expect(b.timeline.first.isPast, isTrue);
      expect(b.timeline[1].length, const Duration(hours: 1));
      expect(b.timeline.last.isPast, isFalse);
    });

    test('email lines become sender and subject', () {
      expect(b.emails.single, const BriefEmail(from: 'priya@x.com', subject: 'Deck for 10:00?'));
    });

    test('a quiet day has nothing urgent', () {
      final quiet = DayBriefing.build(now: now, tasks: [task('later', due: DateTime(2026, 11, 2))]);
      expect(quiet.hasUrgent, isFalse);
      expect(quiet.timeline, isEmpty);
    });
  });

  test("the summary prompt tells Pip what's overdue and due today", () {
    expect(PipBriefing.taskLine(task('taxes', due: DateTime(2026, 10, 26)), now: now), 'taxes (overdue since 26/10)');
    expect(PipBriefing.taskLine(task('deck', due: DateTime(2026, 10, 28, 17)), now: now), 'deck (due today)');
    expect(PipBriefing.taskLine(task('dentist'), now: now), 'dentist');
    expect(PipBriefing.prompt(tasks: const [], emails: const []), contains('no markdown'));
  });

  testWidgets('sections show tasks, timeline and inbox, and ticking works', (tester) async {
    final ticked = <String>[];
    final b = DayBriefing.build(
      now: now,
      tasks: [task('taxes', due: DateTime(2026, 10, 26)), task('deck', due: DateTime(2026, 10, 28))],
      emailLines: ['From: sam@x.com | Subject: Lunch?'],
    );
    await tester.pumpWidget(MaterialApp(
      theme: PipTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ListView(children: [
          BriefingUrgent(briefing: b, onToggle: (t) => ticked.add(t.id), onSnooze: (_) {}),
          BriefingTimeline(items: b.timeline),
          BriefingTasks(tasks: b.openTasks, today: b.date, onToggle: (t) => ticked.add(t.id)),
          BriefingInbox(emails: b.emails, loading: false, onReply: (_) {}),
        ]),
      ),
    ));
    expect(find.text('Needs you now'), findsOneWidget);
    expect(find.text('Overdue since 26 Oct'), findsOneWidget);
    expect(find.text('Nothing scheduled today.'), findsOneWidget);
    expect(find.text('today'), findsOneWidget);
    expect(find.text('Lunch?'), findsOneWidget);
    await tester.tap(find.text('deck'));
    expect(ticked, ['deck']);
  });
}
