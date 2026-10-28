import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/theme/pip_theme.dart';
import '../../../../widgets/companion/pip_action_confirmation_banner.dart';
import '../../../../widgets/pip_companion.dart';
import '../../../../widgets/pip_text_switcher.dart';
import '../cubit/pip_stage_cubit.dart';
import '../cubit/pip_stage_state.dart';
import 'pip_screen_context.dart';

/// A suggestion chip: a short label, and the instruction it sends to Pip.
class PipSuggestion {
  final String label;
  final String query;

  const PipSuggestion(this.label, this.query);
}

/// Pip, sitting at the top of a screen while it works there. Shows Pip's
/// current line (one line, replaced, never a history), suggestions for this
/// screen, and any confirmation Pip is waiting for.
class PipLedge extends StatelessWidget {
  /// What Pip says when it has nothing new to say on this screen.
  final String idleLine;
  final List<PipSuggestion> suggestions;

  const PipLedge({super.key, required this.idleLine, this.suggestions = const []});

  static const String heroTag = 'pip-ledge';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.colors.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(t.space.md, t.space.sm, t.space.md, t.space.sm),
        child: BlocBuilder<PipStageCubit, PipStageState>(
          buildWhen: (a, b) =>
              a.currentMood != b.currentMood ||
              a.speechText != b.speechText ||
              a.isLoading != b.isLoading ||
              a.pendingActionConfirmation != b.pendingActionConfirmation,
          builder: (context, state) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Hero(tag: heroTag, child: PipDeskCompanion(mood: state.currentMood, width: 76, height: 57)),
                  SizedBox(width: t.space.sm),
                  Expanded(child: _Line(text: _line(context, state))),
                ],
              ),
              if (state.pendingActionConfirmation != null)
                PipActionConfirmationBanner(
                  confirmation: state.pendingActionConfirmation!,
                  onConfirm: context.read<PipStageCubit>().confirmPendingAction,
                  onCancel: context.read<PipStageCubit>().cancelPendingAction,
                )
              else if (suggestions.isNotEmpty)
                _Chips(suggestions: suggestions),
            ],
          ),
        ),
      ),
    );
  }

  String _line(BuildContext context, PipStageState state) {
    if (state.isLoading) return context.l10n.pipThinking;
    return state.speechText.trim().isNotEmpty ? state.speechText : idleLine;
  }
}

class _Line extends StatelessWidget {
  final String text;
  const _Line({required this.text});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.space.md, vertical: t.space.sm),
      decoration: BoxDecoration(
        color: t.colors.chip,
        border: Border.all(color: t.colors.border),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(t.space.radius),
          topRight: Radius.circular(t.space.radius),
          bottomRight: Radius.circular(t.space.radius),
          bottomLeft: Radius.circular(t.space.xs),
        ),
      ),
      child: Semantics(
        liveRegion: true,
        child: PipTextSwitcher(
          text: text,
          builder: (context, s) => Text(s, maxLines: 3, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  final List<PipSuggestion> suggestions;
  const _Chips({required this.suggestions});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final cubit = context.read<PipStageCubit>();
    return Padding(
      padding: EdgeInsets.only(top: t.space.sm),
      child: Wrap(
        spacing: t.space.sm,
        runSpacing: t.space.xs,
        children: [
          for (final s in suggestions)
            ActionChip(
              label: Text(s.label),
              onPressed: () => cubit.handleQuery(PipScreenContext.withContext(s.query)),
            ),
        ],
      ),
    );
  }
}
