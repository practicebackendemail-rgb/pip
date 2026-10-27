import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/tools/schedule_store.dart';
import '../../../../core/theme/pip_theme.dart';
import '../cubit/reminder_editor_cubit.dart';

/// Bottom sheet to add or edit an alarm or reminder. Pops with the item to
/// save, or null when cancelled.
class ReminderEditorSheet extends StatelessWidget {
  final VoidCallback? onDelete;

  const ReminderEditorSheet({super.key, this.onDelete});

  static Future<ScheduledItem?> show(BuildContext context,
      {ScheduledItem? item, String kind = ScheduledItem.alarm, VoidCallback? onDelete}) {
    return showModalBottomSheet<ScheduledItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: PipColors.surface,
      builder: (_) => BlocProvider(
        create: (_) => item == null ? ReminderEditorCubit.create(kind: kind) : ReminderEditorCubit.edit(item),
        child: ReminderEditorSheet(onDelete: onDelete),
      ),
    );
  }

  Future<void> _pickTime(BuildContext context, ReminderDraft draft) async {
    final cubit = context.read<ReminderEditorCubit>();
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: draft.hour, minute: draft.minute));
    if (picked != null) cubit.setTime(picked.hour, picked.minute);
  }

  Future<void> _pickDate(BuildContext context, ReminderDraft draft) async {
    final cubit = context.read<ReminderEditorCubit>();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: draft.date.isBefore(now) ? now : draft.date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) cubit.setDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return BlocBuilder<ReminderEditorCubit, ReminderDraft>(
      builder: (context, draft) {
        final cubit = context.read<ReminderEditorCubit>();
        final noun = draft.isAlarm ? 'alarm' : 'reminder';
        return Padding(
          padding: EdgeInsets.fromLTRB(
              PipSpace.xl, 0, PipSpace.xl, PipSpace.xl + MediaQuery.viewInsetsOf(context).bottom),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(draft.isNew ? 'New $noun' : 'Edit $noun', style: text.titleLarge),
                const SizedBox(height: PipSpace.lg),
                if (draft.isNew) ...[
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: ScheduledItem.alarm, label: Text('Alarm'), icon: Icon(Icons.alarm)),
                      ButtonSegment(
                          value: ScheduledItem.reminder, label: Text('Reminder'), icon: Icon(Icons.notifications_none)),
                    ],
                    selected: {draft.kind},
                    onSelectionChanged: (s) => cubit.setKind(s.first),
                  ),
                  const SizedBox(height: PipSpace.lg),
                ],
                _TimeButton(label: DateFormat.jm().format(draft.at), onTap: () => _pickTime(context, draft)),
                const SizedBox(height: PipSpace.md),
                TextFormField(
                  initialValue: draft.title,
                  onChanged: cubit.setTitle,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: draft.isAlarm ? 'Label' : 'Remind me to…'),
                ),
                const SizedBox(height: PipSpace.lg),
                Text('Repeat', style: text.titleMedium),
                const SizedBox(height: PipSpace.sm),
                _DayChips(selected: draft.days, onToggle: cubit.toggleDay),
                if (draft.days.isEmpty) ...[
                  const SizedBox(height: PipSpace.sm),
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(context, draft),
                    icon: const Icon(Icons.event),
                    label: Text(DateFormat('EEEE, d MMMM').format(draft.date)),
                  ),
                ],
                if (!draft.isValid())
                  Padding(
                    padding: const EdgeInsets.only(top: PipSpace.sm),
                    child: Text('That time has already passed.', style: text.bodySmall?.copyWith(color: PipColors.danger)),
                  ),
                const SizedBox(height: PipSpace.xl),
                FilledButton(
                  onPressed: draft.isValid() ? () => Navigator.pop(context, draft.toItem()) : null,
                  child: Text(draft.isNew ? 'Add $noun' : 'Save'),
                ),
                if (onDelete != null)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onDelete!();
                    },
                    style: TextButton.styleFrom(foregroundColor: PipColors.danger),
                    child: Text('Delete $noun'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TimeButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PipSpace.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: PipSpace.lg),
        decoration: BoxDecoration(
          color: PipColors.card,
          borderRadius: BorderRadius.circular(PipSpace.radius),
          border: Border.all(color: PipColors.borderSoft),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: PipColors.amber, fontSize: 36)),
      ),
    );
  }
}

class _DayChips extends StatelessWidget {
  final List<int> selected;
  final ValueChanged<int> onToggle;

  const _DayChips({required this.selected, required this.onToggle});

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: PipSpace.xs,
      runSpacing: PipSpace.xs,
      children: [
        for (var d = 1; d <= 7; d++)
          Tooltip(
            message: _names[d - 1],
            child: FilterChip(
              label: Text(_letters[d - 1]),
              showCheckmark: false,
              selected: selected.contains(d),
              selectedColor: PipColors.amber,
              labelStyle: TextStyle(color: selected.contains(d) ? PipColors.onAmber : PipColors.ink),
              onSelected: (_) => onToggle(d),
            ),
          ),
      ],
    );
  }
}
