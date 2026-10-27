import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/services/tools/alarm_tools.dart';
import 'package:personal_assistant/core/services/tools/schedule_store.dart';
import 'package:personal_assistant/features/companion/domain/pip_action_speech.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Clock times', () {
    test('understands common spoken and written forms', () {
      expect(parseClockTime('7am'), (7, 0));
      expect(parseClockTime('7:30 pm'), (19, 30));
      expect(parseClockTime('12 am'), (0, 0));
      expect(parseClockTime('12pm'), (12, 0));
      expect(parseClockTime('19:05'), (19, 5));
      expect(parseClockTime('0730'), (7, 30));
      expect(parseClockTime('6.45 p.m.'), (18, 45));
      expect(parseClockTime('25:00'), isNull);
      expect(parseClockTime('13pm'), isNull);
      expect(parseClockTime('soon'), isNull);
    });

    test('a time already past today means tomorrow', () {
      final now = DateTime(2026, 10, 27, 15, 46);
      expect(resolveWhen(time: '4pm', now: now), DateTime(2026, 10, 27, 16));
      expect(resolveWhen(time: '7am', now: now), DateTime(2026, 10, 28, 7));
      expect(resolveWhen(delaySeconds: 600, now: now), DateTime(2026, 10, 27, 15, 56));
      expect(resolveWhen(atIso: '2026-12-01T09:00:00', now: now), DateTime(2026, 12, 1, 9));
      expect(resolveWhen(now: now), isNull);
    });

    test('repeat days', () {
      expect(parseDays('weekdays'), [1, 2, 3, 4, 5]);
      expect(parseDays('Mon, Wed and Fri'), [1, 3, 5]);
      expect(parseDays('every day'), hasLength(7));
      expect(parseDays(null), isEmpty);
      // Android counts Sunday as 1.
      expect(toAndroidDays([1, 7]), [2, 1]);
    });
  });

  group('Schedule store', () {
    test('keeps upcoming items, drops past one-offs, finds by words', () async {
      final now = DateTime.now();
      await ScheduleStore.add(ScheduledItem(id: 1, kind: 'reminder', title: 'Call mum', at: now.add(const Duration(hours: 1))));
      await ScheduleStore.add(ScheduledItem(id: 2, kind: 'reminder', title: 'Old', at: now.subtract(const Duration(hours: 1))));
      await ScheduleStore.add(ScheduledItem(
          id: 3, kind: 'alarm', title: 'Gym', at: now.subtract(const Duration(hours: 2)), days: const [1, 2, 3]));
      final upcoming = await ScheduleStore.upcoming();
      expect(upcoming.map((e) => e.id), [3, 1]); // repeating alarm kept, sorted by time
      expect((await ScheduleStore.find('gym')).single.id, 3);
      await ScheduleStore.remove(3);
      expect(await ScheduleStore.find('gym'), isEmpty);
    });
  });

  test('cancel asks which one when several match', () async {
    final at = DateTime.now().add(const Duration(hours: 3));
    await ScheduleStore.add(ScheduledItem(id: 10, kind: 'reminder', title: 'Gym bag', at: at));
    await ScheduleStore.add(ScheduledItem(id: 11, kind: 'reminder', title: 'Gym class', at: at));
    final res = await CancelReminderTool().execute({'query': 'gym'});
    expect(res['error'], contains('Which one'));
    expect((res['matches'] as List), hasLength(2));
    expect((await CancelReminderTool().execute({'query': 'dentist'}))['error'], contains("couldn't find"));
  });

  test('set_alarm rejects a missing time', () async {
    expect((await SetAlarmTool().execute({'label': 'x'}))['error'], contains('clock time'));
  });

  test('Pip announces alarms and cancellations in plain words', () {
    expect(describeToolResult('set_alarm', {'status': 'created', 'kind': 'alarm', 'time': '2026-10-28T06:30:00'}),
        'Alarm set for 6:30 AM.');
    expect(describeToolResult('cancel_reminder', {'status': 'cancelled', 'title': 'Gym'}), "Done, 'Gym' is cancelled.");
    expect(describePendingAction('cancel_reminder', {'query': 'gym'}), "Cancel your 'gym' alarm or reminder?");
  });
}
