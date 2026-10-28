import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/localization/l10n_extension.dart';
import '../../../core/services/pip_audio_coordinator.dart';
import '../../../core/theme/pip_theme.dart';

/// "Try it": listen once with the chosen engine and show what was heard,
/// with a live mic meter. Restores the app's normal command handler after.
class VoiceTryIt extends StatefulWidget {
  final PipAudioCoordinator audio;

  const VoiceTryIt({super.key, required this.audio});

  @override
  State<VoiceTryIt> createState() => _VoiceTryItState();
}

class _VoiceTryItState extends State<VoiceTryIt> {
  final ValueNotifier<String?> _heard = ValueNotifier(null);

  Future<void> _try() async {
    final audio = widget.audio;
    final previous = audio.onCommandReceived;
    _heard.value = null;
    audio.lastError.value = null;
    await audio.startActiveListening(onQuery: (text) {
      _heard.value = text;
      audio.onCommandReceived = previous;
    });
  }

  @override
  void dispose() {
    _heard.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final audio = widget.audio;
    return Container(
      padding: EdgeInsets.all(t.space.md),
      decoration: BoxDecoration(
        color: t.colors.card,
        borderRadius: BorderRadius.circular(t.space.radius),
        border: Border.all(color: t.colors.border),
      ),
      child: ListenableBuilder(
        listenable: Listenable.merge([audio, _heard, audio.lastError]),
        builder: (context, _) {
          final listening = audio.isActiveListening;
          final message = audio.lastError.value ??
              (_heard.value == null
                  ? (listening ? l10n.voiceListening : null)
                  : (_heard.value!.isEmpty ? l10n.voiceHeardNothing : l10n.voiceHeard(_heard.value!)));
          return Row(
            children: [
              FilledButton.icon(
                onPressed: listening ? audio.stopListening : _try,
                icon: Icon(listening ? Icons.stop : Icons.mic_none),
                label: Text(listening ? l10n.voiceListening : l10n.voiceTryIt),
              ),
              SizedBox(width: t.space.md),
              Expanded(
                child: listening && audio.geminiCapture != null
                    ? _MicMeter(level: audio.geminiCapture!.level)
                    : Text(message ?? '', style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MicMeter extends StatelessWidget {
  final ValueListenable<double> level;
  const _MicMeter({required this.level});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ValueListenableBuilder<double>(
      valueListenable: level,
      builder: (context, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(t.space.pill),
        child: LinearProgressIndicator(
          value: v,
          minHeight: t.space.sm,
          backgroundColor: t.colors.chip,
          color: t.colors.accent,
        ),
      ),
    );
  }
}
