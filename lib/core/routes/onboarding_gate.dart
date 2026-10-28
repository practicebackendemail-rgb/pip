import 'package:flutter/foundation.dart';
import '../services/pip_profile_service.dart';

/// Whether first-run setup is done. The router listens to it, so finishing
/// setup re-runs the global redirect.
class OnboardingGate extends ChangeNotifier {
  OnboardingGate._();
  static final OnboardingGate instance = OnboardingGate._();

  bool _completed = false;
  bool get completed => _completed;

  /// Reads the saved flag. Call once before the app starts.
  Future<void> load() async {
    _completed = await PipProfileService.hasCompletedOnboarding();
  }

  Future<void> complete() async {
    await PipProfileService.setCompletedOnboarding(true);
    _completed = true;
    notifyListeners();
  }
}
