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
}
