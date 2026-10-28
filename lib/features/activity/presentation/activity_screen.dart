import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/localization/l10n_extension.dart';
import '../../../core/theme/pip_theme.dart';
import '../../companion/presentation/widgets/pip_ledge.dart';
import '../domain/activity_entry.dart';
import 'activity_cubit.dart';
import 'activity_icons.dart';

/// What Pip did: a log of actions grouped by day, each undoable where it
/// still can be. Deliberately not a conversation.
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    return Column(
      children: [
        PipLedge(idleLine: l10n.ledgeActivityIdle),
        Expanded(
          child: BlocBuilder<ActivityCubit, ActivityState>(
            buildWhen: (a, b) => a.entries != b.entries,
            builder: (context, state) {
              if (state.entries.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(t.space.xl),
                    child: Text(l10n.activityEmpty, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                  ),
                );
              }
              final rows = _withDayHeaders(context, state.entries);
              return ListView.builder(
                padding: EdgeInsets.all(t.space.lg),
                itemCount: rows.length,
                itemBuilder: (context, i) => rows[i],
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _withDayHeaders(BuildContext context, List<ActivityEntry> entries) {
    final rows = <Widget>[];
    String? lastDay;
    for (final e in entries) {
      final day = _dayLabel(context, e.at);
      if (day != lastDay) {
        rows.add(_DayHeader(day));
        lastDay = day;
      }
      rows.add(_EntryRow(entry: e));
    }
    return rows;
  }

  String _dayLabel(BuildContext context, DateTime at) {
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(at.year, at.month, at.day)).inDays;
    if (days == 0) return context.l10n.activityToday;
    if (days == 1) return context.l10n.activityYesterday;
    return MaterialLocalizations.of(context).formatMediumDate(at);
  }
}

class _DayHeader extends StatelessWidget {
  final String label;
  const _DayHeader(this.label);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(top: t.space.md, bottom: t.space.sm),
      child: Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final ActivityEntry entry;
  const _EntryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(entry.at));
    final where = switch (entry.ranOn) { 'local' => l10n.ranOnDevice, 'cloud' => l10n.ranInCloud, _ => null };
    final detail = [time, ?where, if (entry.detail != null) entry.detail!].join(' · ');
    return Padding(
      padding: EdgeInsets.only(bottom: t.space.xs),
      child: Material(
        color: t.colors.card,
        borderRadius: BorderRadius.circular(t.space.radius),
        child: ListTile(
          leading: Icon(activityIcon(entry.kind), color: entry.undone ? t.colors.textFaint : t.colors.accent),
          title: Text(
            entry.title,
            style: entry.undone ? TextStyle(color: t.colors.textMuted, decoration: TextDecoration.lineThrough) : null,
          ),
          subtitle: Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
          trailing: entry.undone
              ? Text(l10n.undone, style: TextStyle(color: t.colors.textMuted))
              : entry.canUndo
                  ? TextButton(onPressed: () => context.read<ActivityCubit>().undo(entry), child: Text(l10n.undo))
                  : null,
        ),
      ),
    );
  }
}
