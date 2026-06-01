import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Secure PIN hashing utility for staff authentication.
///
/// Uses SHA-256 with a static salt. While not bcrypt-grade,
/// it's dramatically better than plaintext and appropriate for
/// a 4-6 digit numeric PIN in a retail ERP context.
class PinHasher {
  // Salt prefix — prevents rainbow table attacks on short PINs
  static const _salt = 'skywalk_erp_v1_';

  /// Hash a raw PIN string. Returns a hex-encoded SHA-256 digest.
  static String hash(String rawPin) {
    final bytes = utf8.encode('$_salt$rawPin');
    final digest = sha256.convert(bytes);
    return digest.toString(); // 64-char hex string
  }

  /// Verify a raw PIN against a stored hash.
  static bool verify(String rawPin, String storedHash) {
    // Backward compatibility: if stored value is a short numeric string
    // (plaintext PIN from before migration), compare directly
    if (storedHash.length <= 6 && RegExp(r'^\d+$').hasMatch(storedHash)) {
      return rawPin == storedHash;
    }
    return hash(rawPin) == storedHash;
  }
}
