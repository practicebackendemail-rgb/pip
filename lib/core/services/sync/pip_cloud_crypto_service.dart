import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

/// Versioned, authenticated encryption envelope for user-owned cloud backups.
/// Upgrades basic SHA-256 derivation to PBKDF2 with SHA-256, 100,000 iterations, and random 128-bit salt.
class PipCloudCryptoService {
  PipCloudCryptoService._();

  static final AesGcm _cipher = AesGcm.with256bits();

  /// Derives a 256-bit AES key using PBKDF2-HMAC-SHA256 with random/provided salt.
  static Future<SecretKey> deriveKeyPbkdf2({
    required String passphrase,
    required List<int> salt,
    int iterations = 100000,
  }) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    final secretKey = SecretKey(utf8.encode(passphrase));
    return await pbkdf2.deriveKey(
      secretKey: secretKey,
      nonce: salt,
    );
  }

  /// Encrypts plaintext into a version 2 envelope.
  static Future<String> encryptPayload(String plaintext, String passphrase) async {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final key = await deriveKeyPbkdf2(passphrase: passphrase, salt: salt);

    final secretBox = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
    );

    final envelope = {
      'envelope_version': 2,
      'kdf': 'pbkdf2_hmac_sha256',
      'iterations': 100000,
      'salt': base64Encode(salt),
      'nonce': base64Encode(secretBox.nonce),
      'cipher': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    };

    return jsonEncode(envelope);
  }

  /// Decrypts payload supporting backward compatibility with version 1 (SHA-256 legacy).
  static Future<String> decryptPayload(String encryptedJson, String passphrase) async {
    final map = jsonDecode(encryptedJson) as Map<String, dynamic>;
    final version = map['envelope_version'] as int? ?? 1;

    final nonce = base64Decode(map['nonce'] as String);
    final cipher = base64Decode(map['cipher'] as String);
    final macBytes = base64Decode(map['mac'] as String);
    final secretBox = SecretBox(cipher, nonce: nonce, mac: Mac(macBytes));

    SecretKey key;
    if (version == 2) {
      final salt = base64Decode(map['salt'] as String);
      final iterations = (map['iterations'] as int?) ?? 100000;
      key = await deriveKeyPbkdf2(passphrase: passphrase, salt: salt, iterations: iterations);
    } else {
      // Version 1 legacy fallback
      final hash = await Sha256().hash(utf8.encode(passphrase));
      key = SecretKey(hash.bytes);
    }

    final decryptedBytes = await _cipher.decrypt(
      secretBox,
      secretKey: key,
    );
    return utf8.decode(decryptedBytes);
  }

  /// Generates a human-readable 16-character alphanumeric emergency recovery code.
  static String generateRecoveryCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final parts = <String>[];
    for (int i = 0; i < 4; i++) {
      final chunk = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
      parts.add(chunk);
    }
    return parts.join('-');
  }
}
