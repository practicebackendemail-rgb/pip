/// How Pip talks about actions: asking for confirmation in plain words,
/// understanding a spoken yes or no, and summarising a real tool result.
library;

enum ConfirmAnswer { yes, no }

final _yes = RegExp(
    r"^(yes|yeah|yep|yup|sure|ok|okay|alright|do it|go ahead|go for it|confirm|please do|sounds good|send it|add it|"
    r"yes please|of course|absolutely)\b");
final _no = RegExp(r"^(no|nope|nah|cancel|stop|don'?t|do not|never ?mind|wait|hold on|not now)\b");

/// Reads a spoken reply to "shall I…?". Returns null when it's neither.
ConfirmAnswer? parseConfirmation(String text) {
  final t = text.toLowerCase().replaceAll(RegExp(r'[^a-z\s\x27]'), '').trim();
  if (_no.hasMatch(t)) return ConfirmAnswer.no;
  if (_yes.hasMatch(t)) return ConfirmAnswer.yes;
  return null;
}

/// True for actions that must be confirmed by tapping, never by voice alone
/// (sending email to someone else is irreversible).
bool needsTapToConfirm(String? level) => level != null && level.contains('level3');

String _time(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute == 0 ? '' : ':${d.minute.toString().padLeft(2, '0')}';
  return '$h$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

String _day(DateTime d, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
  if (diff == 0) return 'today';
  if (diff == 1) return 'tomorrow';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return 'on ${d.day} ${months[d.month - 1]}${d.year != now.year ? ' ${d.year}' : ''}';
}

/// "Add 'Leave' to your calendar today at 4 PM for 30 minutes?" instead of
/// "Should I proceed with executing create_calendar_event?".
String describePendingAction(String tool, Map<String, dynamic> args, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  String arg(String k) => '${args[k] ?? ''}'.trim();
  switch (tool) {
    case 'create_calendar_event':
      final start = DateTime.tryParse(arg('start_iso'))?.toLocal();
      final mins = int.tryParse(arg('duration_minutes'));
      final when = start == null ? '' : ' ${_day(start, clock)} at ${_time(start)}';
      final length = mins == null ? '' : ' for $mins minutes';
      return "Add '${arg('title')}' to your calendar$when$length?";
    case 'send_email':
      return "Send the email '${arg('subject')}' to ${arg('recipient')}?";
    case 'set_reminder':
      final secs = int.tryParse(arg('delay_seconds'));
      final when = DateTime.tryParse(arg('at_iso')) ?? (secs == null ? null : clock.add(Duration(seconds: secs)));
      final at = when != null ? ' ${_day(when, clock)} at ${_time(when)}' : (arg('time').isEmpty ? '' : ' at ${arg('time')}');
      return "Remind you about '${arg('title')}'$at?";
    case 'cancel_reminder':
      return "Cancel your '${arg('query')}' alarm or reminder?";
  }
  return 'Go ahead with ${tool.replaceAll('_', ' ')}?';
}

/// Spoken summary built from the tool's real result, not the model's guess.
String describeToolResult(String toolName, Map<String, dynamic> result) {
  final status = result['status'];
  switch (status) {
    case 'sent':
      return "Done! Your email to ${result['recipient']} has been sent.";
    case 'scheduled':
      final at = DateTime.tryParse('${result['scheduled_time']}');
      return at == null ? 'Reminder set.' : 'Reminder set for ${_time(at)}.';
    case 'created':
      if (result['kind'] == 'alarm') {
        final at = DateTime.tryParse('${result['time']}');
        return at == null ? 'Alarm set.' : 'Alarm set for ${_time(at)}.';
      }
      return "Done! It's on your calendar.";
    case 'cancelled':
      return "Done, '${result['title']}' is cancelled.";
    case 'cancel_requested':
      return "I've opened your Clock app so you can remove '${result['title']}'.";
  }
  return "Done! ${toolName.replaceAll('_', ' ')} finished${status != null ? ' ($status)' : ''}.";
}
