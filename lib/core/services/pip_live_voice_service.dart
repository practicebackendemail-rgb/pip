import 'package:flutter/foundation.dart';

/// Status of the live voice prototype.
enum LiveSessionStatus { disconnected, connecting, active, speaking, interrupted }

/// PLACEHOLDER / UNBUILT PROTOTYPE:
/// This class represents an unbuilt prototype for bidirectional Gemini Live WebSocket streaming.
/// Per Phase 8 Option B of the Remediation Plan, live voice streaming is deferred and NOT built.
///
/// Current production voice interaction is exclusively powered by [PipAudioCoordinator],
/// which coordinates native Speech-to-Text (`speech_to_text`), LLM chat queries via [PipStageCubit],
/// and robotic audio SFX / typewriter speech playback.
class PipLiveVoicePlaceholder extends ChangeNotifier {
  static const bool isImplemented = false;

  LiveSessionStatus _status = LiveSessionStatus.disconnected;
  String _currentVoiceStyle = 'normal';

  LiveSessionStatus get status => _status;
  bool get isBargeInActive => false;
  String get currentVoiceStyle => _currentVoiceStyle;

  final void Function()? onBargeIn;

  PipLiveVoicePlaceholder({this.onBargeIn});

  /// Placeholder connect method. Explicitly logs that live streaming is unbuilt.
  Future<void> connect({required String apiKey, String model = 'gemini-2.0-flash-exp'}) async {
    debugPrint('PipLiveVoicePlaceholder: Live WebSocket audio streaming is not built (deferred).');
    _status = LiveSessionStatus.disconnected;
    notifyListeners();
  }

  /// Placeholder audio chunk consumer.
  void sendAudioChunk(Uint8List pcmBytes) {
    // Unbuilt: real implementation requires bidirectional WebSocket audio stream.
  }

  void updateVoiceStyle(String style) {
    _currentVoiceStyle = style;
    notifyListeners();
  }

  Future<void> disconnect() async {
    _status = LiveSessionStatus.disconnected;
    notifyListeners();
  }
}
