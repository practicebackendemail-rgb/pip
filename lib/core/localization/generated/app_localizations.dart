import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// App name shown in the window title and task switcher.
  ///
  /// In en, this message translates to:
  /// **'Pip'**
  String get appTitle;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get actionSkip;

  /// No description provided for @actionLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get actionLater;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionRetry;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @navPip.
  ///
  /// In en, this message translates to:
  /// **'Pip'**
  String get navPip;

  /// No description provided for @navTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get navTasks;

  /// No description provided for @navAlarms.
  ///
  /// In en, this message translates to:
  /// **'Alarms'**
  String get navAlarms;

  /// No description provided for @navMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get navMemory;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get greetingEvening;

  /// No description provided for @greetingLateNight.
  ///
  /// In en, this message translates to:
  /// **'Late night'**
  String get greetingLateNight;

  /// No description provided for @greetingStillUp.
  ///
  /// In en, this message translates to:
  /// **'Still up'**
  String get greetingStillUp;

  /// No description provided for @greetingWithName.
  ///
  /// In en, this message translates to:
  /// **'{part}, {name}!'**
  String greetingWithName(String part, String name);

  /// No description provided for @greetingNoName.
  ///
  /// In en, this message translates to:
  /// **'{part}!'**
  String greetingNoName(String part);

  /// No description provided for @voiceListening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get voiceListening;

  /// No description provided for @voiceTapToTalk.
  ///
  /// In en, this message translates to:
  /// **'Tap to talk'**
  String get voiceTapToTalk;

  /// No description provided for @voiceSayYesOrNo.
  ///
  /// In en, this message translates to:
  /// **'Just say yes or no.'**
  String get voiceSayYesOrNo;

  /// No description provided for @openTasksCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing on your plate.} =1{1 open task} other{{count} open tasks}}'**
  String openTasksCount(int count);

  /// No description provided for @voiceSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voiceSettingsTitle;

  /// No description provided for @voiceSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How Pip hears you'**
  String get voiceSettingsSubtitle;

  /// No description provided for @voiceEngineHeading.
  ///
  /// In en, this message translates to:
  /// **'Recognition'**
  String get voiceEngineHeading;

  /// No description provided for @voiceEngineFast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get voiceEngineFast;

  /// No description provided for @voiceEngineFastDetail.
  ///
  /// In en, this message translates to:
  /// **'On your phone. Instant, free, works offline.'**
  String get voiceEngineFastDetail;

  /// No description provided for @voiceEngineAccurate.
  ///
  /// In en, this message translates to:
  /// **'Accurate'**
  String get voiceEngineAccurate;

  /// No description provided for @voiceEngineAccurateDetail.
  ///
  /// In en, this message translates to:
  /// **'Gemini listens to the recording. Better with accents and noise; uses your key\'s quota.'**
  String get voiceEngineAccurateDetail;

  /// No description provided for @voiceHandsFreeHeading.
  ///
  /// In en, this message translates to:
  /// **'Hands-free'**
  String get voiceHandsFreeHeading;

  /// No description provided for @voiceConversationMode.
  ///
  /// In en, this message translates to:
  /// **'Conversation mode'**
  String get voiceConversationMode;

  /// No description provided for @voiceConversationModeDetail.
  ///
  /// In en, this message translates to:
  /// **'After Pip answers, keep listening for your reply.'**
  String get voiceConversationModeDetail;

  /// No description provided for @voiceOpenMic.
  ///
  /// In en, this message translates to:
  /// **'Talk without a wake word'**
  String get voiceOpenMic;

  /// No description provided for @voiceOpenMicDetail.
  ///
  /// In en, this message translates to:
  /// **'While Pip is open, anything you say is for Pip.'**
  String get voiceOpenMicDetail;

  /// No description provided for @voiceWakeWord.
  ///
  /// In en, this message translates to:
  /// **'\"Hey Pip\" wake word'**
  String get voiceWakeWord;

  /// No description provided for @voiceWakeWordDetail.
  ///
  /// In en, this message translates to:
  /// **'Listen in the background for Pip\'s name.'**
  String get voiceWakeWordDetail;

  /// No description provided for @voicePrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Pip only listens while the app is open. Accurate mode sends the recording to Google with your key; nothing is stored.'**
  String get voicePrivacyNote;

  /// No description provided for @voiceTryIt.
  ///
  /// In en, this message translates to:
  /// **'Try it'**
  String get voiceTryIt;

  /// No description provided for @voiceHeard.
  ///
  /// In en, this message translates to:
  /// **'Heard: \"{text}\"'**
  String voiceHeard(String text);

  /// No description provided for @voiceHeardNothing.
  ///
  /// In en, this message translates to:
  /// **'I didn\'t catch anything. Try again a little louder.'**
  String get voiceHeardNothing;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
