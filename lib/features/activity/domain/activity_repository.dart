import 'activity_entry.dart';

/// Stores what Pip did.
abstract interface class ActivityRepository {
  Future<List<ActivityEntry>> load();
  Future<void> save(List<ActivityEntry> entries);
}

/// Reverses an action Pip took. Returns false if it could not be undone.
abstract interface class ActivityUndoer {
  Future<bool> undo(ActivityUndo undo);
}
