import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/pip_theme.dart';
import '../../features/companion/presentation/cubit/pip_stage_cubit.dart';
import '../../features/companion/presentation/cubit/pip_stage_state.dart';
import '../pip_companion.dart';
import '../pip_text_switcher.dart';
import 'pip_action_confirmation_banner.dart';

/// A small Pip that lives on any screen. It is the same Pip as the home
/// stage (same cubit, tools, memory and mood), so asking it here does the
/// work for you while the screen's own controls stay available.
class MiniPipAssistant extends StatefulWidget {
  /// Shown in the empty field, e.g. 'Ask Pip: "wake me at 6:30 on weekdays"'.
  final String hint;

  /// Tells Pip where the user is, so short requests like "6:30 weekdays"
  /// are understood in context.
  final String screenContext;

  const MiniPipAssistant({super.key, required this.hint, required this.screenContext});

  @override
  State<MiniPipAssistant> createState() => _MiniPipAssistantState();
}

class _MiniPipAssistantState extends State<MiniPipAssistant> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    _controller.clear();
    FocusScope.of(context).unfocus();
    context.read<PipStageCubit>().handleQuery('(${widget.screenContext}) $query');
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PipStageCubit, PipStageState>(
      buildWhen: (a, b) =>
          a.currentMood != b.currentMood ||
          a.speechText != b.speechText ||
          a.isLoading != b.isLoading ||
          a.pendingActionConfirmation != b.pendingActionConfirmation,
      builder: (context, state) {
        final cubit = context.read<PipStageCubit>();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(PipSpace.md),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        PipDeskCompanion(mood: state.currentMood, width: 92, height: 68),
                        const SizedBox(width: PipSpace.sm),
                        Expanded(child: _Speech(state: state)),
                      ],
                    ),
                    const SizedBox(height: PipSpace.sm),
                    _AskField(controller: _controller, hint: widget.hint, busy: state.isLoading, onSend: _send),
                  ],
                ),
              ),
            ),
            if (state.pendingActionConfirmation != null)
              PipActionConfirmationBanner(
                confirmation: state.pendingActionConfirmation!,
                onConfirm: cubit.confirmPendingAction,
                onCancel: cubit.cancelPendingAction,
              ),
          ],
        );
      },
    );
  }
}

class _Speech extends StatelessWidget {
  final PipStageState state;

  const _Speech({required this.state});

  @override
  Widget build(BuildContext context) {
    final text = state.isLoading
        ? 'Thinking…'
        : (state.speechText.isNotEmpty ? state.speechText : 'I can set these for you, or you can do it yourself below.');
    return PipTextSwitcher(
      text: text,
      builder: (context, t) => Text(
        t,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: PipColors.ink),
      ),
    );
  }
}

class _AskField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool busy;
  final VoidCallback onSend;

  const _AskField({required this.controller, required this.hint, required this.busy, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: !busy,
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => onSend(),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        suffixIcon: IconButton(
          tooltip: 'Ask Pip',
          icon: const Icon(Icons.arrow_upward_rounded, color: PipColors.amber),
          onPressed: busy ? null : onSend,
        ),
      ),
    );
  }
}
