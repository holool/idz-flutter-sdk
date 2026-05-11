import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Helpers for verifying IDz webhook deliveries.
///
/// Each delivery carries an `X-IDz-Signature` header of the form
/// `t=<unix_seconds>,v1=<hex_sha256>`. The signature is
/// `HMAC_SHA256(endpoint_secret, "<t>.<raw_body>")`.
///
/// Always verify the signature **before** trusting the body and reject
/// requests where the timestamp drifts more than the tolerance — that's
/// your replay defence.
class IdzWebhooks {
  IdzWebhooks._();

  /// Verify a delivery.
  ///
  /// - [secret] is the `signing_secret` returned exactly once when you
  ///   created (or rotated) the webhook endpoint.
  /// - [body] is the raw request body bytes as received. Do not parse
  ///   first — the signature is over the bytes, not the parsed JSON.
  /// - [signatureHeader] is the value of the `X-IDz-Signature` header.
  /// - [toleranceSeconds] rejects timestamps farther than this from
  ///   `now`. Default 5 minutes, matching the API.
  /// - [now] override for tests.
  ///
  /// Returns `true` only when the signature matches and the timestamp
  /// is within tolerance. Returns `false` for malformed headers,
  /// signature mismatches, and stale timestamps.
  static bool verifySignature({
    required String secret,
    required List<int> body,
    required String signatureHeader,
    int toleranceSeconds = 300,
    DateTime? now,
  }) {
    final parts = <String, String>{};
    for (final raw in signatureHeader.split(',')) {
      final eq = raw.indexOf('=');
      if (eq <= 0) continue;
      parts[raw.substring(0, eq).trim()] = raw.substring(eq + 1).trim();
    }
    final tStr = parts['t'];
    final v1 = parts['v1'];
    if (tStr == null || v1 == null) return false;

    final t = int.tryParse(tStr);
    if (t == null) return false;

    // Replay defence — reject far-future or far-past timestamps.
    final nowEpoch = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    if ((nowEpoch - t).abs() > toleranceSeconds) return false;

    // sig = HMAC_SHA256(secret, "<t>.<raw_body>")
    final hmac = Hmac(sha256, utf8.encode(secret));
    final builder = BytesBuilder()
      ..add(utf8.encode('$t.'))
      ..add(body);
    final mac = hmac.convert(builder.toBytes()).toString();

    return _constantTimeEquals(mac, v1);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
