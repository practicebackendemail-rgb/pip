import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Something Pip scheduled: a reminder (notification) or an alarm.
class ScheduledItem {
  final int id;
  final String kind; // 'reminder' | 'alarm'
  final String title;
  final DateTime at;

  /// Repeat days, 1 = Monday … 7 = Sunday. Empty means once.
  final List<int> days;

  /// True when the alarm lives in the phone's Clock app (Android) rather
  /// than as a Pip notification.
  final bool inClockApp;

  const ScheduledItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.at,
    this.days = const [],
    this.inClockApp = false,
  });

  bool get repeats => days.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'title': title,
        'at': at.toIso8601String(),
        'days': days,
        'in_clock_app': inClockApp,
      };

  factory ScheduledItem.fromJson(Map<String, dynamic> j) => ScheduledItem(
        id: j['id'] as int,
        kind: j['kind'] as String? ?? 'reminder',
        title: j['title'] as String? ?? '',
        at: DateTime.parse(j['at'] as String),
        days: ((j['days'] as List?) ?? const []).cast<int>(),
        inClockApp: j['in_clock_app'] as bool? ?? false,
      );
}

/// Pip's own list of what it scheduled, so it can answer "what alarms do I
/// have?" and cancel them. Android gives apps no way to read Clock alarms,
/// so this is the source of truth for anything Pip created.
class ScheduleStore {
  static const String _key = 'pip_scheduled_items';

  static Future<List<ScheduledItem>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => ScheduledItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(List<ScheduledItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  static Future<void> add(ScheduledItem item) async => _save([...await all(), item]);

  static Future<void> remove(int id) async => _save((await all()).where((e) => e.id != id).toList());

  /// Upcoming items, soonest first. One-off items in the past are dropped.
  static Future<List<ScheduledItem>> upcoming({DateTime? now}) async {
    final t = now ?? DateTime.now();
    final items = await all();
    final live = items.where((e) => e.repeats || e.at.isAfter(t)).toList();
    if (live.length != items.length) await _save(live);
    return live..sort((a, b) => a.at.compareTo(b.at));
  }

  /// Items whose title contains [query] (case-insensitive), or whose id matches.
  static Future<List<ScheduledItem>> find(String query) async {
    final q = query.trim().toLowerCase();
    final id = int.tryParse(q);
    return (await upcoming()).where((e) => e.id == id || (q.isNotEmpty && e.title.toLowerCase().contains(q))).toList();
  }
}

/// Resolves when something should happen from whichever the model gave:
/// an ISO timestamp, a clock time ("7:30", "7am", "19:00", "6:45 pm"), or a
/// delay. A clock time already past today means tomorrow. Returns null if
/// nothing usable was given.
DateTime? resolveWhen({String? atIso, String? time, int? delaySeconds, DateTime? now}) {
  final t = now ?? DateTime.now();
  if (atIso != null && atIso.trim().isNotEmpty) {
    final parsed = DateTime.tryParse(atIso.trim());
    if (parsed != null) return parsed.isUtc ? parsed.toLocal() : parsed;
  }
  if (time != null && time.trim().isNotEmpty) {
    final clock = parseClockTime(time);
    if (clock != null) {
      var at = DateTime(t.year, t.month, t.day, clock.$1, clock.$2);
      if (!at.isAfter(t)) at = at.add(const Duration(days: 1));
      return at;
    }
  }
  if (delaySeconds != null && delaySeconds > 0) return t.add(Duration(seconds: delaySeconds));
  return null;
}

/// "7", "7am", "7:05 pm", "19:30", "0730" → (hour, minute). Null if invalid.
(int, int)? parseClockTime(String input) {
  final s = input.trim().toLowerCase().replaceAll('.', '');
  final m = RegExp(r'^(\d{1,2})(?::?(\d{2}))?\s*(am|pm|a|p)?$').firstMatch(s);
  if (m == null) return null;
  var hour = int.parse(m.group(1)!);
  final minute = int.tryParse(m.group(2) ?? '0') ?? 0;
  final suffix = m.group(3);
  if (suffix != null) {
    if (hour < 1 || hour > 12) return null;
    final pm = suffix.startsWith('p');
    hour = hour % 12 + (pm ? 12 : 0);
  }
  if (hour > 23 || minute > 59) return null;
  return (hour, minute);
}

/// "weekdays", "weekends", "daily", or "mon,wed,fri" → 1..7 (Monday = 1).
List<int> parseDays(String? input) {
  final s = (input ?? '').toLowerCase();
  if (s.trim().isEmpty) return const [];
  if (s.contains('weekday')) return const [1, 2, 3, 4, 5];
  if (s.contains('weekend')) return const [6, 7];
  if (s.contains('daily') || s.contains('every day') || s.contains('everyday')) return const [1, 2, 3, 4, 5, 6, 7];
  const names = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  return [
    for (var i = 0; i < names.length; i++)
      if (s.contains(names[i])) i + 1,
  ];
}
