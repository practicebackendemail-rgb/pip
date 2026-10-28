import 'package:flutter/material.dart';
import '../../../core/di/injection.dart';
import '../../../core/localization/l10n_extension.dart';
import '../../../core/services/task_provider.dart';
import '../../../core/theme/pip_theme.dart';
import '../../../models/task_model.dart';
import '../../../widgets/companion/quick_add_task_modal.dart';
import '../../companion/presentation/widgets/pip_ledge.dart';

/// Objectives with Pip working inside them: Pip's ledge and task
/// suggestions on top, your list below. Tick to complete, swipe to delete.
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tasks = getIt<TaskProvider>();
    return Column(
      children: [
        PipLedge(
          idleLine: l10n.ledgeTasksIdle,
          suggestions: [
            PipSuggestion(l10n.chipPlanDay, l10n.queryPlanDay),
            PipSuggestion(l10n.chipWhatsNext, l10n.queryWhatsNext),
            PipSuggestion(l10n.chipMoveOverdue, l10n.queryMoveOverdue),
          ],
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: tasks,
            builder: (context, _) => _TaskList(tasks: tasks),
          ),
        ),
      ],
    );
  }
}

class _TaskList extends StatelessWidget {
  final TaskProvider tasks;
  const _TaskList({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final open = tasks.allTasks.where((x) => !x.isCompleted).toList()
      ..sort((a, b) => (a.dueDate ?? DateTime(9999)).compareTo(b.dueDate ?? DateTime(9999)));
    return ListView(
      padding: EdgeInsets.all(t.space.lg),
      children: [
        Row(
          children: [
            Expanded(child: Text(l10n.tasksTitle, style: Theme.of(context).textTheme.titleLarge)),
            IconButton.filledTonal(
              tooltip: l10n.tasksAdd,
              onPressed: () => QuickAddTaskModal.show(context),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        SizedBox(height: t.space.sm),
        if (open.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: t.space.xl),
            child: Text(l10n.tasksEmpty, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ),
        for (final task in open) _TaskRow(task: task, tasks: tasks),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  final TaskItem task;
  final TaskProvider tasks;
  const _TaskRow({required this.task, required this.tasks});

  String? _due(BuildContext context) {
    final d = task.dueDate;
    if (d == null) return null;
    final now = DateTime.now();
    if (d.isBefore(now)) return context.l10n.tasksOverdue;
    final today = d.year == now.year && d.month == now.month && d.day == now.day;
    final loc = MaterialLocalizations.of(context);
    return today ? loc.formatTimeOfDay(TimeOfDay.fromDateTime(d)) : loc.formatShortMonthDay(d);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final due = _due(context);
    final overdue = due == context.l10n.tasksOverdue;
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => tasks.deleteTask(task.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: t.space.lg),
        color: t.colors.danger.withValues(alpha: .25),
        child: Icon(Icons.delete_outline, color: t.colors.danger),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: t.space.xs),
        child: Material(
          color: t.colors.card,
          borderRadius: BorderRadius.circular(t.space.radius),
          child: ListTile(
            leading: Checkbox(value: false, onChanged: (_) => tasks.toggleTask(task.id)),
            title: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(task.project, style: Theme.of(context).textTheme.bodySmall),
            trailing: due == null
                ? null
                : Text(due, style: TextStyle(fontSize: 12, color: overdue ? t.colors.danger : t.colors.textMuted)),
          ),
        ),
      ),
    );
  }
}
