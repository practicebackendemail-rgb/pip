import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/task_provider.dart';
import '../../../core/services/tools/alarm_tools.dart';
import '../domain/activity_entry.dart';
import '../domain/activity_repository.dart';

/// Activity log in local preferences, newest first, capped at [maxEntries].
class PrefsActivityRepository implements ActivityRepository {
  static const String _key = 'pip_activity_log';
  static const int maxEntries = 200;

  const PrefsActivityRepository();

  @override
  Future<List<ActivityEntry>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => ActivityEntry.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> save(List<ActivityEntry> entries) async {
    final kept = entries.take(maxEntries).map((e) => e.toJson()).toList();
    await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(kept));
  }
}

/// Undo using the same code paths the tools use: cancelling an alarm or
/// reminder by id, or deleting the task Pip added.
class ToolActivityUndoer implements ActivityUndoer {
  final TaskProvider tasks;

  const ToolActivityUndoer(this.tasks);

  @override
  Future<bool> undo(ActivityUndo undo) async {
    switch (undo.type) {
      case 'schedule':
        final res = await CancelReminderTool().execute({'query': undo.ref});
        return !res.containsKey('error');
      case 'task':
        if (!tasks.allTasks.any((t) => t.id == undo.ref)) return false;
        tasks.deleteTask(undo.ref);
        return true;
    }
    return false;
  }
}
