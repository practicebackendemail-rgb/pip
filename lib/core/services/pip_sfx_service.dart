import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Cross-platform robotic sound effects for Pip adhering to the Ben Burtt WALL-E formula.
/// Blends tactile mechanical foley with warm analog pitch-modulated sweeps and servo textures.
class PipSfxService {
  PipSfxService._();

  static AudioPlayer? _playerInstance;
  static bool _initAttempted = false;
  static bool enableAudio = true;

  static AudioPlayer? get _player {
    if (!enableAudio) return null;
    if (!_initAttempted) {
      _initAttempted = true;
      try {
        _playerInstance = AudioPlayer()
          ..setReleaseMode(ReleaseMode.stop)
          ..setPlayerMode(PlayerMode.lowLatency);
      } catch (e) {
        debugPrint("PipSfxService player init error (non-fatal): $e");
      }
    }
    return _playerInstance;
  }

  static Future<void> _playAsset(String path) async {
    if (!enableAudio) return;
    try {
      final p = _player;
      if (p == null) return;
      await p.stop();
      await p.play(AssetSource(path), volume: 1.0);
    } catch (e) {
      debugPrint("PipSfxService play error ($path): $e");
    }
  }

  /// WALL-E inquisitive ascending frequency glissando with harmonic resonance
  static Future<void> chirp() async {
    if (!enableAudio) return;
    await _playAsset('audio/pip_chirp.wav');
  }

  /// Cheerful ascending tri-tone melodic warble with micro-servo vibrato
  static Future<void> happy() async {
    if (!enableAudio) return;
    await _playAsset('audio/pip_happy.wav');
  }

  /// Inquisitive two-tone ring-modulated pitch oscillation
  static Future<void> thinking() async {
    if (!enableAudio) return;
    await _playAsset('audio/pip_thinking.wav');
  }

  /// Camera shutter & solenoid tactile contact click
  static Future<void> blip() async {
    if (!enableAudio) return;
    await _playAsset('audio/pip_blip.wav');
  }

  /// Soft mechanical power-down descent for sleep mode
  static Future<void> sleep() async {
    if (!enableAudio) return;
    await _playAsset('audio/pip_sleep.wav');
  }
}
