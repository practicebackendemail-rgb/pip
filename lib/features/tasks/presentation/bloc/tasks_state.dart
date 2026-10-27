import 'package:equatable/equatable.dart';
import '../../domain/entities/task_entity.dart';

enum TasksStatus { initial, loading, success, failure }

class TasksState extends Equatable {
  final TasksStatus status;
  final List<TaskEntity> tasks;
  final String selectedProject;
  final int completedTodayCount;
  final int streakDays;
  final String? errorMessage;

  const TasksState({
    this.status = TasksStatus.initial,
    this.tasks = const [],
    this.selectedProject = 'All',
    this.completedTodayCount = 0,
    this.streakDays = 1,
    this.errorMessage,
  });

  List<TaskEntity> get filteredTasks {
    if (selectedProject == 'All') return tasks;
    return tasks.where((t) => t.project == selectedProject).toList();
  }

  TasksState copyWith({
    TasksStatus? status,
    List<TaskEntity>? tasks,
    String? selectedProject,
    int? completedTodayCount,
    int? streakDays,
    String? errorMessage,
  }) {
    return TasksState(
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      selectedProject: selectedProject ?? this.selectedProject,
      completedTodayCount: completedTodayCount ?? this.completedTodayCount,
      streakDays: streakDays ?? this.streakDays,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        tasks,
        selectedProject,
        completedTodayCount,
        streakDays,
        errorMessage,
      ];
}
