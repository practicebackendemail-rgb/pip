import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/services/tools/notification_tools.dart';
import 'package:personal_assistant/features/notifications/data/notification_inbox.dart';
import 'package:personal_assistant/features/notifications/domain/inbox_notification.dart';
import 'package:shared_preferences/shared_preferences.dart';

InboxNotification n(String app, String title, {String text = '', String package = 'x', String category = '', int minsAgo = 5}) =>
    InboxNotification(
      key: '$app$title',
      package: package,
      app: app,
      title: title,
      text: text,
      category: category,
      posted: DateTime.now().subtract(Duration(minutes: minsAgo)),
    );

/// What the Android listener writes (same JSON shape and key).
Map<String, Object> stored(List<Map<String, Object>> items) => {NotificationInbox.inboxKey: jsonEncode(items)};

Map<String, Object> raw(String app, String title, {int minsAgo = 5, String package = 'com.app'}) => {
      'key': '$app-$title',
      'package': package,
      'app': app,
      'title': title,
      'text': '',
      'category': '',
      'posted': DateTime.now().subtract(Duration(minutes: minsAgo)).millisecondsSinceEpoch,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Triage', () {
    test('urgent words beat everything', () {
      expect(NotificationTriage.classify(n('Phone', 'Missed call from Mum')), NotificationPriority.urgent);
      expect(NotificationTriage.classify(n('Slack', 'Need this ASAP')), NotificationPriority.urgent);
    });

    test('messages, mail and calls are actionable', () {
      expect(NotificationTriage.classify(n('WhatsApp', 'Sam', package: 'com.whatsapp')), NotificationPriority.actionable);
      expect(NotificationTriage.classify(n('Mail', 'Invoice', category: 'email')), NotificationPriority.actionable);
    });

    test('promotions are noise, the rest is info', () {
      expect(NotificationTriage.classify(n('Shop', '50% off today only')), NotificationPriority.noise);
      expect(NotificationTriage.classify(n('YouTube', 'x', category: 'recommendation')), NotificationPriority.noise);
      expect(NotificationTriage.classify(n('Weather', 'Rain at 6pm')), NotificationPriority.info);
    });

    test('sorting groups by priority, newest first', () {
      final groups = NotificationTriage.sort([
        n('Weather', 'Rain', minsAgo: 30),
        n('Weather', 'Sun', minsAgo: 5),
        n('Phone', 'Missed call', minsAgo: 10),
      ]);
      expect(groups[NotificationPriority.urgent]!.single.title, 'Missed call');
      expect(groups[NotificationPriority.info]!.map((e) => e.title), ['Sun', 'Rain']);
    });
  });

  group('Inbox', () {
    test('reads what the listener stored and only returns what is new since the last check', () async {
      SharedPreferences.setMockInitialValues(stored([
        raw('WhatsApp', 'Sam: lunch?', minsAgo: 20),
        raw('News', 'Old story', minsAgo: 60 * 24),
      ]));
      final inbox = NotificationInbox();
      final first = await inbox.missed(markChecked: true);
      expect(first.map((e) => e.title), ['Sam: lunch?']); // the day-old one is past the 12 h window
      expect(await inbox.missed(), isEmpty); // nothing new since that check
    });

    test('muting an app is remembered for the native side', () async {
      SharedPreferences.setMockInitialValues({});
      final inbox = NotificationInbox();
      await inbox.setMuted('com.spam', true);
      expect(await inbox.mutedApps(), {'com.spam'});
      await inbox.setMuted('com.spam', false);
      expect(await inbox.mutedApps(), isEmpty);
    });

    test('briefing lines include only important notifications', () async {
      SharedPreferences.setMockInitialValues(stored([
        raw('WhatsApp', 'Sam', package: 'com.whatsapp'),
        raw('Shop', '20% off everything'),
      ]));
      final lines = await NotificationInbox().briefingLines();
      expect(lines, ['WhatsApp: Sam']);
    });

    test('counts-only lines keep contents on the device', () async {
      SharedPreferences.setMockInitialValues(stored([
        raw('WhatsApp', 'Sam: secret', package: 'com.whatsapp'),
        raw('WhatsApp', 'Mum: call me', package: 'com.whatsapp'),
      ]));
      expect(await NotificationInbox().briefingLines(countsOnly: true), ['2 from WhatsApp']);
    });

    test('a corrupt inbox reads as empty rather than crashing', () async {
      SharedPreferences.setMockInitialValues({NotificationInbox.inboxKey: '{not json'});
      expect(await NotificationInbox().all(), isEmpty);
    });
  });

  test('the tool explains itself off Android instead of failing', () async {
    final res = await MissedNotificationsTool().execute({});
    expect(res['error'], contains('Android'));
  });
}
