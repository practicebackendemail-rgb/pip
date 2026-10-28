// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Pip';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionBack => 'Back';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSkip => 'Skip for now';

  @override
  String get actionLater => 'Later';

  @override
  String get actionDone => 'Done';

  @override
  String get actionRetry => 'Try again';

  @override
  String get saved => 'Saved';

  @override
  String get navPip => 'Pip';

  @override
  String get navTasks => 'Tasks';

  @override
  String get navAlarms => 'Alarms';

  @override
  String get navMemory => 'Memory';

  @override
  String get navSettings => 'Settings';

  @override
  String get greetingMorning => 'Morning';

  @override
  String get greetingAfternoon => 'Afternoon';

  @override
  String get greetingEvening => 'Evening';

  @override
  String get greetingLateNight => 'Late night';

  @override
  String get greetingStillUp => 'Still up';

  @override
  String greetingWithName(String part, String name) {
    return '$part, $name!';
  }

  @override
  String greetingNoName(String part) {
    return '$part!';
  }

  @override
  String get voiceListening => 'Listening…';

  @override
  String get voiceTapToTalk => 'Tap to talk';

  @override
  String get voiceSayYesOrNo => 'Just say yes or no.';

  @override
  String openTasksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open tasks',
      one: '1 open task',
      zero: 'Nothing on your plate.',
    );
    return '$_temp0';
  }

  @override
  String get voiceSettingsTitle => 'Voice';

  @override
  String get voiceSettingsSubtitle => 'How Pip hears you';

  @override
  String get voiceEngineHeading => 'Recognition';

  @override
  String get voiceEngineFast => 'Fast';

  @override
  String get voiceEngineFastDetail =>
      'On your phone. Instant, free, works offline.';

  @override
  String get voiceEngineAccurate => 'Accurate';

  @override
  String get voiceEngineAccurateDetail =>
      'Gemini listens to the recording. Better with accents and noise; uses your key\'s quota.';

  @override
  String get voiceHandsFreeHeading => 'Hands-free';

  @override
  String get voiceConversationMode => 'Conversation mode';

  @override
  String get voiceConversationModeDetail =>
      'After Pip answers, keep listening for your reply.';

  @override
  String get voiceOpenMic => 'Talk without a wake word';

  @override
  String get voiceOpenMicDetail =>
      'While Pip is open, anything you say is for Pip.';

  @override
  String get voiceWakeWord => '\"Hey Pip\" wake word';

  @override
  String get voiceWakeWordDetail => 'Listen in the background for Pip\'s name.';

  @override
  String get voicePrivacyNote =>
      'Pip only listens while the app is open. Accurate mode sends the recording to Google with your key; nothing is stored.';

  @override
  String get voiceTryIt => 'Try it';

  @override
  String voiceHeard(String text) {
    return 'Heard: \"$text\"';
  }

  @override
  String get voiceHeardNothing =>
      'I didn\'t catch anything. Try again a little louder.';
}
