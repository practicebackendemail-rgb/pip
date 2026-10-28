import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../features/voice/data/gemini_voice_capture.dart';
import '../../features/voice/data/voice_settings.dart';
import '../../features/voice/domain/listen_delivery.dart';
import '../../features/voice/domain/speech_transcriber.dart';
import 'pip_sfx_service.dart';
import 'wake_word.dart';

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

  /// Accurate (Gemini audio) listening; set at startup. Null = on-device only.
  GeminiVoiceCapture? geminiCapture;
  VoiceSettings get _settings => VoiceSettings.instance;

  /// Last listening problem, in words for the user (cleared on success).
  final ValueNotifier<String?> lastError = ValueNotifier(null);

  bool get _useGemini => _settings.engine == SpeechEngine.geminiAudio && geminiCapture != null;

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
            _delivery.stopped(); // e.g. "no match" after partial words: keep them
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

  static const Duration beepLength = Duration(milliseconds: 220);

  late final ListenDelivery _delivery = ListenDelivery(onHeard: (text) {
    lastError.value = null;
    stopListening();
    onCommandReceived?.call(text);
  }, onNothing: () => lastError.value = "I didn't catch that. Tap the mic and try again.");

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
        _delivery.stopped();
        _sessionState = PipAudioSessionState.idle;
        notifyListeners();
      }
    }
  }

  /// Starts passive continuous background listening for wake words ("Pip", "Hey Pip", etc.)
  Future<void> startPassiveWakeLoop() async {
    if (!_isHandsFreeActive) return;
    if (_sessionState == PipAudioSessionState.speaking || _sessionState == PipAudioSessionState.processing) return;
    if (_settings.openMic && _useGemini && onCommandReceived != null) {
      // Open mic, accurate mode: the voice detector is the trigger.
      if (geminiCapture!.isRecording) return;
      _sessionState = PipAudioSessionState.passiveListening;
      notifyListeners();
      return _listenWithGemini(onCommandReceived!, followUp: false, alwaysOn: true);
    }
    if (!_isInitialized || _speech.isListening) return;

    try {
      _sessionState = PipAudioSessionState.passiveListening;
      notifyListeners();

      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords.toLowerCase().trim();
          debugPrint('Passive stream heard: "$words"');

          if (_settings.wakeWord && WakeWord.matches(words)) {
            final followUp = WakeWord.followUp(words);
            handleWakeDetected(followUp: followUp);
          } else if (_settings.openMic && result.finalResult && words.split(' ').length >= 2) {
            // Open mic: any real sentence is for Pip, no wake word needed.
            handleWakeDetected(followUp: result.recognizedWords.trim());
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
  Future<void> startActiveListening({required Function(String query) onQuery, bool followUp = false}) async {
    onCommandReceived = onQuery;
    final wasListening = _speech.isListening;
    await _speech.stop();
    // A restart straight after the wake loop fails with "busy": wait a moment.
    if (wasListening) await Future<void>.delayed(const Duration(milliseconds: 200));
    _sessionState = PipAudioSessionState.activeCommandListening;
    _lastRecognizedWords = '';
    _delivery.begin();
    notifyListeners();
    // "boop-beep" finishes before the mic opens, so it isn't heard as speech.
    if (!followUp) await PipSfxService.listen().then((_) => Future<void>.delayed(beepLength));
    if (_useGemini) return _listenWithGemini(onQuery, followUp: followUp);

    try {
      await _speech.listen(
        onResult: (result) {
          _lastRecognizedWords = result.recognizedWords;
          _delivery.heard(result.recognizedWords);
          notifyListeners();
          if (result.finalResult) _delivery.deliver();
        },
        listenOptions: stt.SpeechListenOptions(
          // Stop 2.5 s after you finish (a follow-up gives up sooner).
          pauseFor: Duration(milliseconds: followUp ? 2000 : 2500),
          listenFor: Duration(seconds: followUp ? 8 : 30),
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

  /// Accurate mode: record until you stop talking, then Gemini transcribes.
  Future<void> _listenWithGemini(Function(String query) onQuery, {required bool followUp, bool alwaysOn = false}) async {
    final result = await geminiCapture!.listenOnce(followUp: followUp, alwaysOn: alwaysOn);
    if (_sessionState == PipAudioSessionState.speaking) return; // Pip started talking meanwhile
    _sessionState = PipAudioSessionState.idle;
    notifyListeners();
    if (result == null) {
      if (alwaysOn) _resumeHandsFree();
      return;
    }
    if (!result.isSuccess) {
      lastError.value = result.error;
      _resumeHandsFree();
      return;
    }
    lastError.value = null;
    _lastRecognizedWords = result.text!;
    onQuery(result.text!.trim());
  }

  Future<void> stopListening() async {
    try {
      await _speech.stop();
      await geminiCapture?.stop();
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
      if (followUp.isNotEmpty && onCommandReceived != null) {
        PipSfxService.chirp(); // heard it all in one go: acknowledge, no mic beep
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
    geminiCapture?.stop(); // never transcribe Pip's own voice
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

  /// Pip stopped talking: in conversation mode the mic reopens for a
  /// follow-up; otherwise hands-free listening resumes.
  void onPlaybackFinished() {
    if (_sessionState != PipAudioSessionState.speaking) return;
    _sessionState = PipAudioSessionState.idle;
    notifyListeners();
    final onQuery = onCommandReceived;
    Future.delayed(const Duration(milliseconds: 350), () {
      if (_sessionState != PipAudioSessionState.idle) return;
      if (_settings.conversationMode && onQuery != null) {
        startActiveListening(onQuery: onQuery, followUp: true);
      } else {
        _resumeHandsFree();
      }
    });
  }

  void _resumeHandsFree() {
    if (_isHandsFreeActive) Future.delayed(const Duration(milliseconds: 400), startPassiveWakeLoop);
  }

  /// Applies [VoiceSettings] (call after they change).
  void applySettings() => toggleHandsFree(_settings.handsFree);

  void toggleHandsFree(bool enable) {
    _isHandsFreeActive = enable;
    if (_isHandsFreeActive) {
      startPassiveWakeLoop();
    } else {
      stopListening();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }
}
