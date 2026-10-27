import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Cross-platform robotic sound effects for Pip adhering to the Ben Burtt WALL-E formula.
/// Blends tactile mechanical foley with warm analog pitch-modulated sweeps and servo textures.
class PipSfxService {
  PipSfxService._();

  static final AudioPlayer _player = AudioPlayer()
    ..setReleaseMode(ReleaseMode.stop)
    ..setPlayerMode(PlayerMode.lowLatency);

  static Future<void> _playAsset(String path) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(path), volume: 1.0);
    } catch (e) {
      debugPrint("PipSfxService play error ($path): $e");
    }
  }

  /// WALL-E inquisitive ascending frequency glissando with harmonic resonance
  static Future<void> chirp() async {
    await _playAsset('audio/pip_chirp.wav');
  }

  /// Cheerful ascending tri-tone melodic warble with micro-servo vibrato
  static Future<void> happy() async {
    await _playAsset('audio/pip_happy.wav');
  }

  /// Inquisitive two-tone ring-modulated pitch oscillation
  static Future<void> thinking() async {
    await _playAsset('audio/pip_thinking.wav');
  }

  /// Camera shutter & solenoid tactile contact click
  static Future<void> blip() async {
    await _playAsset('audio/pip_blip.wav');
  }

  /// Soft mechanical power-down descent for sleep mode
  static Future<void> sleep() async {
    await _playAsset('audio/pip_sleep.wav');
  }
}
