import 'package:shared_preferences/shared_preferences.dart';
import '../../../presence/presence_mode.dart';
import '../../../../core/services/voice_service.dart';

/// Pip's spoken voice: reads replies aloud through [VoiceService] (text to
/// speech) unless the user turned the voice off in Settings.
class PipVoiceOutput {
  static const String _key = 'pip_voice_enabled';

  final VoiceService? _service;
  late final Future<bool> _loaded = _load();
  bool? _enabled;

  PipVoiceOutput(this._service);

  /// Whether Pip speaks out loud. On by default.
  Future<bool> get enabled async => _enabled ?? await _loaded;

  Future<bool> _load() async {
    final prefs = await SharedPreferences.getInstance();
    return _enabled = prefs.getBool(_key) ?? true;
  }

  Future<void> setEnabled(bool on) async {
    _enabled = on;
    if (!on) await stop();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, on);
  }

  /// Speaks [text] if the voice is on. Never throws: a broken TTS engine
  /// leaves Pip silent but still working.
  Future<void> say(String text) async {
    final service = _service;
    if (service == null || text.trim().isEmpty || !await enabled) return;
    if (!PresenceSettings.instance.allowSpeech) return; // Quiet mode: words on screen only
    try {
      await service.speak(text);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _service?.stopSpeaking();
    } catch (_) {}
  }
}
