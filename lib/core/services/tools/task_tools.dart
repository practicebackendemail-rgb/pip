import 'package:intl/intl.dart';
import '../../domain/pip_tool.dart';
import '../task_provider.dart';

class CreateTaskTool extends PipTool {
  final TaskProvider taskProvider;

  const CreateTaskTool(this.taskProvider)
      : super(
          name: 'create_task',
          description: 'Creates a new objective/task for the user with title, description, and optional due date.',
          confirmationLevel: ToolConfirmationLevel.level1ConfirmAction,
          parameters: const [
            ToolParameterSpec(name: 'title', type: 'string', description: 'Title of the task'),
            ToolParameterSpec(name: 'description', type: 'string', description: 'Additional details or notes', isRequired: false),
            ToolParameterSpec(name: 'project', type: 'string', description: 'Project (Work, Personal, Fitness)', isRequired: false),
            ToolParameterSpec(name: 'due_date', type: 'string', description: 'ISO-8601 date string or format YYYY-MM-DD', isRequired: false),
          ],
        );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final title = args['title'] as String? ?? 'Untitled Task';
    final desc = args['description'] as String? ?? '';
    final project = args['project'] as String? ?? 'Work';
    DateTime? dueDate;
    if (args['due_date'] != null) {
      dueDate = DateTime.tryParse(args['due_date'].toString());
    }

    final id = taskProvider.addTask(
      title: title,
      description: desc,
      project: project,
      dueDate: dueDate,
    );

    return {
      'status': 'success',
      'id': id,
      'title': title,
      'project': project,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}

class ListTasksTool extends PipTool {
  final TaskProvider taskProvider;

  const ListTasksTool(this.taskProvider)
      : super(
          name: 'list_tasks',
          description: 'Lists active and pending objectives or tasks for the user.',
          confirmationLevel: ToolConfirmationLevel.level0ReadOnly,
          parameters: const [
            ToolParameterSpec(name: 'include_completed', type: 'boolean', description: 'Whether to include finished tasks', isRequired: false),
          ],
        );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final includeCompleted = args['include_completed'] == true;
    final tasks = taskProvider.allTasks.where((t) => includeCompleted || !t.isCompleted).toList();

    return {
      'count': tasks.length,
      'tasks': tasks
          .map((t) => {
                'id': t.id,
                'title': t.title,
                'project': t.project,
                'is_completed': t.isCompleted,
                'due_date': t.dueDate != null ? DateFormat('yyyy-MM-dd').format(t.dueDate!) : null,
              })
          .toList(),
    };
  }
}

class CompleteTaskTool extends PipTool {
  final TaskProvider taskProvider;

  const CompleteTaskTool(this.taskProvider)
      : super(
          name: 'complete_task',
          description: 'Marks a designated task as completed by title or identifier.',
          confirmationLevel: ToolConfirmationLevel.level2ReportAfter,
          parameters: const [
            ToolParameterSpec(name: 'query', type: 'string', description: 'Task title or keywords matching the task to complete'),
          ],
        );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final q = (args['query'] as String? ?? '').toLowerCase();
    final tasks = taskProvider.allTasks.where((t) => !t.isCompleted).toList();
    final match = tasks.firstWhere(
      (t) => t.title.toLowerCase().contains(q) || t.id.toLowerCase() == q,
      orElse: () => tasks.isNotEmpty ? tasks.first : throw StateError('No pending tasks found matching "$q"'),
    );

    taskProvider.toggleTask(match.id);

    return {
      'status': 'completed',
      'task_id': match.id,
      'title': match.title,
    };
  }
}
