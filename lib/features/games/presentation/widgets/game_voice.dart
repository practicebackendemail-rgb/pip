import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/pip_audio_coordinator.dart';
import 'arcade.dart';

/// Mic button for playing by voice ("column 5", "rock", "yes").
class GameMicButton extends StatefulWidget {
  final ValueChanged<String> onHeard;
  final Color color;
  const GameMicButton({super.key, required this.onHeard, this.color = Arcade.teal});

  @override
  State<GameMicButton> createState() => _GameMicButtonState();
}

class _GameMicButtonState extends State<GameMicButton> {
  bool _listening = false;

  Future<void> _listen() async {
    final audio = getIt<PipAudioCoordinator>();
    if (_listening) {
      await audio.stopListening();
      if (mounted) setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    await audio.startActiveListening(onQuery: (q) {
      if (mounted) setState(() => _listening = false);
      widget.onHeard(q);
    });
  }

  @override
  Widget build(BuildContext context) => ArcadeButton(
        label: _listening ? 'Listening' : 'Say it',
        icon: _listening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
        color: widget.color,
        onPressed: _listen,
      );
}

/// "column five", "col 3", "the 7th" → 0-based column, or null.
int? parseColumn(String text, int cols) {
  // Ordinals first, so "the third one" isn't read as one.
  const words = {'first': 1, 'second': 2, 'third': 3, 'fourth': 4, 'fifth': 5, 'sixth': 6, 'seventh': 7, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6, 'seven': 7};
  final t = text.toLowerCase();
  final digit = RegExp(r'\b([1-9])\b|\b([1-9])(st|nd|rd|th)\b').firstMatch(t);
  int? n = digit == null ? null : int.parse(digit.group(1) ?? digit.group(2)!);
  if (n == null) {
    for (final e in words.entries) {
      if (RegExp('\\b${e.key}\\b').hasMatch(t)) {
        n = e.value;
        break;
      }
    }
  }
  if (n == null || n < 1 || n > cols) return null;
  return n - 1;
}
