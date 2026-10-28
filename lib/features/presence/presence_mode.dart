import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How much Pip speaks up on its own.
enum PresenceMode {
  /// Normal companion: greetings, idle sounds, spoken replies.
  casual,

  /// Deep work: no idle sounds or greetings; Pip only talks when spoken to.
  focus,

  /// Quiet through the day; Pip saves things up for a briefing.
  briefing,

  /// Do not disturb: no sounds, no spoken voice. Pip still works on screen.
  quiet,
}

/// The current mode and what it allows. One place every noisy feature asks.
class PresenceSettings extends ChangeNotifier {
  PresenceSettings._();
  static final PresenceSettings instance = PresenceSettings._();

  static const String _key = 'pip_presence_mode';

  PresenceMode _mode = PresenceMode.casual;
  PresenceMode get mode => _mode;

  Future<void> load() async {
    final saved = (await SharedPreferences.getInstance()).getString(_key);
    _mode = PresenceMode.values.asNameMap()[saved] ?? PresenceMode.casual;
    notifyListeners();
  }

  Future<void> setMode(PresenceMode mode) async {
    _mode = mode;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setString(_key, mode.name);
  }

  /// Quiet on/off (the tray's Do Not Disturb); returns the new mode.
  Future<PresenceMode> toggleQuiet() async {
    await setMode(_mode == PresenceMode.quiet ? PresenceMode.casual : PresenceMode.quiet);
    return _mode;
  }

  /// Short robot sounds when you interact (taps, listening, replies).
  bool get allowSounds => _mode != PresenceMode.quiet;

  /// Pip reading replies out loud.
  bool get allowSpeech => _mode != PresenceMode.quiet;

  /// Things Pip starts by itself: greetings, idle chirps, wandering noises.
  bool get allowProactive => _mode == PresenceMode.casual;
}
