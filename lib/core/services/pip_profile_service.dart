import 'package:shared_preferences/shared_preferences.dart';

/// Small first-run facts about the user (what Pip calls them, whether setup
/// finished). Not personal data that needs secure storage.
class PipProfileService {
  static const String _nameKey = 'pip_user_name';
  static const String _onboardedKey = 'has_completed_onboarding';

  static Future<String?> userName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_nameKey)?.trim();
    return (name == null || name.isEmpty) ? null : name;
  }

  static Future<void> setUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_nameKey);
    } else {
      await prefs.setString(_nameKey, trimmed);
    }
  }

  static const String _humorKey = 'pip_humor_level';

  /// How playful Pip's replies are, 0 (dry) to 1 (silly). Fed into the prompt.
  static Future<double> humor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_humorKey) ?? 0.6;
  }

  static Future<void> setHumor(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_humorKey, value.clamp(0.0, 1.0));
  }

  static Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardedKey) ?? false;
  }

  static Future<void> setCompletedOnboarding(bool done) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardedKey, done);
  }

  /// A friendly greeting for the current hour, with the name when known.
  static String greeting(String? name, {DateTime? now}) {
    final hour = (now ?? DateTime.now()).hour;
    final part = hour < 5
        ? 'Still up'
        : hour < 12
            ? 'Morning'
            : hour < 17
                ? 'Afternoon'
                : hour < 22
                    ? 'Evening'
                    : 'Late night';
    return name == null ? '$part!' : '$part, $name!';
  }
}
