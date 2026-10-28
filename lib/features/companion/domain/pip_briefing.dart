import '../../../core/domain/llm_provider.dart';
import '../../../models/task_model.dart';
import '../../activity/domain/activity_entry.dart';

/// The day's briefing: what Pip asks the model, and the activity entry it
/// leaves behind. Kept out of the cubit so the cubit stays small.
abstract final class PipBriefing {
  static const Duration timeout = Duration(seconds: 45);

  static String prompt({
    required List<String> tasks,
    required List<String> emails,
    List<String> notifications = const [],
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    // The briefing screen lists every task, event and email itself; Pip only
    // adds the headline, so this stays short and quick.
    return 'You are Pip. In one or two short sentences (under 40 words), tell your owner what matters most '
        'today, ${t.year}-${t.month}-${t.day}: lead with anything overdue or urgent, then how the day looks. '
        'Plain text only: no bullets, no markdown, no lists, no greeting. Mention only items given below.\n'
        'Open tasks: ${tasks.isEmpty ? 'none' : tasks.join('; ')}\n'
        'Recent emails: ${emails.isEmpty ? 'none' : emails.join('; ')}\n'
        'Important notifications: ${notifications.isEmpty ? 'none' : notifications.join('; ')}';
  }

  /// "File taxes (overdue since 26 Oct)", "Send deck (due today)", "Book dentist".
  static String taskLine(TaskItem task, {DateTime? now}) {
    final due = task.dueDate;
    if (due == null) return task.title;
    final t = now ?? DateTime.now();
    final today = DateTime(t.year, t.month, t.day);
    final day = DateTime(due.year, due.month, due.day);
    if (day.isBefore(today)) return '${task.title} (overdue since ${due.day}/${due.month})';
    if (day == today) return '${task.title} (due today)';
    return '${task.title} (due ${due.day}/${due.month})';
  }

  static Future<String> compose(
    LlmProvider provider, {
    required List<String> tasks,
    required List<String> emails,
    List<String> notifications = const [],
  }) async {
    final response = await provider
        .chat([LlmMessage(role: 'user', content: prompt(tasks: tasks, emails: emails, notifications: notifications))])
        .timeout(timeout);
    return response.text;
  }

  static ActivityEntry activity({required int tasks, required int emails, DateTime? now}) {
    final t = now ?? DateTime.now();
    return ActivityEntry(
      id: 'brief-${t.microsecondsSinceEpoch}',
      kind: ActivityKind.briefing,
      title: 'Briefed you',
      detail: '$tasks open tasks, $emails emails',
      at: t,
    );
  }
}
