import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/services/pip_live_voice_service.dart';

void main() {
  group('Phase 8: Live Voice Status & Transparency Tests', () {
    test('PipLiveVoicePlaceholder explicitly reports unbuilt status (isImplemented == false)', () async {
      expect(PipLiveVoicePlaceholder.isImplemented, isFalse);

      final service = PipLiveVoicePlaceholder();
      expect(service.status, equals(LiveSessionStatus.disconnected));
      expect(service.isBargeInActive, isFalse);

      await service.connect(apiKey: 'dummy_key');
      expect(service.status, equals(LiveSessionStatus.disconnected));
    });
  });
}
