import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/features/activity/domain/activity_describer.dart';
import 'package:personal_assistant/features/activity/domain/activity_entry.dart';
import 'package:personal_assistant/features/activity/domain/activity_repository.dart';
import 'package:personal_assistant/features/activity/presentation/activity_cubit.dart';

class _MemoryRepo implements ActivityRepository {
  List<ActivityEntry> saved = [];
  @override
  Future<List<ActivityEntry>> load() async => saved;
  @override
  Future<void> save(List<ActivityEntry> entries) async => saved = entries;
}

class _FakeUndoer implements ActivityUndoer {
  final bool succeed;
  final List<ActivityUndo> calls = [];
  _FakeUndoer({this.succeed = true});
  @override
  Future<bool> undo(ActivityUndo undo) async {
    calls.add(undo);
    return succeed;
  }
}

void main() {
  final now = DateTime(2026, 10, 28, 16, 12);

  group('Describing tool results as actions', () {
    test('an alarm reads as an action and can be undone by its id', () {
      final e = describeToolActivity('set_alarm', {}, {
        'status': 'created',
        'id': 42,
        'label': 'Gym',
        'time': '2026-10-29T06:30:00',
        'repeat': [1, 2, 3, 4, 5],
      }, now: now)!;
      expect(e.kind, ActivityKind.alarm);
      expect(e.title, 'Set alarm 6:30 AM, repeating');
      expect(e.detail, 'Gym');
      expect(e.undo, const ActivityUndo('schedule', '42'));
    });

    test('a new task is undoable by task id', () {
      final e = describeToolActivity('create_task', {}, {'status': 'success', 'id': 'abc', 'title': 'Book dentist'}, now: now)!;
      expect(e.title, "Added task 'Book dentist'");
      expect(e.undo, const ActivityUndo('task', 'abc'));
    });

    test('lookups and failures are not logged', () {
      expect(describeToolActivity('list_reminders', {}, {'count': 2}, now: now), isNull);
      expect(describeToolActivity('get_current_time', {}, {'time': 'x'}, now: now), isNull);
      expect(describeToolActivity('set_alarm', {}, {'error': 'nope'}, now: now), isNull);
    });

    test('a draft says it was not sent', () {
      final e = describeToolActivity('draft_email', {'recipient': 'sam@x.io'}, {'status': 'draft_created'}, now: now)!;
      expect(e.title, 'Drafted an email to sam@x.io');
      expect(e.detail, 'Not sent');
      expect(e.canUndo, isFalse);
    });
  });

  group('Activity cubit', () {
    test('records actions newest first, shows the latest, and persists', () async {
      final repo = _MemoryRepo();
      final cubit = ActivityCubit(repository: repo, undoer: _FakeUndoer());
      await cubit.recordTool('create_task', {}, {'id': '1', 'title': 'A'});
      await cubit.recordTool('list_tasks', {}, {'count': 1}); // ignored
      await cubit.recordTool('create_task', {}, {'id': '2', 'title': 'B'});
      expect(cubit.state.entries.map((e) => e.title), ["Added task 'B'", "Added task 'A'"]);
      expect(cubit.state.latest!.title, "Added task 'B'");
      expect(repo.saved, hasLength(2));
      cubit.dismissLatest();
      expect(cubit.state.latest, isNull);
      await cubit.close();
    });

    test('undo marks the entry undone and calls the undoer once', () async {
      final undoer = _FakeUndoer();
      final cubit = ActivityCubit(repository: _MemoryRepo(), undoer: undoer);
      await cubit.recordTool('set_reminder', {}, {'id': 7, 'title': 'Stretch', 'scheduled_time': '2026-10-28T17:00:00'});
      final entry = cubit.state.entries.single;
      expect(await cubit.undo(entry), isTrue);
      expect(cubit.state.entries.single.undone, isTrue);
      expect(cubit.state.entries.single.canUndo, isFalse);
      expect(await cubit.undo(cubit.state.entries.single), isFalse);
      expect(undoer.calls, [const ActivityUndo('schedule', '7')]);
      await cubit.close();
    });

    test('a failed undo leaves the entry as it was', () async {
      final cubit = ActivityCubit(repository: _MemoryRepo(), undoer: _FakeUndoer(succeed: false));
      await cubit.recordTool('create_task', {}, {'id': '1', 'title': 'A'});
      expect(await cubit.undo(cubit.state.entries.single), isFalse);
      expect(cubit.state.entries.single.undone, isFalse);
      await cubit.close();
    });

    test('tools report through the recorder once a cubit exists', () async {
      final cubit = ActivityCubit(repository: _MemoryRepo(), undoer: _FakeUndoer());
      ActivityRecorder.tool('create_task', {}, {'id': '9', 'title': 'Via recorder'});
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.entries.single.title, "Added task 'Via recorder'");
      await cubit.close();
    });
  });

  test('entries survive a JSON round trip', () {
    final e = ActivityEntry(
        id: 'x', kind: ActivityKind.reminder, title: 'T', detail: 'D', at: now, undo: const ActivityUndo('schedule', '3'));
    expect(ActivityEntry.fromJson(e.toJson()), e);
  });
}
