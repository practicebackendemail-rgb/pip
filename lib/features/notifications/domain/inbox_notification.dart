import 'package:equatable/equatable.dart';

/// How much a notification deserves your attention.
enum NotificationPriority { urgent, actionable, info, noise }

/// One notification Pip saw (app, title, trimmed text, time).
class InboxNotification extends Equatable {
  final String key;
  final String package;
  final String app;
  final String title;
  final String text;
  final String category;
  final DateTime posted;

  const InboxNotification({
    required this.key,
    required this.package,
    required this.app,
    required this.title,
    required this.text,
    required this.posted,
    this.category = '',
  });

  factory InboxNotification.fromJson(Map<String, dynamic> j) => InboxNotification(
        key: '${j['key'] ?? ''}',
        package: '${j['package'] ?? ''}',
        app: '${j['app'] ?? j['package'] ?? ''}',
        title: '${j['title'] ?? ''}',
        text: '${j['text'] ?? ''}',
        category: '${j['category'] ?? ''}',
        posted: DateTime.fromMillisecondsSinceEpoch((j['posted'] as num?)?.toInt() ?? 0),
      );

  @override
  List<Object?> get props => [key, posted];
}

/// Sorts notifications by importance with simple, explainable rules
/// (no model call), so triage is instant, offline and testable.
abstract final class NotificationTriage {
  static const _messagingApps = {
    'com.whatsapp', 'org.telegram.messenger', 'org.thoughtcrime.securesms',
    'com.google.android.apps.messaging', 'com.samsung.android.messaging',
    'com.google.android.gm', 'com.microsoft.office.outlook', 'com.Slack',
    'com.microsoft.teams', 'com.discord', 'com.google.android.dialer',
  };
  static final _urgent = RegExp(r'\burgent\b|\basap\b|missed call|emergency|right now|call me', caseSensitive: false);
  static final _noise = RegExp(r'% ?off|\bsale\b|\bdeal\b|\boffer\b|coupon|cashback|subscribe|recommended for you|new episode',
      caseSensitive: false);

  static NotificationPriority classify(InboxNotification n) {
    final body = '${n.title} ${n.text}';
    if (_urgent.hasMatch(body)) return NotificationPriority.urgent;
    if (n.category == 'promo' || n.category == 'recommendation' || _noise.hasMatch(body)) {
      return NotificationPriority.noise;
    }
    const actionableCategories = {'msg', 'call', 'email', 'event', 'reminder', 'alarm'};
    if (actionableCategories.contains(n.category) || _messagingApps.contains(n.package)) {
      return NotificationPriority.actionable;
    }
    return NotificationPriority.info;
  }

  /// Groups by priority (most important first), newest first within each.
  static Map<NotificationPriority, List<InboxNotification>> sort(Iterable<InboxNotification> items) {
    final groups = {for (final p in NotificationPriority.values) p: <InboxNotification>[]};
    for (final n in items) {
      groups[classify(n)]!.add(n);
    }
    for (final list in groups.values) {
      list.sort((a, b) => b.posted.compareTo(a.posted));
    }
    return groups;
  }
}
