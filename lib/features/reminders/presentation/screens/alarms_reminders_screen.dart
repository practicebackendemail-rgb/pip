import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_motion_tokens.dart';
import '../../../../core/theme/pip_theme.dart';
import '../../../../widgets/companion/mini_pip_assistant.dart';
import '../../data/scheduled_reminder_repository.dart';
import '../../domain/reminder_repository.dart';
import '../cubit/reminders_cubit.dart';
import '../cubit/reminders_state.dart';
import '../widgets/reminder_editor_sheet.dart';
import '../widgets/reminder_permission_banner.dart';
import '../widgets/reminder_tile.dart';

/// Alarms & reminders: a mini Pip at the top that sets them for you, and
/// the full list below with add, edit, switch off and swipe-to-delete.
class AlarmsRemindersScreen extends StatelessWidget {
  final ReminderRepository repository;

  const AlarmsRemindersScreen({super.key, this.repository = const ScheduledReminderRepository()});

  static Future<void> open(BuildContext context) => context.push(AppRoutes.alarms);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RemindersCubit(repository)..load(),
      child: const _RemindersView(),
    );
  }
}

class _RemindersView extends StatelessWidget {
  const _RemindersView();

  Future<void> _add(BuildContext context) async {
    final cubit = context.read<RemindersCubit>();
    final item = await ReminderEditorSheet.show(context);
    if (item != null) await cubit.save(item);
  }

  Future<void> _edit(BuildContext context, ScheduledItem item) async {
    final cubit = context.read<RemindersCubit>();
    final updated = await ReminderEditorSheet.show(context, item: item, onDelete: () => cubit.delete(item));
    if (updated != null) await cubit.save(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alarms & reminders')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add_alarm),
        label: const Text('New'),
      ),
      body: SafeArea(
        child: BlocConsumer<RemindersCubit, RemindersState>(
          listenWhen: (a, b) => b.error != null && a.error != b.error,
          listener: (context, state) =>
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error!))),
          builder: (context, state) {
            final cubit = context.read<RemindersCubit>();
            return ListView(
              padding: const EdgeInsets.fromLTRB(PipSpace.lg, PipSpace.sm, PipSpace.lg, 96),
              children: [
                const MiniPipAssistant(
                  hint: 'Ask Pip: "wake me at 6:30 on weekdays"',
                  screenContext: 'User is on the Alarms & reminders screen',
                ),
                if (!state.isLoading && !state.permissions.allGranted)
                  ReminderPermissionBanner(permissions: state.permissions, onFix: cubit.requestPermissions),
                AnimatedSwitcher(
                  duration: AppMotionTokens.resolveDuration(context, AppMotionTokens.medium),
                  switchInCurve: AppMotionTokens.easeOut,
                  child: _body(context, state),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, RemindersState state) {
    if (state.isLoading) {
      return const Padding(
        key: ValueKey('loading'),
        padding: EdgeInsets.all(PipSpace.xxl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.items.isEmpty) return const _EmptyState(key: ValueKey('empty'));
    return Column(
      key: const ValueKey('list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.alarms.isNotEmpty) ..._section(context, 'Alarms', state.alarms),
        if (state.reminders.isNotEmpty) ..._section(context, 'Reminders', state.reminders),
      ],
    );
  }

  List<Widget> _section(BuildContext context, String title, List<ScheduledItem> items) {
    final cubit = context.read<RemindersCubit>();
    return [
      Padding(
        padding: const EdgeInsets.only(top: PipSpace.xl, bottom: PipSpace.xs),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: PipColors.muted)),
      ),
      for (final item in items)
        ReminderTile(
          item: item,
          onTap: () => _edit(context, item),
          onToggle: (on) => cubit.setEnabled(item, on),
          onDelete: () => cubit.delete(item),
        ),
    ];
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PipSpace.xxl),
      child: Column(
        children: [
          const Icon(Icons.alarm_off, size: 48, color: PipColors.faint),
          const SizedBox(height: PipSpace.md),
          Text('No alarms or reminders yet', style: text.titleMedium),
          const SizedBox(height: PipSpace.xs),
          Text('Tap New, or just tell Pip.', style: text.bodyMedium?.copyWith(color: PipColors.muted)),
        ],
      ),
    );
  }
}
