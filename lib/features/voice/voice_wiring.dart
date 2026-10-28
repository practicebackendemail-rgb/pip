import '../../core/services/llm_registry_service.dart';
import '../../core/services/pip_audio_coordinator.dart';
import '../../core/services/voice_service.dart';
import 'data/gemini_audio_transcriber.dart';
import 'data/gemini_voice_capture.dart';
import 'data/utterance_recorder.dart';
import 'data/voice_settings.dart';

/// Connects the voice pieces at startup:
/// - gives the audio coordinator accurate (Gemini audio) listening,
/// - tells it when Pip starts and stops talking, so the mic never hears
///   Pip and conversation mode can reopen it for a follow-up,
/// - applies the hands-free settings now and whenever they change.
class VoiceWiring {
  final PipAudioCoordinator audio;
  final VoiceService voice;
  final LlmRegistryService llm;
  VoiceStatus _lastStatus = VoiceStatus.idle;

  VoiceWiring({required this.audio, required this.voice, required this.llm});

  Future<void> start() async {
    await VoiceSettings.instance.load();
    audio.geminiCapture = GeminiVoiceCapture(
      recorder: UtteranceRecorder(),
      transcriber: GeminiAudioTranscriber(apiKey: () => llm.geminiKey, model: () => llm.chatModel('gemini')),
    );
    voice.addListener(_onVoiceStatus);
    VoiceSettings.instance.addListener(audio.applySettings);
    audio.applySettings();
  }

  void _onVoiceStatus() {
    final status = voice.status;
    if (status == _lastStatus) return;
    _lastStatus = status;
    if (status == VoiceStatus.speaking) {
      audio.onPlaybackStarted();
    } else if (status == VoiceStatus.idle) {
      audio.onPlaybackFinished();
    }
  }

  void dispose() {
    voice.removeListener(_onVoiceStatus);
    VoiceSettings.instance.removeListener(audio.applySettings);
  }
}
