import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/event_log.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/theme/app_motion_tokens.dart';
import '../../../../core/theme/pip_theme.dart';
import '../../data/day_briefing_source.dart';
import '../../../../models/task_model.dart';
import '../../domain/day_briefing.dart';
import '../cubit/day_briefing_cubit.dart';
import '../cubit/pip_stage_cubit.dart';
import '../widgets/briefing_sections.dart';
import '../widgets/briefing_top.dart';
import '../widgets/pip_ledge.dart';
import '../widgets/pip_screen_context.dart';

/// Your day, built from your real tasks, alarms, calendar and email so it
/// shows at once. Pip adds a short summary on top and sits on the ledge for
/// follow-ups ("what's urgent?", "plan my day").
class BriefingScreen extends StatefulWidget {
  const BriefingScreen({super.key});

  @override
  State<BriefingScreen> createState() => _BriefingScreenState();
}

class _BriefingScreenState extends State<BriefingScreen> {
  late final DayBriefingCubit _day = DayBriefingCubit(DayBriefingSource(tasks: getIt(), email: getIt()))..load();

  @override
  void initState() {
    super.initState();
    PipScreenContext.current.value = 'the Briefing screen, reading today\'s briefing';
    final cubit = context.read<PipStageCubit>();
    if (cubit.state.briefingContent.trim().isEmpty && !cubit.state.isLoading) cubit.triggerBriefing();
  }

  @override
  void dispose() {
    PipScreenContext.current.value = null;
    getIt<EventLogService>().log('briefing_closed');
    _day.close();
    super.dispose();
  }

  void _refresh() {
    context.read<PipStageCubit>().triggerBriefing();
    _day.load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocProvider.value(
      value: _day,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.briefingTitle),
          actions: [IconButton(tooltip: l10n.briefingRefresh, onPressed: _refresh, icon: const Icon(Icons.refresh))],
        ),
        body: Column(
          children: [
            PipLedge(
              idleLine: l10n.ledgeBriefingIdle,
              suggestions: [
                PipSuggestion(l10n.chipWhatsUrgent, l10n.queryWhatsUrgent),
                PipSuggestion(l10n.chipWhatDidIMiss, l10n.queryWhatDidIMiss),
                PipSuggestion(l10n.chipPlanMyDay, l10n.queryPlanMyDay),
              ],
            ),
            Expanded(
              child: BlocBuilder<DayBriefingCubit, DayBriefingState>(
                builder: (context, state) {
                  final b = state.briefing;
                  return AnimatedSwitcher(
                    duration: AppMotionTokens.resolveDuration(context, AppMotionTokens.medium),
                    child: b == null
                        ? const Center(key: ValueKey('loading'), child: CircularProgressIndicator())
                        : _BriefingBody(key: const ValueKey('body'), briefing: b, state: state),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BriefingBody extends StatelessWidget {
  final DayBriefing briefing;
  final DayBriefingState state;

  const _BriefingBody({super.key, required this.briefing, required this.state});

  void _snooze(BuildContext context, TaskItem task) {
    context.read<DayBriefingCubit>().snooze(task);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.briefingSnoozed)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final day = context.read<DayBriefingCubit>();
    final pip = context.read<PipStageCubit>();
    return ListView(
      padding: EdgeInsets.fromLTRB(t.space.lg, t.space.sm, t.space.lg, t.space.xxl),
      children: [
        BriefingHeader(date: briefing.date, name: state.name),
        SizedBox(height: t.space.md),
        const BriefingSummary(),
        SizedBox(height: t.space.md),
        BriefingStats(briefing: briefing, loadingEmail: state.loadingEmail),
        if (briefing.hasUrgent)
          BriefingUrgent(briefing: briefing, onToggle: day.toggleTask, onSnooze: (task) => _snooze(context, task)),
        BriefingTimeline(items: briefing.timeline),
        BriefingTasks(tasks: briefing.openTasks, today: briefing.date, onToggle: day.toggleTask),
        BriefingInbox(
          emails: briefing.emails,
          loading: state.loadingEmail,
          onReply: (e) => pip.handleQuery(e.from.isEmpty
              ? context.l10n.briefingReplyQueryNoSender(e.subject)
              : context.l10n.briefingReplyQuery(e.from, e.subject)),
        ),
      ],
    );
  }
}
