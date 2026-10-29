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

  @override
  String get navActivity => 'Activity';

  @override
  String get commandHint => 'Ask Pip…';

  @override
  String get commandHintTasks => 'Ask about tasks…';

  @override
  String get commandHintAlarms => 'Ask about alarms…';

  @override
  String get commandHintBriefing => 'Ask about your day…';

  @override
  String get commandSend => 'Send to Pip';

  @override
  String get commandMicStart => 'Talk to Pip';

  @override
  String get commandMicStop => 'Stop listening';

  @override
  String get pipThinking => 'Thinking…';

  @override
  String get ledgeTasksIdle => 'Want me to plan your day, or add something?';

  @override
  String get ledgeAlarmsIdle =>
      'I can set, move or cancel any of these. Just say it.';

  @override
  String get ledgeBriefingIdle =>
      'Here\'s your day. Ask me about anything in it.';

  @override
  String get ledgeActivityIdle =>
      'Everything I\'ve done for you. Undo anything that wasn\'t right.';

  @override
  String get chipBriefMe => 'Brief me';

  @override
  String get chipPlay => 'Play a game';

  @override
  String get chipPlanDay => 'Plan my day';

  @override
  String get chipWhatsNext => 'What\'s next?';

  @override
  String get chipMoveOverdue => 'Move overdue to tomorrow';

  @override
  String get chipWakeMe => 'Wake me tomorrow at 7';

  @override
  String get chipRemindSoon => 'Remind me in 20 min';

  @override
  String get chipWhatAlarms => 'What alarms do I have?';

  @override
  String get chipReadIt => 'Read it to me';

  @override
  String get chipWhatsUrgent => 'What\'s urgent?';

  @override
  String get queryPlanDay => 'Plan my day using my open tasks.';

  @override
  String get queryWhatsNext => 'What should I do next?';

  @override
  String get queryMoveOverdue => 'Move my overdue tasks to tomorrow.';

  @override
  String get queryWakeMe => 'Wake me tomorrow at 7am.';

  @override
  String get queryRemindSoon => 'Remind me in 20 minutes.';

  @override
  String get queryWhatAlarms => 'What alarms and reminders do I have?';

  @override
  String get queryReadIt => 'Read my briefing to me.';

  @override
  String get queryWhatsUrgent => 'What in my day is urgent?';

  @override
  String get undo => 'Undo';

  @override
  String get undone => 'Undone';

  @override
  String get undoFailed => 'That can\'t be undone any more.';

  @override
  String get activityTitle => 'What Pip did';

  @override
  String get activityEmpty =>
      'Nothing yet. Ask Pip to set an alarm, add a task or brief you.';

  @override
  String get activityToday => 'Today';

  @override
  String get activityYesterday => 'Yesterday';

  @override
  String get tasksTitle => 'Objectives';

  @override
  String get tasksEmpty =>
      'Nothing on your list. Ask Pip, or tap + to add one.';

  @override
  String get tasksAdd => 'Add task';

  @override
  String get tasksOverdue => 'overdue';

  @override
  String get briefingTitle => 'Your day';

  @override
  String get briefingEmpty => 'Ask Pip to brief you to see your day here.';

  @override
  String get briefingRefresh => 'Refresh briefing';

  @override
  String get presenceHeading => 'Speaking up';

  @override
  String get presenceCasual => 'Casual';

  @override
  String get presenceCasualDetail =>
      'Pip greets you, chirps and wanders about.';

  @override
  String get presenceFocus => 'Focus';

  @override
  String get presenceFocusDetail =>
      'No idle sounds or greetings. Pip talks only when you talk to it.';

  @override
  String get presenceBriefing => 'Briefing';

  @override
  String get presenceBriefingDetail =>
      'Quiet through the day; ask \"what did I miss?\" when you\'re ready.';

  @override
  String get presenceQuiet => 'Quiet';

  @override
  String get presenceQuietDetail =>
      'No sounds and no spoken voice. Pip still works and shows its words.';

  @override
  String get chipWhatDidIMiss => 'What did I miss?';

  @override
  String get queryWhatDidIMiss => 'What did I miss? Check my notifications.';

  @override
  String get ranOnDevice => 'on-device';

  @override
  String get ranInCloud => 'cloud';

  @override
  String get brainsTitle => 'Brains';

  @override
  String get brainsIntro =>
      'I have two brains. The one on your device keeps things private; the cloud one is smarter for big jobs.';

  @override
  String get brainsLocalHeading => 'On-device brain';

  @override
  String get brainsLocalDetail =>
      'Private. Runs on this device and works offline. Free, but uses storage and battery.';

  @override
  String get brainsCloudHeading => 'Cloud brain';

  @override
  String get brainsCloudDetail =>
      'Smarter for big jobs. Uses your own key; you pay the provider.';

  @override
  String get brainsRoutingHeading => 'Who handles what';

  @override
  String get brainsRoutingDetail =>
      'Private data never goes to the cloud unless you say so here.';

  @override
  String brainsYourDevice(String ram) {
    return 'This device has $ram GB of memory.';
  }

  @override
  String get brainsNotSupported =>
      'On-device brains aren\'t available on this platform yet.';

  @override
  String get fitRecommended => 'Recommended';

  @override
  String get fitGood => 'Fits';

  @override
  String get fitHeavy => 'Heavy';

  @override
  String get fitTooBig => 'Too big';

  @override
  String modelDownload(String size) {
    return 'Download $size';
  }

  @override
  String get modelUse => 'Use';

  @override
  String get modelInUse => 'In use';

  @override
  String get modelRemove => 'Delete download';

  @override
  String modelDownloading(int percent) {
    return 'Downloading $percent%';
  }

  @override
  String get modelSize => 'Download';

  @override
  String get modelMemory => 'Needs';

  @override
  String modelMemoryValue(int gb) {
    return '$gb GB memory';
  }

  @override
  String get modelSmarts => 'Smarts';

  @override
  String get modelSpeed => 'Speed';

  @override
  String get modelGoodAt => 'Good at';

  @override
  String get modelCost => 'Cost';

  @override
  String get modelFree => 'Free forever';

  @override
  String get modelLicense => 'Licence';

  @override
  String get cloudNoKey =>
      'No cloud brain yet. Add a key to unlock planning, briefings and harder questions.';

  @override
  String get cloudAddKey => 'Add a key';

  @override
  String get cloudChange => 'Change key or model';

  @override
  String cloudPrice(String input, String output) {
    return '\$$input in, \$$output out per million tokens';
  }

  @override
  String get cloudFreeTier => 'Free tier';

  @override
  String cloudPerRequest(String cost) {
    return 'About $cost per request';
  }

  @override
  String cloudMonthly(int count, String cost) {
    return 'This month so far: $count cloud requests, about $cost';
  }

  @override
  String get cloudUnknownModel =>
      'I don\'t know this model\'s prices. Check your provider\'s pricing page.';

  @override
  String get jobPrivate => 'Notifications and memories';

  @override
  String get jobCommands => 'Everyday commands';

  @override
  String get jobBriefing => 'Daily briefing';

  @override
  String get jobBigJobs => 'Planning, drafts, long answers';

  @override
  String get brainLocal => 'On-device';

  @override
  String get brainCloud => 'Cloud';

  @override
  String get presetLabel => 'Presets';

  @override
  String get presetPrivate => 'Private';

  @override
  String get presetBalanced => 'Balanced';

  @override
  String get presetMaxSmarts => 'Max smarts';

  @override
  String get fallbackLabel => 'If that brain can\'t run';

  @override
  String get fallbackAsk => 'Tell me';

  @override
  String get fallbackUseOther => 'Use the other one';

  @override
  String get fallbackFail => 'Don\'t run it';

  @override
  String get fallbackNote =>
      'Private data still won\'t go to the cloud on its own.';

  @override
  String get briefingTasksDue => 'Tasks due';

  @override
  String briefingOverdueCount(int count) {
    return '$count overdue';
  }

  @override
  String get briefingRecentEmail => 'Recent email';

  @override
  String briefingImportantCount(int count) {
    return '$count important';
  }

  @override
  String get briefingNeedsYou => 'Needs you now';

  @override
  String briefingOverdueSince(String date) {
    return 'Overdue since $date';
  }

  @override
  String get briefingSnooze => 'Snooze';

  @override
  String get briefingSnoozed => 'Moved to tomorrow';

  @override
  String get briefingToday => 'Today';

  @override
  String get briefingNothingToday => 'Nothing scheduled today.';

  @override
  String get briefingTasks => 'Tasks';

  @override
  String get briefingNoTasks => 'No open tasks.';

  @override
  String get briefingDueToday => 'today';

  @override
  String get briefingInbox => 'Inbox';

  @override
  String get briefingCheckingEmail => 'Checking email…';

  @override
  String get briefingNoEmail => 'No recent email.';

  @override
  String get briefingReply => 'Reply';

  @override
  String briefingReplyQuery(String from, String subject) {
    return 'Draft a reply to $from about \"$subject\".';
  }

  @override
  String briefingReplyQueryNoSender(String subject) {
    return 'Draft a reply to the email \"$subject\".';
  }

  @override
  String get briefingSummaryLoading => 'Pip is reading your day…';

  @override
  String briefingMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String briefingMore(int count) {
    return '+$count more';
  }

  @override
  String get briefingDone => 'Done';

  @override
  String get chipPlanMyDay => 'Plan my day';

  @override
  String get queryPlanMyDay => 'Plan my day around my tasks and schedule.';
}
