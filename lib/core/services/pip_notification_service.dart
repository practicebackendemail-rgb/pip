import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show DartPluginRegistrant;
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'pip_notification_channels.dart';
import 'tools/schedule_store.dart';

/// What the phone currently allows for alarms and reminders.
class ReminderPermissions extends Equatable {
  final bool notifications;
  final bool exactAlarms;

  const ReminderPermissions({required this.notifications, required this.exactAlarms});

  static const granted = ReminderPermissions(notifications: true, exactAlarms: true);

  bool get allGranted => notifications && exactAlarms;

  @override
  List<Object?> get props => [notifications, exactAlarms];
}

/// Runs a Snooze or Dismiss tapped on a notification while Pip is closed.
@pragma('vm:entry-point')
Future<void> pipNotificationBackgroundHandler(NotificationResponse response) async {
  DartPluginRegistrant.ensureInitialized();
  await PipNotificationService.handleResponse(response);
}

/// Pip's alarms and reminders as system notifications.
///
/// Android, iOS, macOS: scheduled with the OS, so they fire with Pip closed
/// and (on Android) come back after a reboot. Alarms ring through the alarm
/// audio stream, show full-screen over the lock screen, and repeat weekly.
/// Windows: an in-app timer, so they fire only while Pip is running.
///
/// Notification ids are `item.id * 10 + slot`: slot 0 is a one-off, 1–7 the
/// repeat weekday, 8 a snooze.
class PipNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static final Map<int, Timer> _timers = {};
  static final StreamController<int> _opened = StreamController<int>.broadcast();
  static bool _ready = false;

  static const String snoozeAction = PipNotificationChannels.snoozeAction;
  static const String dismissAction = PipNotificationChannels.dismissAction;
  static const Duration snoozeFor = Duration(minutes: 10);

  /// Item ids whose notification the user tapped; the app opens the
  /// Alarms & reminders screen.
  static Stream<int> get openedItems => _opened.stream;

  /// Set when Pip was launched by tapping one of its notifications.
  static int? launchedFromItem;

  static bool get _osScheduled => !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);
  static bool get _android => !kIsWeb && Platform.isAndroid;

  static AndroidFlutterLocalNotificationsPlugin? get _androidPlugin =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Sets up time zones and the plugin. Safe to call repeatedly.
  static Future<void> init() async {
    if (_ready) return;
    try {
      tz.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (e) {
        debugPrint('Time zone lookup failed, using UTC: $e');
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: darwin,
          macOS: darwin,
          windows: WindowsInitializationSettings(
            appName: 'Pip',
            appUserModelId: 'Pip.DeskCompanion',
            guid: 'a8b5c1e2-3f4d-4c6b-9e7a-1d2c3b4a5f60',
          ),
        ),
        onDidReceiveNotificationResponse: handleResponse,
        onDidReceiveBackgroundNotificationResponse: pipNotificationBackgroundHandler,
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        launchedFromItem = _itemId(launch!.notificationResponse?.payload);
      }
      _ready = true;
    } catch (e) {
      debugPrint('Notification init warning: $e');
    }
  }

  /// What is allowed right now, without asking.
  static Future<ReminderPermissions> permissions() async {
    await init();
    if (!_android) return ReminderPermissions.granted;
    final android = _androidPlugin;
    return ReminderPermissions(
      notifications: await android?.areNotificationsEnabled() ?? true,
      exactAlarms: await android?.canScheduleExactNotifications() ?? true,
    );
  }

  /// Asks for whatever is missing. Exact alarms open a system settings page.
  static Future<ReminderPermissions> requestPermissions() async {
    await init();
    if (_android) {
      final android = _androidPlugin;
      final current = await permissions();
      if (!current.notifications) await android?.requestNotificationsPermission();
      if (!current.exactAlarms) await android?.requestExactAlarmsPermission();
      await android?.requestFullScreenIntentPermission();
    } else if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
    return permissions();
  }

  /// Schedules [item], replacing anything scheduled for it before. Returns
  /// 'persistent' (OS-scheduled), 'while_app_open' (in-app timer), or
  /// 'disabled'.
  static Future<String> schedule(ScheduledItem item) async {
    await init();
    await cancel(item);
    if (!item.enabled || item.inClockApp) return 'disabled';
    if (!_osScheduled) {
      _armTimer(item);
      return 'while_app_open';
    }
    final mode = await _scheduleMode(item.isAlarm);
    if (!item.repeats) {
      await _zoned(item, _base(item) * 10, tz.TZDateTime.from(item.at, tz.local), mode);
    } else {
      for (final day in item.days) {
        final at = _nextOnWeekday(day, item.at.hour, item.at.minute);
        await _zoned(item, _base(item) * 10 + day, at, mode, match: DateTimeComponents.dayOfWeekAndTime);
      }
    }
    return 'persistent';
  }

  /// Cancels every notification [item] may have scheduled, including a snooze.
  static Future<void> cancel(ScheduledItem item) async {
    final base = _base(item) * 10;
    for (var slot = 0; slot <= 8; slot++) {
      _timers.remove(base + slot)?.cancel();
      try {
        await _plugin.cancel(id: base + slot);
      } catch (e) {
        debugPrint('Cancel notification ${base + slot} failed: $e');
      }
    }
  }

  /// Fires [item] again after [snoozeFor].
  static Future<void> snooze(ScheduledItem item) async {
    await init();
    final at = DateTime.now().add(snoozeFor);
    final id = _base(item) * 10 + 8;
    if (!_osScheduled) {
      _timers.remove(id)?.cancel();
      _timers[id] = Timer(snoozeFor, () => _show(item, id));
      return;
    }
    await _zoned(item, id, tz.TZDateTime.from(at, tz.local), await _scheduleMode(item.isAlarm));
  }

  /// Re-schedules everything in the store. Run at startup: it repairs items
  /// created before the notification receivers existed, and arms the
  /// in-app timers on Windows.
  static Future<void> rescheduleAll() async {
    for (final item in await ScheduleStore.upcoming()) {
      await schedule(item);
    }
  }

  /// Handles a tap on a notification or on one of its action buttons.
  static Future<void> handleResponse(NotificationResponse response) async {
    final id = _itemId(response.payload);
    if (id == null) return;
    if (response.actionId == null) {
      _opened.add(id);
      return;
    }
    await init();
    final item = await ScheduleStore.byId(id);
    if (item == null) return;
    if (response.actionId == snoozeAction) await snooze(item);
    if (response.actionId == dismissAction && !item.repeats) await ScheduleStore.remove(item.id);
  }

  static int _base(ScheduledItem item) => item.id % 100000000;

  static int? _itemId(String? payload) {
    if (payload == null) return null;
    try {
      return (jsonDecode(payload) as Map<String, dynamic>)['id'] as int?;
    } catch (_) {
      return null;
    }
  }

  static Future<AndroidScheduleMode> _scheduleMode(bool alarm) async {
    if (!_android) return AndroidScheduleMode.exactAllowWhileIdle;
    final exact = await _androidPlugin?.canScheduleExactNotifications() ?? false;
    if (!exact) return AndroidScheduleMode.inexactAllowWhileIdle;
    return alarm ? AndroidScheduleMode.alarmClock : AndroidScheduleMode.exactAllowWhileIdle;
  }

  static Future<void> _zoned(ScheduledItem item, int id, tz.TZDateTime at, AndroidScheduleMode mode,
      {DateTimeComponents? match}) {
    return _plugin.zonedSchedule(
      id: id,
      title: _title(item),
      body: _body(item),
      payload: jsonEncode({'id': item.id}),
      scheduledDate: at,
      notificationDetails: PipNotificationChannels.detailsFor(item),
      androidScheduleMode: mode,
      matchDateTimeComponents: match,
    );
  }

  static tz.TZDateTime _nextOnWeekday(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (at.weekday != weekday || !at.isAfter(now)) {
      at = tz.TZDateTime(tz.local, at.year, at.month, at.day + 1, hour, minute);
    }
    return at;
  }

  static void _armTimer(ScheduledItem item) {
    final next = item.nextOccurrence();
    if (next == null) return;
    final id = _base(item) * 10;
    _timers.remove(id)?.cancel();
    _timers[id] = Timer(next.difference(DateTime.now()), () {
      _timers.remove(id);
      _show(item, id);
      if (item.repeats) _armTimer(item);
    });
  }

  static void _show(ScheduledItem item, int id) {
    _plugin.show(
      id: id,
      title: _title(item),
      body: _body(item),
      payload: jsonEncode({'id': item.id}),
      notificationDetails: PipNotificationChannels.detailsFor(item),
    );
  }

  static String _title(ScheduledItem item) => PipNotificationChannels.title(item);
  static String _body(ScheduledItem item) => PipNotificationChannels.body(item);
}
