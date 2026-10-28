import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/theme/app_motion_tokens.dart';
import '../../../../core/theme/pip_theme.dart';
import '../../domain/day_briefing.dart';
import '../cubit/pip_stage_cubit.dart';
import '../cubit/pip_stage_state.dart';

/// "Wednesday 28 October" over "Morning, Akash!".
class BriefingHeader extends StatelessWidget {
  final DateTime date;
  final String name;

  const BriefingHeader({super.key, required this.date, required this.name});

  String _part(BuildContext context, int hour) {
    final l10n = context.l10n;
    if (hour < 5) return l10n.greetingLateNight;
    if (hour < 12) return l10n.greetingMorning;
    if (hour < 17) return l10n.greetingAfternoon;
    return l10n.greetingEvening;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final part = _part(context, DateTime.now().hour);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(DateFormat('EEEE d MMMM').format(date), style: text.bodySmall?.copyWith(color: context.tokens.colors.textMuted)),
        Text(name.isEmpty ? l10n.greetingNoName(part) : l10n.greetingWithName(part, name), style: text.titleLarge),
      ],
    );
  }
}

/// Pip's one- or two-line take on the day, written by the model while the
/// rest of the screen is already showing.
class BriefingSummary extends StatelessWidget {
  const BriefingSummary({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return BlocBuilder<PipStageCubit, PipStageState>(
      buildWhen: (a, b) => a.briefingContent != b.briefingContent || a.isLoading != b.isLoading,
      builder: (context, state) {
        final summary = state.briefingContent.trim();
        final loading = summary.isEmpty && state.isLoading;
        if (summary.isEmpty && !loading) return const SizedBox.shrink();
        return Container(
          padding: EdgeInsets.all(t.space.md),
          decoration: BoxDecoration(
            color: t.colors.accent.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(t.space.radius),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.smart_toy_outlined, color: t.colors.accent, size: 22),
              SizedBox(width: t.space.sm),
              Expanded(
                child: AnimatedSwitcher(
                  duration: AppMotionTokens.resolveDuration(context, t.motion.fast),
                  child: Text(
                    loading ? context.l10n.briefingSummaryLoading : summary,
                    key: ValueKey(loading),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: loading ? t.colors.textMuted : t.colors.text,
                          height: 1.4,
                        ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Two count tiles: tasks due today (with overdue) and recent email.
class BriefingStats extends StatelessWidget {
  final DayBriefing briefing;
  final bool loadingEmail;

  const BriefingStats({super.key, required this.briefing, required this.loadingEmail});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: l10n.briefingTasksDue,
            value: '${briefing.dueCount}',
            note: briefing.overdue.isEmpty ? null : l10n.briefingOverdueCount(briefing.overdue.length),
            noteColor: t.colors.danger,
          ),
        ),
        SizedBox(width: t.space.sm),
        Expanded(
          child: _StatTile(
            label: l10n.briefingRecentEmail,
            value: loadingEmail ? '…' : '${briefing.emails.length}',
            note: briefing.importantNotifications.isEmpty
                ? null
                : l10n.briefingImportantCount(briefing.importantNotifications.length),
            noteColor: t.colors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? note;
  final Color noteColor;

  const _StatTile({required this.label, required this.value, this.note, required this.noteColor});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.space.md, vertical: t.space.sm),
      decoration: BoxDecoration(color: t.colors.card, borderRadius: BorderRadius.circular(t.space.radius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.bodySmall?.copyWith(color: t.colors.textMuted)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: text.titleLarge),
              if (note != null) ...[
                SizedBox(width: t.space.xs),
                Flexible(child: Text(note!, style: text.bodySmall?.copyWith(color: noteColor), overflow: TextOverflow.ellipsis)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
