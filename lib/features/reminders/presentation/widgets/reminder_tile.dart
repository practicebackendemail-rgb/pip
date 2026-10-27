import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/tools/schedule_store.dart';
import '../../../../core/theme/pip_theme.dart';

/// One alarm or reminder: time, label, when it repeats, and an on/off switch.
/// Tap to edit; swipe to delete.
class ReminderTile extends StatelessWidget {
  final ScheduledItem item;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const ReminderTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  String _when(DateTime now) {
    if (item.inClockApp) return 'In the Clock app';
    if (item.repeats) return describeDays(item.days);
    final next = item.nextOccurrence(now: now) ?? item.at;
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(next.year, next.month, next.day);
    if (day == today) return 'Today';
    if (day == today.add(const Duration(days: 1))) return 'Tomorrow';
    return DateFormat('EEE, d MMM').format(next);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final active = item.enabled && !item.inClockApp;
    final color = active ? PipColors.ink : PipColors.faint;
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: const _DeleteBackground(),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: PipSpace.xs),
        child: InkWell(
          borderRadius: BorderRadius.circular(PipSpace.radius),
          onTap: item.inClockApp ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PipSpace.lg, vertical: PipSpace.md),
            child: Row(
              children: [
                Icon(item.isAlarm ? Icons.alarm : Icons.notifications_none,
                    color: active ? PipColors.amber : PipColors.faint),
                const SizedBox(width: PipSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat.jm().format(item.at), style: text.headlineSmall?.copyWith(color: color)),
                      Text(item.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyLarge?.copyWith(color: color)),
                      Text(_when(DateTime.now()), style: text.bodySmall?.copyWith(color: PipColors.muted)),
                    ],
                  ),
                ),
                if (!item.inClockApp)
                  Switch(
                    value: item.enabled,
                    onChanged: onToggle,
                    activeThumbColor: PipColors.onAmber,
                    activeTrackColor: PipColors.amber,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: PipSpace.xl),
      decoration: BoxDecoration(
        color: PipColors.danger.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(PipSpace.radius),
      ),
      child: const Icon(Icons.delete_outline, color: PipColors.ink),
    );
  }
}
