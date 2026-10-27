import '../../domain/entities/task_entity.dart';

/// Data Layer Model with explicit serialization and domain entity mapping.
class TaskModel {
  final String id;
  final String title;
  final String? description;
  final String project;
  final DateTime? dueDate;
  final TaskPriority priority;
  final bool isCompleted;
  final DateTime createdAt;

  TaskModel({
    required this.id,
    required this.title,
    this.description,
    this.project = 'General',
    this.dueDate,
    this.priority = TaskPriority.medium,
    this.isCompleted = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'project': project,
        'dueDate': dueDate?.toIso8601String(),
        'priority': priority.index,
        'isCompleted': isCompleted,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TaskModel.fromJson(Map<String, dynamic> json) => TaskModel(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        project: (json['project'] as String?) ?? 'General',
        dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
        priority: TaskPriority.values[json['priority'] as int? ?? 1],
        isCompleted: json['isCompleted'] as bool? ?? false,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : DateTime.now(),
      );

  factory TaskModel.fromEntity(TaskEntity entity) => TaskModel(
        id: entity.id,
        title: entity.title,
        description: entity.description,
        project: entity.project,
        dueDate: entity.dueDate,
        priority: entity.priority,
        isCompleted: entity.isCompleted,
        createdAt: entity.createdAt,
      );

  TaskEntity toEntity() => TaskEntity(
        id: id,
        title: title,
        description: description,
        project: project,
        dueDate: dueDate,
        priority: priority,
        isCompleted: isCompleted,
        createdAt: createdAt,
      );
}
