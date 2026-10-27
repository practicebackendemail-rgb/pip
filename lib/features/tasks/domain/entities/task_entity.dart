import 'package:equatable/equatable.dart';

enum TaskPriority { low, medium, high, urgent }

/// Pure Domain Entity representing a Task in the business layer.
class TaskEntity extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String project;
  final DateTime? dueDate;
  final TaskPriority priority;
  final bool isCompleted;
  final DateTime createdAt;

  TaskEntity({
    required this.id,
    required this.title,
    this.description,
    this.project = 'General',
    this.dueDate,
    this.priority = TaskPriority.medium,
    this.isCompleted = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  TaskEntity copyWith({
    String? id,
    String? title,
    String? description,
    String? project,
    DateTime? dueDate,
    TaskPriority? priority,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return TaskEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      project: project ?? this.project,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        project,
        dueDate,
        priority,
        isCompleted,
        createdAt,
      ];
}
