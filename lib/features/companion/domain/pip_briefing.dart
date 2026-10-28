import '../../../core/domain/llm_provider.dart';
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
    return 'Write a short daily briefing for ${t.year}-${t.month}-${t.day}, in plain markdown bullets. '
        'Lead with anything urgent, then the plan. Be concrete and brief.\n'
        'Open tasks: ${tasks.isEmpty ? 'none' : tasks.join('; ')}\n'
        'Recent emails: ${emails.isEmpty ? 'none' : emails.join('; ')}\n'
        'Important notifications: ${notifications.isEmpty ? 'none' : notifications.join('; ')}';
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
