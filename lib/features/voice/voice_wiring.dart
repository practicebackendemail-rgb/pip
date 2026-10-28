import 'dart:async';
import 'dart:io';
import '../../core/services/llm_registry_service.dart';
import '../../core/services/pip_profile_service.dart';
import '../../core/services/pip_audio_coordinator.dart';
import '../companion/presentation/cubit/pip_stage_state.dart';
import 'data/gemini_audio_transcriber.dart';
import 'data/gemini_voice_capture.dart';
import 'data/utterance_recorder.dart';
import 'data/voice_settings.dart';

/// Connects the voice pieces at startup:
/// - gives the audio coordinator accurate (Gemini audio) listening,
/// - tells it when Pip's reply to you starts and finishes appearing (Pip
///   doesn't talk; it types), so the mic never picks up Pip's sounds and
///   conversation mode can reopen it for a follow-up,
/// - applies the hands-free settings now and whenever they change.
class VoiceWiring {
  final PipAudioCoordinator audio;
  final Stream<PipStageState> stage;
  final LlmRegistryService llm;
  StreamSubscription<PipStageState>? _stageSub;
  bool _awaitingReply = false;
  bool _showingReply = false;

  VoiceWiring({required this.audio, required this.stage, required this.llm});

  Future<void> start() async {
    await VoiceSettings.instance.load();
    audio.geminiCapture = GeminiVoiceCapture(
      recorder: UtteranceRecorder(),
      transcriber: GeminiAudioTranscriber(
        apiKey: () => llm.geminiKey,
        model: () => llm.chatModel('gemini'),
        speakerName: () async => await PipProfileService.userName() ?? '',
        locale: () => Platform.localeName,
      ),
    );
    _stageSub = stage.listen(onStage);
    VoiceSettings.instance.addListener(audio.applySettings);
    audio.applySettings();
  }

  /// Only replies to a request count (not greetings), so the mic never opens
  /// on its own.
  void onStage(PipStageState s) {
    if (s.isLoading) {
      _awaitingReply = true;
    } else if (_awaitingReply && s.isTypewriting && !_showingReply) {
      _showingReply = true;
      audio.onPlaybackStarted();
    } else if (_showingReply && !s.isTypewriting) {
      _showingReply = false;
      _awaitingReply = false;
      audio.onPlaybackFinished();
    }
  }

  void dispose() {
    _stageSub?.cancel();
    VoiceSettings.instance.removeListener(audio.applySettings);
  }
}
