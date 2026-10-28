import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/event_log.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/theme/pip_theme.dart';
import '../cubit/pip_stage_cubit.dart';
import '../cubit/pip_stage_state.dart';
import '../widgets/pip_ledge.dart';
import '../widgets/pip_screen_context.dart';

/// Your day, with Pip on the ledge reading it out and ready for follow-ups
/// ("what's urgent?", "draft a reply to Sam"). Briefs you on open if needed.
class BriefingScreen extends StatefulWidget {
  const BriefingScreen({super.key});

  @override
  State<BriefingScreen> createState() => _BriefingScreenState();
}

class _BriefingScreenState extends State<BriefingScreen> {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.briefingTitle),
        actions: [
          IconButton(
            tooltip: l10n.briefingRefresh,
            onPressed: context.read<PipStageCubit>().triggerBriefing,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          PipLedge(
            idleLine: l10n.ledgeBriefingIdle,
            suggestions: [
              PipSuggestion(l10n.chipReadIt, l10n.queryReadIt),
              PipSuggestion(l10n.chipWhatsUrgent, l10n.queryWhatsUrgent),
              PipSuggestion(l10n.chipWhatDidIMiss, l10n.queryWhatDidIMiss),
            ],
          ),
          Expanded(
            child: BlocBuilder<PipStageCubit, PipStageState>(
              buildWhen: (a, b) => a.briefingContent != b.briefingContent || a.isLoading != b.isLoading,
              builder: (context, state) {
                if (state.briefingContent.trim().isEmpty) {
                  return Center(
                    child: state.isLoading
                        ? const CircularProgressIndicator()
                        : Text(l10n.briefingEmpty, style: Theme.of(context).textTheme.bodySmall),
                  );
                }
                return Markdown(
                  data: state.briefingContent,
                  padding: EdgeInsets.all(t.space.lg),
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    strong: TextStyle(color: t.colors.accent, fontWeight: FontWeight.w700),
                    listBullet: TextStyle(color: t.colors.accent),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
