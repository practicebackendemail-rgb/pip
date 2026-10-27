import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../../core/theme/apple_theme.dart';
import '../pip_params.dart';
import '../pip_vector_painter.dart';

/// Lightweight entry point rendered exclusively inside Android floating overlay window.
class PipOverlayWidget extends StatefulWidget {
  const PipOverlayWidget({super.key});

  @override
  State<PipOverlayWidget> createState() => _PipOverlayWidgetState();
}

class _PipOverlayWidgetState extends State<PipOverlayWidget> {
  PipMood _mood = PipMood.idle;
  String _speech = '';
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is String) {
        try {
          final decoded = jsonDecode(data);
          if (decoded is Map<String, dynamic>) {
            setState(() {
              if (decoded.containsKey('mood')) {
                _mood = PipMood.values.firstWhere(
                  (m) => m.name == decoded['mood'],
                  orElse: () => PipMood.idle,
                );
              }
              if (decoded.containsKey('speech')) {
                _speech = decoded['speech'] as String? ?? '';
              }
              if (decoded.containsKey('isListening')) {
                _isListening = decoded['isListening'] as bool? ?? false;
              }
            });
          }
        } catch (_) {}
      }
    });
  }

  void _onTapPip() {
    // Tapping overlay triggers Push-to-Talk or returns to main app
    FlutterOverlayWindow.shareData(jsonEncode({'action': 'tap_listen'}));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: GestureDetector(
          onTap: _onTapPip,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: const Color(0xFF16181F).withValues(alpha: 0.90),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
              border: Border.all(
                color: _isListening ? AppleTheme.accentTeal : Colors.white24,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 90,
                  height: 68,
                  child: CustomPaint(
                    painter: PipVectorPainter(
                      lid: _mood == PipMood.sleepy ? 1.0 : (_mood == PipMood.thinking ? 0.3 : 0.0),
                      tilt: _mood == PipMood.unsure ? 18.0 : 14.0,
                      ledColor: _isListening ? AppleTheme.accentTeal : const Color(0xFF6FBF73),
                    ),
                  ),
                ),
                if (_isListening)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Listening...',
                      style: TextStyle(fontSize: 10, color: AppleTheme.accentTeal),
                    ),
                  ),
                if (_speech.isNotEmpty && !_isListening)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Text(
                      _speech,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9, color: Colors.white70),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
