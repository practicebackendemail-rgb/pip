import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/speech_transcriber.dart';

/// How Pip listens. Loaded once at startup; screens listen for changes.
class VoiceSettings extends ChangeNotifier {
  VoiceSettings._();
  static final VoiceSettings instance = VoiceSettings._();

  static const _engineKey = 'voice_engine';
  static const _conversationKey = 'voice_conversation_mode';
  static const _wakeWordKey = 'voice_wake_word';
  static const _openMicKey = 'voice_open_mic';

  SpeechEngine engine = SpeechEngine.onDevice;

  /// After Pip answers, keep the mic open briefly for a follow-up.
  bool conversationMode = true;

  /// Listen for "Hey Pip" in the background.
  bool wakeWord = false;

  /// While the app is open, any speech to Pip counts; no wake word needed.
  bool openMic = false;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    engine = SpeechEngine.values.asNameMap()[p.getString(_engineKey)] ?? SpeechEngine.onDevice;
    conversationMode = p.getBool(_conversationKey) ?? true;
    wakeWord = p.getBool(_wakeWordKey) ?? false;
    openMic = p.getBool(_openMicKey) ?? false;
    notifyListeners();
  }

  Future<void> update({SpeechEngine? engine, bool? conversationMode, bool? wakeWord, bool? openMic}) async {
    final p = await SharedPreferences.getInstance();
    if (engine != null) {
      this.engine = engine;
      await p.setString(_engineKey, engine.name);
    }
    if (conversationMode != null) {
      this.conversationMode = conversationMode;
      await p.setBool(_conversationKey, conversationMode);
    }
    if (wakeWord != null) {
      this.wakeWord = wakeWord;
      await p.setBool(_wakeWordKey, wakeWord);
    }
    if (openMic != null) {
      this.openMic = openMic;
      await p.setBool(_openMicKey, openMic);
    }
    notifyListeners();
  }

  /// Background listening is on when either hands-free mode is enabled.
  bool get handsFree => wakeWord || openMic;
}
