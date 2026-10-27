import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/injection.dart';
import '../../core/services/email_service.dart';
import '../../core/services/pip_profile_service.dart';
import '../../core/services/task_provider.dart';
import '../../core/theme/pip_theme.dart';
import '../../features/companion/presentation/cubit/pip_stage_cubit.dart';
import '../../models/task_model.dart';

/// Right-hand panel on wide layouts: greeting, open tasks (tick to complete),
/// and the inbox headline, with a one-click briefing.
class PipTodayPanel extends StatelessWidget {
  const PipTodayPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final tasks = getIt<TaskProvider>();
    final email = getIt<EmailService>();
    final text = Theme.of(context).textTheme;

    return Material(
      color: PipColors.surface,
      child: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([tasks, email]),
          builder: (context, _) {
            final open = tasks.allTasks.where((t) => !t.isCompleted).toList()
              ..sort((a, b) => (a.dueDate ?? DateTime(9999)).compareTo(b.dueDate ?? DateTime(9999)));
            return ListView(
              padding: const EdgeInsets.all(PipSpace.lg),
              children: [
                FutureBuilder<String?>(
                  future: PipProfileService.userName(),
                  builder: (context, snap) => Text(PipProfileService.greeting(snap.data), style: text.titleLarge),
                ),
                const SizedBox(height: PipSpace.xs),
                Text(
                  open.isEmpty ? 'Nothing on your plate.' : '${open.length} open ${open.length == 1 ? 'task' : 'tasks'}',
                  style: text.bodySmall,
                ),
                const SizedBox(height: PipSpace.lg),
                FilledButton.icon(
                  onPressed: () => context.read<PipStageCubit>().triggerBriefing(),
                  icon: const Icon(Icons.wb_sunny_outlined, size: 18),
                  label: const Text('Brief me'),
                ),
                const SizedBox(height: PipSpace.xl),
                Text('TODAY', style: text.labelSmall),
                const SizedBox(height: PipSpace.sm),
                if (open.isEmpty)
                  Text('Ask Pip to add one, or enjoy the quiet.', style: text.bodySmall)
                else
                  for (final t in open.take(8)) _TaskRow(task: t, onDone: () => tasks.toggleTask(t.id)),
                const SizedBox(height: PipSpace.xl),
                Text('INBOX', style: text.labelSmall),
                const SizedBox(height: PipSpace.sm),
                Text(
                  !email.isConfigured
                      ? 'Not connected. Add it in Settings → Connections.'
                      : email.recentHeaders.isEmpty
                          ? 'Connected as ${email.config!.username}.'
                          : '${email.recentHeaders.length} recent messages.',
                  style: text.bodySmall,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final TaskItem task;
  final VoidCallback onDone;

  const _TaskRow({required this.task, required this.onDone});

  String? _due(BuildContext context) {
    final d = task.dueDate;
    if (d == null) return null;
    final now = DateTime.now();
    if (d.isBefore(now)) return 'overdue';
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(d));
    }
    return MaterialLocalizations.of(context).formatShortMonthDay(d);
  }

  @override
  Widget build(BuildContext context) {
    final due = _due(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: PipSpace.xs),
      child: Material(
        color: PipColors.card,
        borderRadius: BorderRadius.circular(PipSpace.radius),
        child: ListTile(
          dense: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PipSpace.radius)),
          leading: IconButton(
            tooltip: 'Mark done',
            icon: const Icon(Icons.radio_button_unchecked, color: PipColors.muted, size: 20),
            onPressed: onDone,
          ),
          title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: due == null
              ? null
              : Text(due, style: TextStyle(fontSize: 12, color: due == 'overdue' ? PipColors.danger : PipColors.muted)),
        ),
      ),
    );
  }
}
