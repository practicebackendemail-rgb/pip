import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'pip_sfx_service.dart';

enum PipAudioSessionState {
  idle,
  passiveListening, // background wake word loop
  activeCommandListening, // user initiated manual mic or wake-word followed by speech
  processing,
  speaking,
}

/// Unified Audio & Speech Coordinator for Pip.
/// Solves the dual STT conflict by ensuring only ONE SpeechToText engine exists,
/// transitions between wake-word and command listening, and blocks STT during TTS playback.
class PipAudioCoordinator extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isHandsFreeActive = false; // Stashed auto-trigger; defaulting to pure Push-To-Talk
  PipAudioSessionState _sessionState = PipAudioSessionState.idle;
  String _lastRecognizedWords = '';
  DateTime? _lastTriggerTime;

  bool get isInitialized => _isInitialized;
  bool get isHandsFreeActive => _isHandsFreeActive;
  bool get isListening =>
      _sessionState == PipAudioSessionState.passiveListening ||
      _sessionState == PipAudioSessionState.activeCommandListening;
  bool get isActiveListening => _sessionState == PipAudioSessionState.activeCommandListening;
  PipAudioSessionState get sessionState => _sessionState;
  String get lastRecognizedWords => _lastRecognizedWords;

  void Function(String query)? onCommandReceived;

  PipAudioCoordinator() {
    init();
  }

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      _isInitialized = await _speech.initialize(
        onStatus: _handleStatusChange,
        onError: (err) {
          debugPrint('AudioCoordinator STT error: ${err.errorMsg} (session: $_sessionState)');
          if (_sessionState == PipAudioSessionState.activeCommandListening) {
            _sessionState = PipAudioSessionState.idle;
            notifyListeners();
          }
          if (_isHandsFreeActive && _sessionState != PipAudioSessionState.speaking) {
            final delay = err.errorMsg.contains('error_client') ? 2000 : 800;
            Future.delayed(Duration(milliseconds: delay), () {
              if (_isHandsFreeActive &&
                  _sessionState != PipAudioSessionState.speaking &&
                  _sessionState != PipAudioSessionState.activeCommandListening) {
                startPassiveWakeLoop();
              }
            });
          }
        },
      );
      if (_isInitialized && _isHandsFreeActive) {
        startPassiveWakeLoop();
      }
    } catch (e) {
      debugPrint('Error initializing AudioCoordinator: $e');
    }
  }

  void _handleStatusChange(String status) {
    debugPrint('AudioCoordinator status: $status (session: $_sessionState)');
    if (status == 'notListening' || status == 'done') {
      if (_sessionState == PipAudioSessionState.passiveListening && _isHandsFreeActive) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (_sessionState == PipAudioSessionState.passiveListening && _isHandsFreeActive) {
            startPassiveWakeLoop();
          }
        });
      } else if (_sessionState == PipAudioSessionState.activeCommandListening) {
        _sessionState = PipAudioSessionState.idle;
        notifyListeners();
      }
    }
  }

  /// Starts passive continuous background listening for wake words ("Pip", "Hey Pip", etc.)
  Future<void> startPassiveWakeLoop() async {
    if (!_isInitialized || _speech.isListening || !_isHandsFreeActive) return;
    if (_sessionState == PipAudioSessionState.speaking || _sessionState == PipAudioSessionState.processing) return;

    try {
      _sessionState = PipAudioSessionState.passiveListening;
      notifyListeners();

      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords.toLowerCase().trim();
          debugPrint('Passive stream heard: "$words"');

          if (_matchesWakeWord(words)) {
            final followUp = extractFollowUpCommand(words);
            handleWakeDetected(followUp: followUp);
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
        ),
      );
    } catch (e) {
      debugPrint('Error in passive loop: $e');
      _sessionState = PipAudioSessionState.idle;
      notifyListeners();
    }
  }

  /// Triggers full active command capture (when wake word is detected or manual mic clicked)
  Future<void> startActiveListening({required Function(String query) onQuery}) async {
    onCommandReceived = onQuery;
    await _speech.stop();
    _sessionState = PipAudioSessionState.activeCommandListening;
    _lastRecognizedWords = '';
    notifyListeners();
    PipSfxService.listen(); // "boop-beep": the mic is open

    try {
      await _speech.listen(
        onResult: (result) {
          _lastRecognizedWords = result.recognizedWords;
          notifyListeners();

          if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
            final text = result.recognizedWords.trim();
            stopListening();
            onQuery(text);
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
        ),
      );
    } catch (e) {
      debugPrint('Error starting active listen: $e');
      stopListening();
    }
  }

  Future<void> stopListening() async {
    try {
      await _speech.stop();
    } catch (_) {}
    _sessionState = PipAudioSessionState.idle;
    notifyListeners();
    if (_isHandsFreeActive) {
      Future.delayed(const Duration(milliseconds: 500), startPassiveWakeLoop);
    }
  }

  void handleWakeDetected({String followUp = ''}) async {
    final now = DateTime.now();
    if (_lastTriggerTime != null && now.difference(_lastTriggerTime!).inMilliseconds < 1200) return;
    _lastTriggerTime = now;

    _speech.stop();
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 300), () {
      PipSfxService.listen();
      if (followUp.isNotEmpty && onCommandReceived != null) {
        onCommandReceived!(followUp);
      } else {
        // Transition to active command listening for user follow-up
        if (onCommandReceived != null) {
          startActiveListening(onQuery: onCommandReceived!);
        }
      }
    });
  }

  void onPlaybackStarted() {
    _sessionState = PipAudioSessionState.speaking;
    _speech.stop();
    notifyListeners();
  }

  /// Low-latency barge-in interruption triggered when user starts speaking while Pip is talking
  void interruptPlayback() {
    if (_sessionState == PipAudioSessionState.speaking) {
      _sessionState = PipAudioSessionState.idle;
      PipSfxService.chirp();
      notifyListeners();
    }
  }

  void onPlaybackFinished() {
    _sessionState = PipAudioSessionState.idle;
    notifyListeners();
    if (_isHandsFreeActive) {
      Future.delayed(const Duration(milliseconds: 400), startPassiveWakeLoop);
    }
  }

  void toggleHandsFree(bool enable) {
    _isHandsFreeActive = enable;
    if (_isHandsFreeActive) {
      startPassiveWakeLoop();
    } else {
      stopListening();
    }
    notifyListeners();
  }

  bool _matchesWakeWord(String text) {
    if (text.isEmpty) return false;
    final clean = text.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    final tokens = clean.split(RegExp(r'\s+'));

    const triggers = {
      'pip', 'pipp', 'peep', 'pepe', 'tip', 'tipp', 'pit', 'pitt',
      'pete', 'papp', 'bib', 'bip', 'babe', 'baby', 'bob', 'beep', 'deep'
    };

    for (final t in tokens) {
      if (triggers.contains(t)) return true;
    }

    const salutations = {'hey', 'hi', 'hello', 'ok', 'okay', 'yo'};
    for (int i = 0; i < tokens.length - 1; i++) {
      if (salutations.contains(tokens[i])) {
        final next = tokens[i + 1];
        if (triggers.contains(next) || next.startsWith('p') || next.startsWith('b')) {
          return true;
        }
      }
    }
    return false;
  }

  static String extractFollowUpCommand(String raw) {
    final pattern = RegExp(
      r'^\s*(hey|hi|hello|ok|okay|yo)?\s*(pip|babe|baby|peep|tip|pete|beep|bip|bib)\s*[,:\.\-]?\s*',
      caseSensitive: false,
    );
    return raw.replaceAll(pattern, '').trim();
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }
}
