import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/presence/presence_mode.dart';

enum PipSound { chirp, happy, thinking, blip, sleep, laugh, sad, excited, unsure, listen }

/// Pip's little robot sounds.
///
/// Each sound has its own player, loaded once and replayed from the start,
/// so a sound never waits on a file load (the old single player swapped
/// files and, in low-latency mode, often played nothing). Sounds mix with
/// speech instead of taking audio focus, and idle sounds are softer and
/// stay quiet at night.
class PipSfxService {
  PipSfxService._();

  static bool enableAudio = true;

  /// Sounds for Pip's own idle acts (hops, waves, naps). Off at night anyway.
  static bool idleSounds = true;

  static const Map<PipSound, String> _files = {
    PipSound.chirp: 'audio/pip_chirp.wav',
    PipSound.happy: 'audio/pip_happy.wav',
    PipSound.thinking: 'audio/pip_thinking.wav',
    PipSound.blip: 'audio/pip_blip.wav',
    PipSound.sleep: 'audio/pip_sleep.wav',
    PipSound.laugh: 'audio/pip_laugh.wav',
    PipSound.sad: 'audio/pip_sad.wav',
    PipSound.excited: 'audio/pip_excited.wav',
    PipSound.unsure: 'audio/pip_unsure.wav',
    PipSound.listen: 'audio/pip_listen.wav',
  };

  /// The sound for a reply emotion from the reply contract. Calm and
  /// unknown emotions get the plain chirp.
  static PipSound forEmotion(String emotion) => switch (emotion) {
        'happy' || 'proud' => PipSound.happy,
        'excited' || 'mischievous' => PipSound.excited,
        'laughing' => PipSound.laugh,
        'sad' || 'sulky' => PipSound.sad,
        'unsure' => PipSound.unsure,
        'sleepy' => PipSound.sleep,
        _ => PipSound.chirp,
      };

  static final Map<PipSound, AudioPlayer> _players = {};
  static Future<void>? _loading;

  /// Loads every sound once. Safe to call repeatedly; play calls await it.
  static Future<void> preload() => _loading ??= _load();

  /// Each sound loads on its own, so one failure doesn't leave the rest
  /// without players.
  static Future<void> _load() async {
    for (final sound in _files.keys) {
      await _loadOne(sound);
    }
  }

  static Future<AudioPlayer?> _loadOne(PipSound sound) async {
    if (_players[sound] case final existing?) return existing;
    final player = AudioPlayer(playerId: 'pip_${sound.name}');
    try {
      try {
        await player.setAudioContext(AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build());
      } catch (e) {
        // Some devices reject the mixing context; the default still plays.
        debugPrint('PipSfxService audio context (${sound.name}) not applied: $e');
      }
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setSource(AssetSource(_files[sound]!));
      return _players[sound] = player;
    } catch (e) {
      debugPrint('PipSfxService could not load ${sound.name}: $e');
      await player.dispose();
      return null;
    }
  }

  /// Last playback failure, shown by the Settings "Test sound" button.
  static String? lastError;

  /// Plays [sound]. Returns true if playback started. Uses the preloaded
  /// player, and if that fails, retries once with a fresh player (the plain,
  /// most compatible path) so one broken player never silences Pip.
  static Future<bool> play(PipSound sound, {double volume = 1.0}) async {
    if (!enableAudio || !PresenceSettings.instance.allowSounds) return false;
    try {
      await preload();
      // A sound that failed to preload gets another chance now.
      final player = _players[sound] ?? await _loadOne(sound);
      if (player == null) throw StateError('player not loaded');
      await player.stop();
      await player.setVolume(volume);
      await player.resume();
      lastError = null;
      return true;
    } catch (e) {
      debugPrint('PipSfxService preloaded play failed (${sound.name}): $e; retrying with a fresh player');
    }
    try {
      final fresh = AudioPlayer();
      await fresh.setReleaseMode(ReleaseMode.release);
      await fresh.play(AssetSource(_files[sound]!), volume: volume);
      lastError = null;
      return true;
    } catch (e) {
      lastError = '$e';
      debugPrint('PipSfxService play error (${sound.name}): $e');
      return false;
    }
  }

  /// Whether an idle (unprompted) sound may play at [hour].
  static bool idleSoundAllowed(int hour) =>
      enableAudio && idleSounds && PresenceSettings.instance.allowProactive && hour >= 7 && hour < 22;

  /// Softer sound for something Pip does on its own.
  static Future<void> idle(PipSound sound) async {
    if (!idleSoundAllowed(DateTime.now().hour)) return;
    await play(sound, volume: .45);
  }

  static Future<void> chirp() => play(PipSound.chirp);
  static Future<void> happy() => play(PipSound.happy);
  static Future<void> thinking() => play(PipSound.thinking);
  static Future<void> blip() => play(PipSound.blip);
  static Future<void> sleep() => play(PipSound.sleep);
  static Future<void> laugh() => play(PipSound.laugh);
  static Future<void> sad() => play(PipSound.sad);
  static Future<void> excited() => play(PipSound.excited);
  static Future<void> unsure() => play(PipSound.unsure);
  static Future<void> listen() => play(PipSound.listen);

  static const String _enabledKey = 'pip_sfx_enabled';

  /// Restores the user's sound-effects setting (on by default).
  static Future<void> loadSetting() async {
    final prefs = await SharedPreferences.getInstance();
    enableAudio = prefs.getBool(_enabledKey) ?? true;
  }

  static Future<void> setEnabled(bool enabled) async {
    enableAudio = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }
}
