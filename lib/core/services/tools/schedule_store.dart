import 'dart:async';
import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'schedule_time.dart';

/// Something Pip scheduled: a reminder (notification) or an alarm.
class ScheduledItem extends Equatable {
  static const String reminder = 'reminder';
  static const String alarm = 'alarm';

  final int id;
  final String kind; // reminder | alarm
  final String title;

  /// When it fires. For repeating items only the time of day matters.
  final DateTime at;

  /// Repeat days, 1 = Monday … 7 = Sunday. Empty means once.
  final List<int> days;

  /// True for alarms created in the phone's Clock app by older versions of
  /// Pip. Pip can't read or edit those, only ask the Clock app to dismiss them.
  final bool inClockApp;

  /// Switched off items stay in the list but don't fire.
  final bool enabled;

  const ScheduledItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.at,
    this.days = const [],
    this.inClockApp = false,
    this.enabled = true,
  });

  bool get repeats => days.isNotEmpty;
  bool get isAlarm => kind == alarm;

  /// The next time this fires at or after [now], or null for a one-off that
  /// has already passed.
  DateTime? nextOccurrence({DateTime? now}) {
    final t = now ?? DateTime.now();
    if (!repeats) return at.isAfter(t) ? at : null;
    for (var i = 0; i < 8; i++) {
      final d = DateTime(t.year, t.month, t.day + i, at.hour, at.minute);
      if (days.contains(d.weekday) && d.isAfter(t)) return d;
    }
    return null;
  }

  ScheduledItem copyWith({String? kind, String? title, DateTime? at, List<int>? days, bool? enabled}) => ScheduledItem(
        id: id,
        kind: kind ?? this.kind,
        title: title ?? this.title,
        at: at ?? this.at,
        days: days ?? this.days,
        inClockApp: inClockApp,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'title': title,
        'at': at.toIso8601String(),
        'days': days,
        'in_clock_app': inClockApp,
        'enabled': enabled,
      };

  factory ScheduledItem.fromJson(Map<String, dynamic> j) => ScheduledItem(
        id: j['id'] as int,
        kind: j['kind'] as String? ?? reminder,
        title: j['title'] as String? ?? '',
        at: DateTime.parse(j['at'] as String),
        days: ((j['days'] as List?) ?? const []).cast<int>(),
        inClockApp: j['in_clock_app'] as bool? ?? false,
        enabled: j['enabled'] as bool? ?? true,
      );

  @override
  List<Object?> get props => [id, kind, title, at, days, inClockApp, enabled];
}

/// A fresh id for a new item. Kept below 10^8 so notification ids derived
/// from it (id * 10 + slot) fit Android's 32-bit notification ids.
int newScheduleId() => DateTime.now().millisecondsSinceEpoch % 100000000;

/// Pip's own list of what it scheduled, so it can answer "what alarms do I
/// have?", show them on the Alarms & reminders screen, and cancel them.
class ScheduleStore {
  static const String _key = 'pip_scheduled_items';
  static final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Fires after every add, update or remove, from the tools or the screen.
  static Stream<void> get changes => _changes.stream;

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
    _changes.add(null);
  }

  static Future<void> add(ScheduledItem item) async => _save([...await all(), item]);

  /// Replaces the item with the same id, or adds it.
  static Future<void> upsert(ScheduledItem item) async {
    final items = await all();
    final i = items.indexWhere((e) => e.id == item.id);
    i < 0 ? items.add(item) : items[i] = item;
    await _save(items);
  }

  static Future<void> remove(int id) async => _save((await all()).where((e) => e.id != id).toList());

  static Future<ScheduledItem?> byId(int id) async {
    for (final e in await all()) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Upcoming items, soonest first. One-off items in the past are dropped;
  /// switched-off items are kept.
  static Future<List<ScheduledItem>> upcoming({DateTime? now}) async {
    final t = now ?? DateTime.now();
    final items = await all();
    final live = items.where((e) => e.repeats || e.at.isAfter(t)).toList();
    if (live.length != items.length) await _save(live);
    DateTime key(ScheduledItem e) => e.nextOccurrence(now: t) ?? e.at;
    return live..sort((a, b) => key(a).compareTo(key(b)));
  }

  /// Items whose title contains [query] (case-insensitive), or whose id matches.
  static Future<List<ScheduledItem>> find(String query) async {
    final q = query.trim().toLowerCase();
    final id = int.tryParse(q);
    return (await upcoming()).where((e) => e.id == id || (q.isNotEmpty && e.title.toLowerCase().contains(q))).toList();
  }
}
