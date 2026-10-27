import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'pip_sfx_service.dart';

/// Robust wake-word listener with broad phonetic context matching,
/// auto-restart loop, manual trigger capability, and live listening status.
class PipWakeWordService extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isHandsFreeActive = true;
  String _lastTriggerWord = '';
  DateTime? _lastTriggerTime;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  bool get isHandsFreeActive => _isHandsFreeActive;
  String get lastTriggerWord => _lastTriggerWord;

  PipWakeWordService() {
    init();
  }

  Future<void> init() async {
    try {
      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          debugPrint('WakeWord STT status: $status');
          final active = status == 'listening';
          if (_isListening != active) {
            _isListening = active;
            notifyListeners();
          }
          if (status == 'notListening' || status == 'done') {
            if (_isHandsFreeActive) {
              Future.delayed(const Duration(milliseconds: 250), _startWakeWordLoop);
            }
          }
        },
        onError: (error) {
          debugPrint('WakeWord STT error: ${error.errorMsg}');
          _isListening = false;
          notifyListeners();
          if (_isHandsFreeActive) {
            Future.delayed(const Duration(milliseconds: 500), _startWakeWordLoop);
          }
        },
      );
      if (_isInitialized && _isHandsFreeActive) {
        _startWakeWordLoop();
      }
    } catch (e) {
      debugPrint('Error init WakeWordService: $e');
    }
  }

  void toggleHandsFree(bool enable) {
    _isHandsFreeActive = enable;
    if (_isHandsFreeActive) {
      _startWakeWordLoop();
    } else {
      _speech.stop();
      _isListening = false;
    }
    notifyListeners();
  }

  void manualTrigger() {
    _handleWakeDetection("pip");
  }

  Future<void> _startWakeWordLoop() async {
    if (!_isInitialized || _speech.isListening || !_isHandsFreeActive) return;

    try {
      _isListening = true;
      notifyListeners();

      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords.toLowerCase().trim();
          debugPrint('WakeWord stream heard: "$words"');

          if (_matchesWakeWord(words)) {
            _handleWakeDetection(words);
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
        ),
      );
    } catch (e) {
      debugPrint('Error in wake word loop: $e');
      _isListening = false;
      notifyListeners();
    }
  }

  /// Broad phonetic & contextual matcher for Pip
  /// Captures common acoustic transcript mishearings:
  /// - "hey babe", "hey baby", "babe", "baby", "hey bob"
  /// - "tip", "pip", "peep", "pete", "papp", "pit", "pipp", "bib", "bip", "deep", "beep"
  /// - "hey pip", "hi pip", "okay pip", "ok pip", "wake pip", "hello pip"
  bool _matchesWakeWord(String text) {
    if (text.isEmpty) return false;
    final clean = text.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    final tokens = clean.split(RegExp(r'\s+'));

    // 1. Exact phonetic vocabulary cluster
    const triggers = {
      'pip', 'pipp', 'peep', 'pepe', 'tip', 'tipp', 'pit', 'pitt',
      'pete', 'papp', 'bib', 'bip', 'babe', 'baby', 'bob', 'beep', 'deep'
    };

    // 2. Direct single token trigger
    for (final t in tokens) {
      if (triggers.contains(t)) return true;
    }

    // 3. Salutation + any short target token (e.g. "hey...", "hi...", "okay...")
    const salutations = {'hey', 'hi', 'hello', 'ok', 'okay', 'yo', 'dear'};
    for (int i = 0; i < tokens.length - 1; i++) {
      if (salutations.contains(tokens[i])) {
        final next = tokens[i + 1];
        if (triggers.contains(next) || next.startsWith('p') || next.startsWith('b') || next.startsWith('t')) {
          return true;
        }
      }
    }

    // 4. Broad regex patterns
    final broadRegex = RegExp(r'\b(hey|hi|hello|ok|okay)?\s*(pip|babe|baby|peep|tip|pete|beep|bip)\b');
    return broadRegex.hasMatch(clean);
  }

  /// Cleans the wake-phrase off the user speech so follow-up commands remain clean
  static String extractFollowUpCommand(String rawHeard) {
    final pattern = RegExp(
      r'^\s*(hey|hi|hello|ok|okay|yo)?\s*(pip|babe|baby|peep|tip|pete|beep|bip|bib)\s*[,:\.\-]?\s*',
      caseSensitive: false,
    );
    return rawHeard.replaceAll(pattern, '').trim();
  }

  void _handleWakeDetection(String fullWords) {
    final now = DateTime.now();
    if (_lastTriggerTime != null && now.difference(_lastTriggerTime!).inMilliseconds < 1200) {
      return;
    }
    _lastTriggerTime = now;
    _lastTriggerWord = fullWords;
    _speech.stop();
    _isListening = false;
    notifyListeners();

    PipSfxService.chirp();
  }

  void pause() {
    _speech.stop();
    _isListening = false;
    notifyListeners();
  }

  void resume() {
    if (_isHandsFreeActive) {
      _startWakeWordLoop();
    }
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }
}
