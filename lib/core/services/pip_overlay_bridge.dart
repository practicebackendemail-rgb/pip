import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../../features/companion/presentation/cubit/pip_stage_cubit.dart';
import '../../features/companion/presentation/cubit/pip_stage_state.dart';
import '../../widgets/pip_params.dart';
import 'pip_audio_coordinator.dart';
import 'pip_overlay_manager.dart';

/// Bridges communication between the main app's PipStageCubit and the floating Android overlay.
/// Features:
/// 1. Subscribes to PipStageCubit and throttles state sync to overlay window (max once every 250ms).
/// 2. Never transmits intermediate typewriter ticks to preserve GPU and battery performance.
/// 3. Subscribes to overlay events ('tap_listen') and invokes AudioCoordinator to trigger voice input.
class PipOverlayBridge {
  final PipStageCubit cubit;
  final PipAudioCoordinator audioCoordinator;

  StreamSubscription<PipStageState>? _cubitSubscription;
  StreamSubscription<dynamic>? _overlaySubscription;
  DateTime _lastSentTime = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _throttleTimer;

  PipMood _lastMood = PipMood.idle;
  String _lastSpeech = '';
  bool _lastListening = false;

  PipOverlayBridge({
    required this.cubit,
    required this.audioCoordinator,
  });

  void start() {
    // Listen to cubit state emissions
    _cubitSubscription = cubit.stream.listen(_handleCubitState);

    // Listen for events coming from overlay (e.g. tap to listen) on Android
    if (!kIsWeb && Platform.isAndroid) {
      _overlaySubscription = FlutterOverlayWindow.overlayListener.listen(_handleOverlayEvent);
    }
  }

  void handleOverlayMessage(dynamic data) {
    _handleOverlayEvent(data);
  }

  void _handleCubitState(PipStageState state) {
    // Only send when mood, finished speech text, or listening state changes
    final currentMood = state.currentMood;
    final currentSpeech = state.isTypewriting ? _lastSpeech : state.speechText;
    final currentListening = audioCoordinator.isActiveListening;

    if (currentMood == _lastMood &&
        currentSpeech == _lastSpeech &&
        currentListening == _lastListening) {
      return;
    }

    final now = DateTime.now();
    final elapsed = now.difference(_lastSentTime).inMilliseconds;

    if (elapsed >= 250) {
      _transmitState(currentMood, currentSpeech, currentListening);
    } else {
      _throttleTimer?.cancel();
      _throttleTimer = Timer(Duration(milliseconds: 250 - elapsed), () {
        _transmitState(currentMood, currentSpeech, currentListening);
      });
    }
  }

  void _transmitState(PipMood mood, String speech, bool isListening) {
    _lastSentTime = DateTime.now();
    _lastMood = mood;
    _lastSpeech = speech;
    _lastListening = isListening;

    final payload = jsonEncode({
      'mood': mood.name,
      'speech': speech,
      'isListening': isListening,
    });
    PipOverlayManager.shareData(payload);
  }

  void _handleOverlayEvent(dynamic data) {
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is! Map<String, dynamic>) return;
        switch (decoded['action']) {
          case 'tap_listen':
            handleTapListen();
          case 'stop_listen':
            audioCoordinator.stopListening();
          case 'quick':
            final query = decoded['query'];
            if (query is String && query.isNotEmpty) cubit.handleQuery(query);
        }
      } catch (e) {
        debugPrint('Overlay event parse error: $e');
      }
    }
  }

  void handleTapListen() {
    audioCoordinator.startActiveListening(onQuery: (query) {
      cubit.handleQuery(query);
    });
  }

  void dispose() {
    _cubitSubscription?.cancel();
    _overlaySubscription?.cancel();
    _throttleTimer?.cancel();
  }
}
