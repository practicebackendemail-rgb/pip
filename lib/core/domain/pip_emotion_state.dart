import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../widgets/pip_params.dart';

/// Pip's internal psychological state based on Section 7.1 of the Implementation Guide.
/// Drives personality, eye expressions, LED colors, and proactive comments.
class PipEmotionState extends ChangeNotifier {
  double _valence = 0.5;   // 0.0 (sad/sulky) to 1.0 (happy/celebratory)
  double _energy = 0.8;    // 0.0 (sleepy/dormant) to 1.0 (hyper/excited)
  double _bond = 0.2;      // 0.0 (stranger) to 1.0 (best companion/deep bond)
  double _boredom = 0.1;   // 0.0 (fully engaged) to 1.0 (neglected/fidgety)
  DateTime _lastInteraction = DateTime.now();

  double get valence => _valence;
  double get energy => _energy;
  double get bond => _bond;
  double get boredom => _boredom;
  DateTime get lastInteraction => _lastInteraction;

  void onUserInteraction() {
    _lastInteraction = DateTime.now();
    _boredom = math.max(0.0, _boredom - 0.35);
    _bond = math.min(1.0, _bond + 0.005);
    _driftTowardsBaseline();
    notifyListeners();
  }

  void onTaskCompleted() {
    _valence = math.min(1.0, _valence + 0.25);
    _energy = math.min(1.0, _energy + 0.15);
    _bond = math.min(1.0, _bond + 0.02);
    _boredom = 0.0;
    _lastInteraction = DateTime.now();
    notifyListeners();
  }

  void onOverdueAccumulation() {
    _valence = math.max(0.1, _valence - 0.15);
    notifyListeners();
  }

  void onSleepTriggered() {
    _energy = 0.15;
    _boredom = 0.0;
    notifyListeners();
  }

  void onWakeTriggered() {
    _energy = 0.85;
    _lastInteraction = DateTime.now();
    notifyListeners();
  }

  /// Evaluates natural biological baseline drift
  void evaluateTimeDrift() {
    final now = DateTime.now();
    final inactiveMinutes = now.difference(_lastInteraction).inMinutes;

    if (inactiveMinutes > 60) {
      // Gradual increase in boredom after 1 hour
      _boredom = math.min(1.0, _boredom + 0.05 * (inactiveMinutes / 60));
    }

    // Late night energy drain (11 PM - 6 AM)
    if (now.hour >= 23 || now.hour < 6) {
      _energy = math.max(0.2, _energy - 0.2);
    } else {
      _energy = math.min(0.9, _energy + 0.05);
    }

    _driftTowardsBaseline();
    notifyListeners();
  }

  void _driftTowardsBaseline() {
    _valence += (0.55 - _valence) * 0.05;
  }

  /// Maps the continuous emotional state into Pip's vector posture
  PipMood resolvePipMood() {
    if (_energy <= 0.25) return PipMood.sleepy;
    if (_valence >= 0.75) return PipMood.happy;
    if (_valence <= 0.3) return PipMood.sad;
    if (_boredom >= 0.7) return PipMood.unsure;
    return PipMood.idle;
  }

  /// Provides an emotion context block to inject into the LLM prompt
  String toPromptContext() {
    return '[Pip Current Internal State: valence=${_valence.toStringAsFixed(2)}, '
        'energy=${_energy.toStringAsFixed(2)}, bond=${_bond.toStringAsFixed(2)}, boredom=${_boredom.toStringAsFixed(2)}]';
  }
}
