import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/inbox_notification.dart';

/// Reads what the Android notification listener saved (it writes into the
/// shared_preferences file, so this works even for notifications that came
/// in while Pip was closed). Tracks when you last asked "what did I miss?".
class NotificationInbox {
  NotificationInbox({MethodChannel? channel}) : _channel = channel ?? const MethodChannel(channelName);

  static final NotificationInbox instance = NotificationInbox();
  static const String channelName = 'com.pip.companion/notifications';
  static const String inboxKey = 'pip_notification_inbox';
  static const String mutedKey = 'pip_notification_muted';
  static const String lastCheckedKey = 'pip_notification_last_checked';

  final MethodChannel _channel;

  static bool get supported => !kIsWeb && Platform.isAndroid;

  /// Whether the user granted notification access to Pip.
  Future<bool> isEnabled() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('isEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens Android's notification-access screen.
  Future<void> openSettings() async {
    if (supported) await _channel.invokeMethod('openSettings');
  }

  Future<List<InboxNotification>> all() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // the native listener writes behind Dart's cache
    final raw = prefs.getString(inboxKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => InboxNotification.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Notifications since the last check (or the last [fallback] if never
  /// checked). Pass [markChecked] to move the "last checked" line forward.
  Future<List<InboxNotification>> missed({Duration fallback = const Duration(hours: 12), bool markChecked = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(lastCheckedKey);
    final since = lastMs == null ? DateTime.now().subtract(fallback) : DateTime.fromMillisecondsSinceEpoch(lastMs);
    final items = (await all()).where((n) => n.posted.isAfter(since)).toList();
    if (markChecked) await prefs.setInt(lastCheckedKey, DateTime.now().millisecondsSinceEpoch);
    return items;
  }

  Future<Set<String>> mutedApps() async {
    final raw = (await SharedPreferences.getInstance()).getString(mutedKey);
    return raw == null ? {} : (jsonDecode(raw) as List).cast<String>().toSet();
  }

  /// Stop collecting from [package] (the native side reads this list).
  Future<void> setMuted(String package, bool muted) async {
    final apps = await mutedApps();
    muted ? apps.add(package) : apps.remove(package);
    await (await SharedPreferences.getInstance()).setString(mutedKey, jsonEncode(apps.toList()));
  }

  /// Short lines for a briefing: the important ones only.
  Future<List<String>> briefingLines({int max = 6}) async {
    final groups = NotificationTriage.sort(await missed());
    final important = [...groups[NotificationPriority.urgent]!, ...groups[NotificationPriority.actionable]!];
    return [for (final n in important.take(max)) '${n.app}: ${n.title}${n.text.isEmpty ? '' : ' — ${n.text}'}'];
  }
}
