import 'dart:async';
import 'package:flutter/services.dart';
import '../../core/services/pip_sfx_service.dart';

class PipSpeechCoordinator {
  Timer? _typewriterTimer;
  bool _isTypewriting = false;
  String _displayedSpeechText = '';

  bool get isTypewriting => _isTypewriting;
  String get displayedSpeechText => _displayedSpeechText;

  void triggerSpeech({
    required String fullText,
    bool isHappy = false,
    PipSound? sound,
    required void Function() onTick,
    required void Function() onDone,
  }) {
    _typewriterTimer?.cancel();
    _displayedSpeechText = '';
    _isTypewriting = true;

    isHappy ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact();
    PipSfxService.play(sound ?? (isHappy ? PipSound.happy : PipSound.chirp));
    onTick();

    int index = 0;
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 22), (timer) {
      if (index < fullText.length) {
        index = (index + 2 <= fullText.length) ? index + 2 : fullText.length;
        _displayedSpeechText = fullText.substring(0, index);
        onTick();
      } else {
        timer.cancel();
        _isTypewriting = false;
        HapticFeedback.selectionClick();
        onDone();
      }
    });
  }

  void clear() {
    _typewriterTimer?.cancel();
    _displayedSpeechText = '';
    _isTypewriting = false;
  }

  void dispose() {
    _typewriterTimer?.cancel();
  }
}
