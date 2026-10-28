import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/services/pip_audio_coordinator.dart';
import '../../../../core/theme/pip_theme.dart';
import '../cubit/pip_stage_cubit.dart';
import 'pip_screen_context.dart';

/// The one way to give Pip an instruction, shared by every tab: a text field
/// and a mic. Commands carry the current screen as context.
class PipCommandBar extends StatefulWidget {
  final String hint;

  const PipCommandBar({super.key, required this.hint});

  @override
  State<PipCommandBar> createState() => _PipCommandBarState();
}

class _PipCommandBarState extends State<PipCommandBar> {
  final TextEditingController _text = TextEditingController();
  final PipAudioCoordinator _audio = getIt<PipAudioCoordinator>();

  void _send(String raw) {
    final query = raw.trim();
    if (query.isEmpty) return;
    _text.clear();
    FocusScope.of(context).unfocus();
    context.read<PipStageCubit>().handleQuery(PipScreenContext.withContext(query));
  }

  Future<void> _toggleMic() async {
    HapticFeedback.selectionClick();
    if (_audio.isActiveListening) return _audio.stopListening();
    final cubit = context.read<PipStageCubit>();
    await _audio.startActiveListening(onQuery: (words) => cubit.handleQuery(PipScreenContext.withContext(words)));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    return Container(
      padding: EdgeInsets.fromLTRB(t.space.lg, t.space.xs, t.space.xs, t.space.xs),
      decoration: BoxDecoration(
        color: t.colors.chip,
        borderRadius: BorderRadius.circular(t.space.pill),
        border: Border.all(color: t.colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _text,
              textInputAction: TextInputAction.send,
              onSubmitted: _send,
              decoration: InputDecoration(
                hintText: widget.hint,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _text,
            builder: (context, value, _) => value.text.trim().isEmpty
                ? _MicButton(audio: _audio, onTap: _toggleMic)
                : IconButton.filled(
                    tooltip: l10n.commandSend,
                    onPressed: () => _send(_text.text),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final PipAudioCoordinator audio;
  final VoidCallback onTap;

  const _MicButton({required this.audio, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: audio,
      builder: (context, _) {
        final on = audio.isActiveListening;
        return IconButton.filled(
          tooltip: on ? l10n.commandMicStop : l10n.commandMicStart,
          style: IconButton.styleFrom(backgroundColor: on ? t.colors.info : t.colors.accent),
          onPressed: onTap,
          icon: Icon(on ? Icons.graphic_eq : Icons.mic_none, color: t.colors.onAccent),
        );
      },
    );
  }
}
