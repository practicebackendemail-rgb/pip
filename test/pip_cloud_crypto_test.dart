import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/services/sync/pip_cloud_crypto_service.dart';

void main() {
  group('PipCloudCryptoService Unit Tests', () {
    const passphrase = 'SuperSecurePassword123!';
    const plaintext = 'User prefers mornings, lives in Cambridge, loves Earl Grey.';

    test('performs complete encrypt-decrypt roundtrip', () async {
      final encrypted = await PipCloudCryptoService.encryptPayload(plaintext, passphrase);
      expect(encrypted, contains('envelope_version'));
      expect(encrypted, contains('pbkdf2_hmac_sha256'));

      final decrypted = await PipCloudCryptoService.decryptPayload(encrypted, passphrase);
      expect(decrypted, equals(plaintext));
    });

    test('fails decryption when provided with wrong passphrase', () async {
      final encrypted = await PipCloudCryptoService.encryptPayload(plaintext, passphrase);
      expect(
        () async => await PipCloudCryptoService.decryptPayload(encrypted, 'WrongPassword456!'),
        throwsA(anything),
      );
    });

  });
}
