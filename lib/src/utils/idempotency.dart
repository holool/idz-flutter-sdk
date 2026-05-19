import 'dart:math';

/// Cryptographically-strong UUID v4 generator for `Idempotency-Key`
/// headers. Uses [Random.secure] under the hood, which sources from the
/// platform CSPRNG (`/dev/urandom`, `BCryptGenRandom`, etc).
///
/// Not a general-purpose UUID library — only the v4 (random) variant is
/// supported, which is the only one IDz uses. Format matches RFC 4122:
/// `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx` where `y ∈ {8,9,a,b}`.
class IdempotencyKey {
  IdempotencyKey._();

  static final Random _rng = Random.secure();

  /// Generate a fresh UUID v4. Each call returns a new value.
  static String generate() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }
}
