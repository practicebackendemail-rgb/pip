import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../brains/data/pip_brains.dart';
import '../domain/activity_describer.dart';
import '../domain/activity_entry.dart';
import '../domain/activity_repository.dart';

class ActivityState extends Equatable {
  final List<ActivityEntry> entries; // newest first

  /// The action just taken, shown as a result card until dismissed.
  final ActivityEntry? latest;

  const ActivityState({this.entries = const [], this.latest});

  ActivityState copyWith({List<ActivityEntry>? entries, ActivityEntry? latest, bool clearLatest = false}) =>
      ActivityState(entries: entries ?? this.entries, latest: clearLatest ? null : (latest ?? this.latest));

  @override
  List<Object?> get props => [entries, latest];
}

/// The log of what Pip did, with undo. Tools report results through
/// [ActivityRecorder], so the chat engine doesn't know this exists.
class ActivityCubit extends Cubit<ActivityState> {
  final ActivityRepository repository;
  final ActivityUndoer undoer;

  ActivityCubit({required this.repository, required this.undoer}) : super(const ActivityState()) {
    ActivityRecorder._sink = this;
  }

  Future<void> load() async => emit(state.copyWith(entries: await repository.load()));

  /// Logs a tool result if it was an action (lookups are ignored).
  Future<void> recordTool(String tool, Map<String, dynamic> args, Map<String, dynamic> result) async {
    final entry = describeToolActivity(tool, args, result);
    if (entry != null) await record(entry);
  }

  Future<void> record(ActivityEntry entry) async {
    if (entry.ranOn == null) entry = entry.ranOnBrain(PipBrains.instance.lastUsed?.name);
    final entries = [entry, ...state.entries];
    emit(state.copyWith(entries: entries, latest: entry));
    await repository.save(entries);
  }

  void dismissLatest() => emit(state.copyWith(clearLatest: true));

  /// Reverses [entry]. Returns false if it could no longer be undone.
  Future<bool> undo(ActivityEntry entry) async {
    if (!entry.canUndo || !await undoer.undo(entry.undo!)) return false;
    final updated = entry.markUndone();
    final entries = [for (final e in state.entries) e.id == entry.id ? updated : e];
    emit(state.copyWith(entries: entries, latest: state.latest?.id == entry.id ? updated : state.latest));
    await repository.save(entries);
    return true;
  }

  @override
  Future<void> close() {
    if (ActivityRecorder._sink == this) ActivityRecorder._sink = null;
    return super.close();
  }
}

/// Where tool runs report outcomes. A no-op until an [ActivityCubit] exists.
abstract final class ActivityRecorder {
  static ActivityCubit? _sink;

  static void tool(String name, Map<String, dynamic> args, Map<String, dynamic> result) =>
      _sink?.recordTool(name, args, result);

  static void entry(ActivityEntry entry) => _sink?.record(entry);
}
