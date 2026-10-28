import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/pip_audio_coordinator.dart';
import '../../../../core/theme/pip_theme.dart';

/// What Pip is hearing, shown live like a subtitle while you talk, then
/// faded away. Never kept: this is not a message, just feedback.
class HeardCaption extends StatelessWidget {
  const HeardCaption({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final audio = getIt<PipAudioCoordinator>();
    return ListenableBuilder(
      listenable: audio,
      builder: (context, _) {
        final words = audio.lastRecognizedWords.trim();
        final visible = audio.isActiveListening && words.isNotEmpty;
        return AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: context.motion(t.motion.fast),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: EdgeInsets.symmetric(horizontal: t.space.md, vertical: t.space.xs + 2),
            decoration: BoxDecoration(
              color: t.colors.background.withValues(alpha: .72),
              borderRadius: BorderRadius.circular(t.space.pill),
            ),
            child: Text(
              visible ? '“$words…”' : '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: t.colors.text, fontStyle: FontStyle.italic),
            ),
          ),
        );
      },
    );
  }
}
