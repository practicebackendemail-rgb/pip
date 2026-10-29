/// Every route path in the app. Never write a path string anywhere else.
abstract final class AppRoutes {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String onboarding = '/onboarding';

  /// Query flag on [onboarding] after a backup restore, so Pip can say so.
  static const String restoredParam = 'restored';

  static const String home = '/home';
  static const String briefingSegment = 'briefing';
  static const String briefing = '$home/$briefingSegment';
  static const String tasks = '/tasks';
  static const String activity = '/activity';
  static const String alarms = '/alarms';
  static const String memory = '/memory';

  static const String games = '/games';
  static String game(String slug) => '$games/$slug';

  static const String settings = '/settings';
  static const String settingsPersonality = '/settings/personality';
  static const String settingsAiModel = '/settings/ai-model';
  static const String settingsBrains = '/settings/brains';
  static const String settingsConnections = '/settings/connections';
  static const String settingsBackup = '/settings/backup';
  static const String settingsVoice = '/settings/voice';
  static const String settingsSetupAgain = '/settings/setup';

  /// Routes reachable before setup is finished.
  static const Set<String> publicPaths = {splash, welcome, onboarding};
}
