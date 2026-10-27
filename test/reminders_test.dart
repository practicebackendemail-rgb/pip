import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/services/tools/alarm_tools.dart';
import 'package:personal_assistant/core/services/tools/reminder_tool.dart';
import 'package:personal_assistant/core/services/tools/schedule_store.dart';
import 'package:personal_assistant/features/reminders/domain/reminder_repository.dart';
import 'package:personal_assistant/features/reminders/presentation/cubit/reminder_editor_cubit.dart';
import 'package:personal_assistant/features/reminders/presentation/cubit/reminders_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory repository so the cubit is tested without notifications.
class _FakeRepository implements ReminderRepository {
  final List<ScheduledItem> items = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();
  ReminderPermissions perms = const ReminderPermissions(notifications: true, exactAlarms: false);

  void externalAdd(ScheduledItem item) {
    items.add(item);
    _changes.add(null);
  }

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<ScheduledItem>> upcoming() async => [...items];

  @override
  Future<void> save(ScheduledItem item) async {
    items
      ..removeWhere((e) => e.id == item.id)
      ..add(item);
  }

  @override
  Future<void> delete(ScheduledItem item) async => items.removeWhere((e) => e.id == item.id);

  @override
  Future<ReminderPermissions> permissions() async => perms;

  @override
  Future<ReminderPermissions> requestPermissions() async => perms = ReminderPermissions.granted;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Next occurrence', () {
    final tue3pm = DateTime(2026, 10, 27, 15);

    test('one-off fires once, then is gone', () {
      final item = ScheduledItem(id: 1, kind: 'reminder', title: 'x', at: DateTime(2026, 10, 27, 18));
      expect(item.nextOccurrence(now: tue3pm), DateTime(2026, 10, 27, 18));
      expect(item.nextOccurrence(now: DateTime(2026, 10, 27, 19)), isNull);
    });

    test('repeating alarm finds the next chosen weekday', () {
      final weekdays7am = ScheduledItem(id: 1, kind: 'alarm', title: 'x', at: DateTime(2026, 1, 1, 7), days: const [1, 2, 3, 4, 5]);
      expect(weekdays7am.nextOccurrence(now: tue3pm), DateTime(2026, 10, 28, 7)); // Wednesday
      final fri = DateTime(2026, 10, 30, 8);
      expect(weekdays7am.nextOccurrence(now: fri), DateTime(2026, 11, 2, 7)); // skips the weekend
      final sundays = ScheduledItem(id: 2, kind: 'alarm', title: 'x', at: DateTime(2026, 1, 1, 16), days: const [7]);
      expect(sundays.nextOccurrence(now: tue3pm), DateTime(2026, 11, 1, 16));
    });

    test('repeat days read naturally', () {
      expect(describeDays(const [1, 2, 3, 4, 5]), 'Weekdays');
      expect(describeDays(const [6, 7]), 'Weekends');
      expect(describeDays(const [1, 2, 3, 4, 5, 6, 7]), 'Every day');
      expect(describeDays(const [5, 1, 3]), 'Mon, Wed, Fri');
    });

    test('items saved before the enabled flag existed load as on', () {
      final old = ScheduledItem.fromJson({'id': 5, 'kind': 'alarm', 'title': 'Old', 'at': '2026-10-28T07:00:00'});
      expect(old.enabled, isTrue);
      expect(ScheduledItem.fromJson(old.copyWith(enabled: false).toJson()).enabled, isFalse);
    });
  });

  group('Tools use Pip\'s own alarms', () {
    test('set_alarm stores a repeating Pip alarm, not a Clock-app one', () async {
      final res = await const SetAlarmTool().execute({'time': '6:30am', 'label': 'Gym', 'repeat': 'weekdays'});
      expect(res['status'], 'created');
      final item = (await ScheduleStore.all()).single;
      expect(item.isAlarm, isTrue);
      expect(item.inClockApp, isFalse);
      expect(item.days, [1, 2, 3, 4, 5]);
      expect((item.at.hour, item.at.minute), (6, 30));
      expect(item.id, lessThan(100000000)); // notification ids must fit 32 bits
    });

    test('set_reminder can repeat', () async {
      final res = await const ReminderTool().execute({'title': 'Water plants', 'time': '9am', 'repeat': 'sat,sun'});
      expect(res['status'], 'scheduled');
      expect((await ScheduleStore.all()).single.days, [6, 7]);
    });

    test('upsert replaces by id and announces the change', () async {
      final at = DateTime.now().add(const Duration(hours: 2));
      final seen = expectLater(ScheduleStore.changes, emitsInOrder([null, null]));
      await ScheduleStore.upsert(ScheduledItem(id: 9, kind: 'alarm', title: 'A', at: at));
      await ScheduleStore.upsert(ScheduledItem(id: 9, kind: 'alarm', title: 'B', at: at, enabled: false));
      final items = await ScheduleStore.all();
      expect(items.single.title, 'B');
      expect(items.single.enabled, isFalse);
      await seen;
    });
  });

  group('Editor', () {
    final now = DateTime(2026, 10, 27, 15, 2);

    test('a new item starts an hour ahead on a 5-minute mark', () {
      final draft = ReminderEditorCubit.create(kind: 'alarm', now: now).state;
      expect((draft.hour, draft.minute), (16, 5));
      expect(draft.isNew, isTrue);
    });

    test('a time already past today moves a one-off to tomorrow', () {
      final cubit = ReminderEditorCubit.create(kind: 'reminder', now: now)..setTime(9, 0, now: now);
      expect(cubit.state.at, DateTime(2026, 10, 28, 9));
      expect(cubit.state.isValid(now: now), isTrue);
    });

    test('repeat days toggle, and a blank title gets a default', () {
      final cubit = ReminderEditorCubit.create(kind: 'alarm', now: now)
        ..toggleDay(1)
        ..toggleDay(3)
        ..toggleDay(1);
      expect(cubit.state.days, [3]);
      expect(cubit.state.toItem().title, 'Alarm');
    });

    test('editing keeps the id', () {
      final item = ScheduledItem(id: 42, kind: 'reminder', title: 'Call', at: DateTime(2026, 11, 1, 10));
      final draft = ReminderEditorCubit.edit(item).state;
      expect(draft.toItem().id, 42);
      expect(draft.toItem().title, 'Call');
    });
  });

  group('RemindersCubit', () {
    test('loads, toggles, deletes, and picks up items Pip adds', () async {
      final repo = _FakeRepository();
      final at = DateTime.now().add(const Duration(hours: 1));
      repo.items.add(ScheduledItem(id: 1, kind: 'alarm', title: 'Wake', at: at));
      final cubit = RemindersCubit(repo);
      await cubit.load();
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.alarms.single.title, 'Wake');
      expect(cubit.state.permissions.exactAlarms, isFalse);

      await cubit.setEnabled(cubit.state.items.single, false);
      expect(cubit.state.items.single.enabled, isFalse);

      repo.externalAdd(ScheduledItem(id: 2, kind: 'reminder', title: 'Pills', at: at));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.reminders.single.title, 'Pills');

      await cubit.delete(cubit.state.alarms.single);
      expect(cubit.state.alarms, isEmpty);

      await cubit.requestPermissions();
      expect(cubit.state.permissions.allGranted, isTrue);
      await cubit.close();
    });
  });
}
