import 'package:equatable/equatable.dart';
import '../../domain/entities/task_entity.dart';

abstract class TasksEvent extends Equatable {
  const TasksEvent();

  @override
  List<Object?> get props => [];
}

class LoadTasksEvent extends TasksEvent {}

class AddTaskEvent extends TasksEvent {
  final String title;
  final String? description;
  final String project;
  final TaskPriority priority;
  final DateTime? dueDate;

  const AddTaskEvent({
    required this.title,
    this.description,
    this.project = 'Work',
    this.priority = TaskPriority.medium,
    this.dueDate,
  });

  @override
  List<Object?> get props => [title, description, project, priority, dueDate];
}

class ToggleTaskEvent extends TasksEvent {
  final String id;

  const ToggleTaskEvent(this.id);

  @override
  List<Object?> get props => [id];
}

class DeleteTaskEvent extends TasksEvent {
  final String id;

  const DeleteTaskEvent(this.id);

  @override
  List<Object?> get props => [id];
}

class SelectProjectFilterEvent extends TasksEvent {
  final String project;

  const SelectProjectFilterEvent(this.project);

  @override
  List<Object?> get props => [project];
}
