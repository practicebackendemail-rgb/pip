import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/domain/pip_tool.dart';
import 'package:personal_assistant/core/services/tools/email_tools.dart';
import 'package:personal_assistant/core/services/tools/weather_tool.dart';
import 'package:personal_assistant/core/services/email_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pip Tool Confirmation Level Tests', () {
    test('weather tool is Level 0 (read-only)', () {
      const weather = WeatherTool();
      expect(weather.confirmationLevel, equals(ToolConfirmationLevel.level0ReadOnly));
      expect(weather.isReadOnly, isTrue);
    });

    test('draft email is Level 1 (confirm action)', () {
      const draft = DraftEmailTool();
      expect(draft.confirmationLevel, equals(ToolConfirmationLevel.level1ConfirmAction));
      expect(draft.isReadOnly, isFalse);
    });

    test('send email is Level 3 (dangerous double confirm)', () {
      final emailService = EmailService();
      final send = SendEmailTool(emailService: emailService);
      expect(send.confirmationLevel, equals(ToolConfirmationLevel.level3DangerousDoubleConfirm));
      expect(send.isReadOnly, isFalse);
    });
  });
}
