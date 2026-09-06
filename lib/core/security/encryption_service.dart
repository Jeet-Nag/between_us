import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Cryptographic service providing pairing code generation,
/// payload integrity checking, and local data obfuscation.
class EncryptionService {
  static final _random = Random.secure();
  static const _codeChars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'; // base32 without confusing chars (0/O, 1/I)

  /// Generates a cryptographically strong 6-character uppercase pairing code.
  static String generatePairingCode() {
    return List.generate(6, (index) => _codeChars[_random.nextInt(_codeChars.length)]).join();
  }

  /// Hashes a sensitive identifier using SHA-256 with a salt
  static String hashWithSalt(String input, String salt) {
    final bytes = utf8.encode('$salt:$input');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generates a unique, non-predictable session token
  static String generateSessionToken() {
    final values = List<int>.generate(32, (i) => _random.nextInt(256));
    return base64Url.encode(values);
  }

  /// Obfuscates local stored tokens
  static String obfuscatePayload(String payload, String key) {
    final payloadBytes = utf8.encode(payload);
    final keyBytes = utf8.encode(key);
    final result = List<int>.generate(
      payloadBytes.length,
      (i) => payloadBytes[i] ^ keyBytes[i % keyBytes.length],
    );
    return base64.encode(result);
  }

  /// Deobfuscates local stored tokens
  static String deobfuscatePayload(String encoded, String key) {
    try {
      final decodedBytes = base64.decode(encoded);
      final keyBytes = utf8.encode(key);
      final result = List<int>.generate(
        decodedBytes.length,
        (i) => decodedBytes[i] ^ keyBytes[i % keyBytes.length],
      );
      return utf8.decode(result);
    } catch (e) {
      return '';
    }
  }
}
