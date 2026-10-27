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
    if (clock != null) return nextClockTime(clock.$1, clock.$2, now: t);
  }
  if (delaySeconds != null && delaySeconds > 0) return t.add(Duration(seconds: delaySeconds));
  return null;
}

/// The next time the clock reads [hour]:[minute], today or tomorrow.
DateTime nextClockTime(int hour, int minute, {DateTime? now}) {
  final t = now ?? DateTime.now();
  final at = DateTime(t.year, t.month, t.day, hour, minute);
  return at.isAfter(t) ? at : DateTime(t.year, t.month, t.day + 1, hour, minute);
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

/// Short label for repeat days: "Every day", "Weekdays", "Weekends", "Mon, Wed".
String describeDays(List<int> days) {
  final set = days.toSet();
  if (set.length == 7) return 'Every day';
  if (set.length == 5 && set.containsAll(const [1, 2, 3, 4, 5])) return 'Weekdays';
  if (set.length == 2 && set.containsAll(const [6, 7])) return 'Weekends';
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return ([...set]..sort()).map((d) => names[d - 1]).join(', ');
}
