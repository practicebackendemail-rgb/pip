import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum VoiceStatus { idle, listening, speaking }

class VoicePreset {
  final String id;
  final String name;
  final String description;
  final double pitch;
  final double rate;

  const VoicePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.pitch,
    required this.rate,
  });

  static const List<VoicePreset> presets = [
    VoicePreset(
      id: 'pip_friendly',
      name: 'Pip (Playful Robot)',
      description: 'Upbeat, warm, and curious companion voice',
      pitch: 1.25,
      rate: 0.52,
    ),
    VoicePreset(
      id: 'jarvis_calm',
      name: 'AURA (Smooth Executive)',
      description: 'Poised, elegant, and articulated cadence',
      pitch: 1.0,
      rate: 0.48,
    ),
    VoicePreset(
      id: 'deep_cosmic',
      name: 'Supreme Intelligence (Deep Cosmic)',
      description: 'Resonant, authoritative, and cinematic tone',
      pitch: 0.82,
      rate: 0.46,
    ),
    VoicePreset(
      id: 'sage_mentor',
      name: 'Sage (Gentle & Mindful)',
      description: 'Relaxed, warm, and soothing pace',
      pitch: 0.95,
      rate: 0.44,
    ),
  ];
}

class VoiceService extends ChangeNotifier {
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  VoiceStatus _status = VoiceStatus.idle;
  bool _isSpeechAvailable = false;
  bool _isInitializing = false;
  bool _isListeningActive = false; // Guards against duplicate listen calls
  String _lastRecognizedWords = '';
  VoicePreset _currentPreset = VoicePreset.presets.first;
  List<dynamic> _availableTtsVoices = [];
  Map<String, String>? _selectedSystemVoice;
  Timer? _listenDebounce;

  VoiceStatus get status => _status;
  bool get isListening => _status == VoiceStatus.listening;
  bool get isSpeaking => _status == VoiceStatus.speaking;
  String get lastRecognizedWords => _lastRecognizedWords;
  VoicePreset get currentPreset => _currentPreset;
  List<dynamic> get availableTtsVoices => List.unmodifiable(_availableTtsVoices);
  Map<String, String>? get selectedSystemVoice => _selectedSystemVoice;

  VoiceService() {
    _loadVoiceSettings();
    _initVoiceEngine();
  }

  Future<void> _loadVoiceSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final presetId = prefs.getString('voice_preset_id') ?? 'pip_friendly';
    _currentPreset = VoicePreset.presets.firstWhere(
      (p) => p.id == presetId,
      orElse: () => VoicePreset.presets.first,
    );
    notifyListeners();
  }

  Future<void> setPreset(VoicePreset preset) async {
    _currentPreset = preset;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('voice_preset_id', preset.id);

    await _flutterTts.setPitch(preset.pitch);
    await _flutterTts.setSpeechRate(preset.rate);
    notifyListeners();

    // Sample voice preview
    speak("Voice changed to ${preset.name}.");
  }

  Future<void> _initVoiceEngine() async {
    if (_isInitializing) return;
    _isInitializing = true;

    // TTS Setup (Speech-to-Text has been migrated to PipAudioCoordinator to avoid dual-engine audio hardware conflicts)
    try {
      // Prefer Google's engine, but only if it's installed: many phones
      // (Samsung included) ship only their own, and forcing a missing
      // engine leaves Pip silent.
      if (defaultTargetPlatform == TargetPlatform.android) {
        final engines = await _flutterTts.getEngines;
        if (engines is List && engines.contains("com.google.android.tts")) {
          await _flutterTts.setEngine("com.google.android.tts");
        }
      }
      await _flutterTts.awaitSpeakCompletion(false); // Non-blocking
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setSpeechRate(_currentPreset.rate);
      await _flutterTts.setPitch(_currentPreset.pitch);
      await _flutterTts.setLanguage("en-US");

      _flutterTts.setStartHandler(() {
        debugPrint('TTS Started speaking');
        _status = VoiceStatus.speaking;
        notifyListeners();
      });

      _flutterTts.setCompletionHandler(() {
        debugPrint('TTS Finished speaking');
        _status = VoiceStatus.idle;
        notifyListeners();
      });

      _flutterTts.setCancelHandler(() {
        debugPrint('TTS Cancelled speaking');
        _status = VoiceStatus.idle;
        notifyListeners();
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint('TTS Error: $msg');
        _status = VoiceStatus.idle;
        notifyListeners();
      });

      _flutterTts.getVoices.then((voices) {
        if (voices is List) {
          _availableTtsVoices = voices;
          notifyListeners();
        }
      }).catchError((_) {});
    } catch (e) {
      debugPrint('Error setting up TTS: $e');
    }

    _isInitializing = false;
  }

  /// Start listening to user voice command
  Future<void> startListening({required Function(String text) onResultReceived}) async {
    // Debounce: ignore if already listening or debounce timer is active
    if (_isListeningActive || _speech.isListening) return;

    _listenDebounce?.cancel();
    _listenDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (_status == VoiceStatus.speaking) {
        await stopSpeaking();
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (!_isSpeechAvailable) {
        _isSpeechAvailable = await _speech.initialize();
      }

      if (!_isSpeechAvailable) {
        debugPrint('STT not available');
        return;
      }

      _isListeningActive = true;
      _status = VoiceStatus.listening;
      _lastRecognizedWords = '';
      notifyListeners();

      try {
        await _speech.listen(
          onResult: (result) {
            _lastRecognizedWords = result.recognizedWords;
            notifyListeners();

            if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
              final words = result.recognizedWords.trim();
              _isListeningActive = false;
              stopListening();
              onResultReceived(words);
            }
          },
          listenOptions: stt.SpeechListenOptions(
            // Use dictation mode — does NOT auto-restart, waits for natural pause
            listenMode: stt.ListenMode.dictation,
            cancelOnError: true,
            partialResults: true,
          ),
        );
      } catch (e) {
        debugPrint('STT listen error: $e');
        _isListeningActive = false;
        _status = VoiceStatus.idle;
        notifyListeners();
      }
    });
  }

  Future<void> stopListening() async {
    try {
      await _speech.stop();
    } catch (_) {}
    _status = VoiceStatus.idle;
    notifyListeners();
  }

  /// Speak text out loud — non-blocking, with audio session handoff delay
  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    // Hard-stop any in-progress speech first
    try {
      await _flutterTts.stop();
    } catch (_) {}

    // Give Android audio session time to fully release from STT / previous TTS
    // before requesting it again. 500ms is the sweet spot on most Android devices.
    await Future.delayed(const Duration(milliseconds: 500));

    final cleanedText = _sanitizeForTts(text);
    if (cleanedText.isEmpty) return;

    debugPrint("Pip speaking: $cleanedText");

    // Reapply settings before every speak — some Android devices reset them
    try {
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setSpeechRate(_currentPreset.rate);
      await _flutterTts.setPitch(_currentPreset.pitch);
      await _flutterTts.setLanguage("en-US");
    } catch (_) {}

    try {
      final res = await _flutterTts.speak(cleanedText, focus: true);
      debugPrint("TTS speak result code: $res");
    } catch (e) {
      debugPrint("Error in speak: $e");
      _status = VoiceStatus.idle;
      notifyListeners();
    }
  }

  /// Strips markdown, code blocks, emote actions (*like this*), and emoji
  /// from text so it sounds natural when spoken aloud.
  String _sanitizeForTts(String text) {
    return text
        // 1. Remove fenced code blocks entirely
        .replaceAll(RegExp(r'```[\s\S]*?```'), '')
        // 2. Remove inline code
        .replaceAll(RegExp(r'`[^`]*`'), '')
        // 3. Strip *emote actions* AND **bold** — remove the whole *...* block
        .replaceAll(RegExp(r'\*{1,3}[^*\n]*\*{1,3}'), '')
        // 4. Strip _italic_ blocks
        .replaceAll(RegExp(r'_{1,2}[^_\n]*_{1,2}'), '')
        // 5. Strip headers (#, ##, ###)
        .replaceAll(RegExp(r'#+\s*'), '')
        // 6. Strip markdown links [text](url) → keep just text
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]*\)'), r'$1')
        // 7. Strip remaining markdown special chars
        .replaceAll(RegExp(r'[>\|\~\\]'), ' ')
        // 8. Strip emoji (broad unicode range)
        .replaceAll(
          RegExp(
            r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}'
            r'\u{1F900}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
            unicode: true,
          ),
          '',
        )
        // 9. Collapse whitespace
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> stopSpeaking() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
    _status = VoiceStatus.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _listenDebounce?.cancel();
    stopSpeaking();
    stopListening();
    super.dispose();
  }
}
