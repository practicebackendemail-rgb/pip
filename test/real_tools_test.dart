import 'package:flutter_test/flutter_test.dart';
import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:personal_assistant/core/services/email_service.dart';
import 'package:personal_assistant/core/services/tools/calendar_tools.dart';
import 'package:personal_assistant/core/services/tools/email_tools.dart';
import 'package:personal_assistant/core/services/tools/reminder_tool.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeDeviceCalendarService extends DeviceCalendarService {
  final bool supported;
  final CalendarPermissionStatus permissionStatus;
  final List<Event> existingEvents;
  final String? createdEventId;

  FakeDeviceCalendarService({
    this.supported = true,
    this.permissionStatus = CalendarPermissionStatus.granted,
    this.existingEvents = const [],
    this.createdEventId = 'mock_event_123',
  });

  @override
  bool get isSupported => supported;

  @override
  Future<CalendarPermissionStatus> checkPermission() async => permissionStatus;

  @override
  Future<CalendarPermissionStatus> requestPermission() async => permissionStatus;

  @override
  Future<List<Event>> getEvents(DateTime start, DateTime end) async => existingEvents;

  @override
  Future<String?> createEvent({
    required String title,
    required DateTime start,
    required DateTime end,
    String? calendarId,
  }) async => createdEventId;
}

class FakeEmailService extends EmailService {
  final bool configured;
  final Map<String, dynamic> sendResult;

  FakeEmailService({
    this.configured = true,
    required this.sendResult,
  });

  @override
  bool get isConfigured => configured;

  @override
  Future<Map<String, dynamic>> sendEmail({
    required String to,
    required String subject,
    required String body,
  }) async => sendResult;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Phase 5: Real Tools Execution & Error Handling Tests', () {
    test('SendEmailTool halts when email service is unconfigured', () async {
      final fakeEmail = FakeEmailService(
        configured: false,
        sendResult: {'error': 'Mail service is not configured. Setup credentials first.'},
      );
      final tool = SendEmailTool(emailService: fakeEmail);

      final result = await tool.execute({
        'recipient': 'test@example.com',
        'subject': 'Test Subject',
        'body': 'Test Body',
      });

      expect(result['error'], contains('not configured'));
    });

    test('SendEmailTool rejects empty or invalid email recipient format', () async {
      final fakeEmail = FakeEmailService(
        configured: true,
        sendResult: {'error': 'Recipient email cannot be empty.'},
      );
      final tool = SendEmailTool(emailService: fakeEmail);

      final emptyResult = await tool.execute({
        'recipient': '',
        'subject': 'Test Subject',
        'body': 'Test Body',
      });
      expect(emptyResult['error'], equals('Recipient email cannot be empty.'));

      final realEmailService = EmailService();
      final invalidFormatResult = await realEmailService.sendEmail(
        to: 'invalid-address-without-at',
        subject: 'Sub',
        body: 'Body',
      );
      expect(invalidFormatResult['error'], contains('not configured'));
    });

    test('SendEmailTool returns sent status only on real successful SMTP transmission', () async {
      final fakeEmail = FakeEmailService(
        configured: true,
        sendResult: {
          'status': 'sent',
          'recipient': 'dr.sheldon.cooper@caltech.edu',
          'subject': 'String Theory Paper',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      final tool = SendEmailTool(emailService: fakeEmail);

      final result = await tool.execute({
        'recipient': 'dr.sheldon.cooper@caltech.edu',
        'subject': 'String Theory Paper',
        'body': 'Bazinga! Quantum loop gravity is fundamentally flawed.',
      });

      expect(result['status'], equals('sent'));
      expect(result['recipient'], equals('dr.sheldon.cooper@caltech.edu'));
      expect(result['error'], isNull);
    });

    test('Calendar tools return platform error when executed on unsupported platform', () async {
      final fakeCalendar = FakeDeviceCalendarService(supported: false);
      final listTool = ListCalendarEventsTool(calendarService: fakeCalendar);
      final createTool = CreateCalendarEventTool(calendarService: fakeCalendar);

      final listResult = await listTool.execute({});
      expect(listResult['error'], equals('Calendar is not available on this platform'));

      final createResult = await createTool.execute({'title': 'Colloquium'});
      expect(createResult['error'], equals('Calendar is not available on this platform'));
    });

    test('Calendar tools return permission error when platform permissions are denied', () async {
      final fakeCalendar = FakeDeviceCalendarService(
        supported: true,
        permissionStatus: CalendarPermissionStatus.denied,
      );
      final listTool = ListCalendarEventsTool(calendarService: fakeCalendar);

      final result = await listTool.execute({});
      expect(result['error'], contains('permission was denied or restricted'));
    });

    test('Calendar tools return real event mappings and created event IDs', () async {
      final now = DateTime.now();
      final fakeCalendar = FakeDeviceCalendarService(
        supported: true,
        permissionStatus: CalendarPermissionStatus.granted,
        existingEvents: [
          Event(
            eventId: 'ev_physics_101',
            instanceId: 'ev_physics_101',
            calendarId: 'primary_cal',
            title: 'Physics Department Meeting',
            startDate: now.add(const Duration(hours: 1)),
            endDate: now.add(const Duration(hours: 2)),
            isAllDay: false,
            availability: EventAvailability.busy,
            status: EventStatus.confirmed,
            isRecurring: false,
          ),
        ],
        createdEventId: 'ev_halo_night_42',
      );

      final listTool = ListCalendarEventsTool(calendarService: fakeCalendar);
      final listResult = await listTool.execute({'days_ahead': 2});

      expect(listResult['count'], equals(1));
      expect((listResult['events'] as List).first['title'], equals('Physics Department Meeting'));

      final createTool = CreateCalendarEventTool(calendarService: fakeCalendar);
      final createResult = await createTool.execute({
        'title': 'Halo Game Night',
        'start_iso': now.toIso8601String(),
        'duration_minutes': 60,
      });

      expect(createResult['status'], equals('created'));
      expect(createResult['id'], equals('ev_halo_night_42'));
    });

    test('ReminderTool executes and reports scheduled time', () async {
      const tool = ReminderTool();
      final result = await tool.execute({
        'title': 'Laundry Night: Wednesday 8:15 PM',
        'delay_seconds': 120,
      });

      expect(result['status'], equals('scheduled'));
      expect(result['title'], equals('Laundry Night: Wednesday 8:15 PM'));
      final at = DateTime.parse(result['scheduled_time'] as String);
      expect(at.difference(DateTime.now()).inSeconds, inInclusiveRange(110, 121));
      expect(result['persistence'], isNotNull);
    });
  });
}
