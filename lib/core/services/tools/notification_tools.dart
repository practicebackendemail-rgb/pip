import '../../../features/notifications/data/notification_inbox.dart';
import '../../../features/notifications/domain/inbox_notification.dart';
import '../../domain/pip_tool.dart';

/// "What did I miss?": notifications since the last check, most important
/// first, noise left out unless asked for. Read-only.
class MissedNotificationsTool extends PipTool {
  final NotificationInbox inbox;

  MissedNotificationsTool({NotificationInbox? inbox})
      : inbox = inbox ?? NotificationInbox.instance,
        super(
          name: 'get_missed_notifications',
          description: 'Get the phone notifications the user missed since they last asked, sorted by '
              'importance (urgent, actionable, info). Use for "what did I miss?" and to triage alerts.',
          confirmationLevel: ToolConfirmationLevel.level0ReadOnly,
          parameters: const [
            ToolParameterSpec(
              name: 'include_noise',
              type: 'boolean',
              description: 'Also include promotions and other low-value alerts.',
              isRequired: false,
            ),
          ],
        );

  static const int _maxPerGroup = 8;

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    if (!NotificationInbox.supported) return {'error': 'Reading notifications only works on Android.'};
    if (!await inbox.isEnabled()) {
      return {'error': 'Notification access is off. Turn it on in Settings > Connections > Notifications.'};
    }
    final items = await inbox.missed(markChecked: true);
    final groups = NotificationTriage.sort(items);
    final includeNoise = args['include_noise'] == true;
    Map<String, dynamic> entry(InboxNotification n) => {
          'app': n.app,
          'title': n.title,
          'text': n.text,
          'time': n.posted.toIso8601String(),
        };
    return {
      'total': items.length,
      'urgent': groups[NotificationPriority.urgent]!.take(_maxPerGroup).map(entry).toList(),
      'actionable': groups[NotificationPriority.actionable]!.take(_maxPerGroup).map(entry).toList(),
      'info': groups[NotificationPriority.info]!.take(_maxPerGroup).map(entry).toList(),
      if (includeNoise) 'noise': groups[NotificationPriority.noise]!.take(_maxPerGroup).map(entry).toList(),
      'noise_count': groups[NotificationPriority.noise]!.length,
    };
  }
}
