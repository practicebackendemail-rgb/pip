import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/theme/pip_theme.dart';
import '../../../../models/task_model.dart';
import '../../domain/day_briefing.dart';

/// A small section title, optionally tinted (red for "Needs you now").
class BriefingSectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? color;

  const BriefingSectionTitle(this.title, {super.key, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.colors.textMuted;
    return Padding(
      padding: EdgeInsets.only(top: t.space.lg, bottom: t.space.xs),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 16, color: c), SizedBox(width: t.space.xs)],
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: c)),
        ],
      ),
    );
  }
}

/// Overdue tasks (tick or snooze) and important notifications.
class BriefingUrgent extends StatelessWidget {
  final DayBriefing briefing;
  final ValueChanged<TaskItem> onToggle;
  final ValueChanged<TaskItem> onSnooze;

  const BriefingUrgent({super.key, required this.briefing, required this.onToggle, required this.onSnooze});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BriefingSectionTitle(l10n.briefingNeedsYou, icon: Icons.error_outline, color: t.colors.danger),
        for (final task in briefing.overdue)
          _Box(
            borderColor: t.colors.danger,
            child: Row(
              children: [
                Checkbox(value: false, onChanged: (_) => onToggle(task)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.title, style: text.bodyMedium),
                      Text(l10n.briefingOverdueSince(DateFormat('d MMM').format(task.dueDate!)),
                          style: text.bodySmall?.copyWith(color: t.colors.danger)),
                    ],
                  ),
                ),
                TextButton(onPressed: () => onSnooze(task), child: Text(l10n.briefingSnooze)),
              ],
            ),
          ),
        for (final line in briefing.importantNotifications)
          _Box(
            borderColor: t.colors.borderSoft,
            child: Padding(
              padding: EdgeInsets.all(t.space.sm),
              child: Row(
                children: [
                  Icon(Icons.notifications_active_outlined, size: 18, color: t.colors.textMuted),
                  SizedBox(width: t.space.sm),
                  Expanded(child: Text(line, style: text.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Today's alarms, reminders and events in time order; past ones greyed.
class BriefingTimeline extends StatelessWidget {
  final List<TimelineItem> items;

  const BriefingTimeline({super.key, required this.items});

  static IconData _icon(TimelineKind k) => switch (k) {
        TimelineKind.alarm => Icons.alarm,
        TimelineKind.reminder => Icons.notifications_none,
        TimelineKind.event => Icons.event,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BriefingSectionTitle(l10n.briefingToday),
        if (items.isEmpty) Text(l10n.briefingNothingToday, style: text.bodySmall?.copyWith(color: t.colors.textMuted)),
        for (final i in items)
          Padding(
            padding: EdgeInsets.symmetric(vertical: t.space.xs),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text(DateFormat.jm().format(i.at), style: text.bodySmall?.copyWith(color: t.colors.textMuted)),
                ),
                Icon(_icon(i.kind), size: 18, color: i.kind == TimelineKind.event ? t.colors.info : t.colors.textMuted),
                SizedBox(width: t.space.sm),
                Expanded(
                  child: Text(
                    i.length == null ? i.title : '${i.title}  ·  ${l10n.briefingMinutes(i.length!.inMinutes)}',
                    style: text.bodyMedium?.copyWith(
                      color: i.isPast ? t.colors.textFaint : t.colors.text,
                      decoration: i.isPast ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Open tasks with a tick box; due today marked, a few at most.
class BriefingTasks extends StatelessWidget {
  final List<TaskItem> tasks;
  final DateTime today;
  final ValueChanged<TaskItem> onToggle;
  static const int shown = 6;

  const BriefingTasks({super.key, required this.tasks, required this.today, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    String? due(TaskItem task) {
      if (task.dueDate == null) return null;
      return DayBriefing.isDueOn(task, today) ? l10n.briefingDueToday : DateFormat('EEE').format(task.dueDate!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BriefingSectionTitle(l10n.briefingTasks),
        if (tasks.isEmpty) Text(l10n.briefingNoTasks, style: text.bodySmall?.copyWith(color: t.colors.textMuted)),
        for (final task in tasks.take(shown))
          InkWell(
            onTap: () => onToggle(task),
            borderRadius: BorderRadius.circular(t.space.radius),
            child: Row(
              children: [
                Checkbox(value: false, onChanged: (_) => onToggle(task)),
                Expanded(child: Text(task.title, style: text.bodyMedium, overflow: TextOverflow.ellipsis)),
                if (due(task) case final d?)
                  Text(d,
                      style: text.bodySmall?.copyWith(
                          color: DayBriefing.isDueOn(task, today) ? t.colors.warning : t.colors.textMuted)),
              ],
            ),
          ),
        if (tasks.length > shown)
          Text(l10n.briefingMore(tasks.length - shown), style: text.bodySmall?.copyWith(color: t.colors.textMuted)),
      ],
    );
  }
}

/// The latest emails, each with a Reply that asks Pip to draft one.
class BriefingInbox extends StatelessWidget {
  final List<BriefEmail> emails;
  final bool loading;
  final ValueChanged<BriefEmail> onReply;
  static const int shown = 3;

  const BriefingInbox({super.key, required this.emails, required this.loading, required this.onReply});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BriefingSectionTitle(l10n.briefingInbox),
        if (emails.isEmpty)
          Text(loading ? l10n.briefingCheckingEmail : l10n.briefingNoEmail,
              style: text.bodySmall?.copyWith(color: t.colors.textMuted)),
        for (final e in emails.take(shown))
          Padding(
            padding: EdgeInsets.symmetric(vertical: t.space.xs),
            child: Row(
              children: [
                Icon(Icons.mail_outline, size: 18, color: t.colors.textMuted),
                SizedBox(width: t.space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.subject, style: text.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (e.from.isNotEmpty)
                        Text(e.from, style: text.bodySmall?.copyWith(color: t.colors.textMuted), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                TextButton(onPressed: () => onReply(e), child: Text(l10n.briefingReply)),
              ],
            ),
          ),
        if (emails.length > shown)
          Text(l10n.briefingMore(emails.length - shown), style: text.bodySmall?.copyWith(color: t.colors.textMuted)),
      ],
    );
  }
}

class _Box extends StatelessWidget {
  final Color borderColor;
  final Widget child;

  const _Box({required this.borderColor, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      margin: EdgeInsets.only(bottom: t.space.xs),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(t.space.radius),
      ),
      child: child,
    );
  }
}
