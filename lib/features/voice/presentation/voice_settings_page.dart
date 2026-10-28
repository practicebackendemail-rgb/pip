import 'package:flutter/material.dart';
import '../../../core/di/injection.dart';
import '../../../core/localization/l10n_extension.dart';
import '../../../core/services/pip_audio_coordinator.dart';
import '../../../core/theme/pip_theme.dart';
import '../../presence/presence_picker.dart';
import '../data/voice_settings.dart';
import '../domain/speech_transcriber.dart';
import 'voice_try_it.dart';

/// Settings → Voice: recognition engine and hands-free behaviour.
class VoiceSettingsPage extends StatelessWidget {
  const VoiceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final settings = VoiceSettings.instance;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.voiceSettingsTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListenableBuilder(
            listenable: settings,
            builder: (context, _) => ListView(
              padding: EdgeInsets.all(t.space.lg),
              children: [
                _Heading(l10n.voiceEngineHeading),
                _EngineChoice(selected: settings.engine, onChanged: (e) => settings.update(engine: e)),
                SizedBox(height: t.space.md),
                VoiceTryIt(audio: getIt<PipAudioCoordinator>()),
                _Heading(l10n.voiceHandsFreeHeading),
                _Toggle(
                  title: l10n.voiceConversationMode,
                  detail: l10n.voiceConversationModeDetail,
                  value: settings.conversationMode,
                  onChanged: (v) => settings.update(conversationMode: v),
                ),
                _Toggle(
                  title: l10n.voiceOpenMic,
                  detail: l10n.voiceOpenMicDetail,
                  value: settings.openMic,
                  onChanged: (v) => settings.update(openMic: v),
                ),
                _Toggle(
                  title: l10n.voiceWakeWord,
                  detail: l10n.voiceWakeWordDetail,
                  value: settings.wakeWord,
                  onChanged: (v) => settings.update(wakeWord: v),
                ),
                _Heading(l10n.presenceHeading),
                const PresencePicker(),
                SizedBox(height: t.space.lg),
                Text(l10n.voicePrivacyNote, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(top: t.space.xl, bottom: t.space.sm),
      child: Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _EngineChoice extends StatelessWidget {
  final SpeechEngine selected;
  final ValueChanged<SpeechEngine> onChanged;

  const _EngineChoice({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final detail = selected == SpeechEngine.onDevice ? l10n.voiceEngineFastDetail : l10n.voiceEngineAccurateDetail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<SpeechEngine>(
          segments: [
            ButtonSegment(value: SpeechEngine.onDevice, label: Text(l10n.voiceEngineFast), icon: const Icon(Icons.bolt)),
            ButtonSegment(
                value: SpeechEngine.geminiAudio, label: Text(l10n.voiceEngineAccurate), icon: const Icon(Icons.hearing)),
          ],
          selected: {selected},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
        SizedBox(height: context.tokens.space.sm),
        Text(detail, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  final String title;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Toggle({required this.title, required this.detail, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(detail, style: Theme.of(context).textTheme.bodySmall),
      value: value,
      onChanged: onChanged,
    );
  }
}
