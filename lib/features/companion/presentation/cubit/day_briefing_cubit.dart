import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/pip_profile_service.dart';
import '../../../../core/services/tools/schedule_store.dart';
import '../../../../models/task_model.dart';
import '../../data/day_briefing_source.dart';
import '../../domain/day_briefing.dart';

class DayBriefingState extends Equatable {
  final DayBriefing? briefing;
  final bool loadingEmail;
  final String name;

  const DayBriefingState({this.briefing, this.loadingEmail = true, this.name = ''});

  @override
  List<Object?> get props => [briefing, loadingEmail, name];
}

/// The briefing screen's data. On-device sections show at once; email,
/// which needs the network, joins when it arrives. Ticking or snoozing a
/// task, or Pip changing tasks and alarms elsewhere, refreshes it.
class DayBriefingCubit extends Cubit<DayBriefingState> {
  final DayBriefingSource source;
  StreamSubscription<void>? _schedule;
  List<String> _emailLines = const [];
  String _name = '';

  DayBriefingCubit(this.source) : super(const DayBriefingState()) {
    source.tasks.addListener(_refreshLocal);
    _schedule = ScheduleStore.changes.listen((_) => _refreshLocal());
  }

  Future<void> load() async {
    _name = await PipProfileService.userName() ?? '';
    await _refreshLocal(loadingEmail: true);
    _emailLines = await source.emailLines();
    await _refreshLocal(loadingEmail: false);
  }

  Future<void> _refreshLocal({bool? loadingEmail}) async {
    final b = await source.local();
    if (isClosed) return;
    final withEmail = DayBriefing(
      date: b.date,
      overdue: b.overdue,
      openTasks: b.openTasks,
      timeline: b.timeline,
      emails: _emailLines.map(BriefEmail.parse).toList(),
      importantNotifications: b.importantNotifications,
    );
    emit(DayBriefingState(briefing: withEmail, loadingEmail: loadingEmail ?? state.loadingEmail, name: _name));
  }

  void toggleTask(TaskItem task) => source.tasks.toggleTask(task.id);

  /// Moves an overdue task to tomorrow morning.
  void snooze(TaskItem task, {DateTime? now}) {
    final t = now ?? DateTime.now();
    source.tasks.updateTask(id: task.id, dueDate: DateTime(t.year, t.month, t.day + 1, 9));
  }

  @override
  Future<void> close() {
    source.tasks.removeListener(_refreshLocal);
    _schedule?.cancel();
    return super.close();
  }
}
