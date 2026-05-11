import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idz_flutter/src/webhooks/idz_webhooks.dart';

void main() {
  const secret = 'whsec_examplesecret';
  final body = utf8.encode('{"id":"evt_1","type":"verification.completed"}');

  String sign(int t) {
    final mac = Hmac(
      sha256,
      utf8.encode(secret),
    ).convert([...utf8.encode('$t.'), ...body]).toString();
    return 't=$t,v1=$mac';
  }

  group('IdzWebhooks.verifySignature', () {
    test('accepts a valid signature within tolerance', () {
      final t = 1746500000;
      final ok = IdzWebhooks.verifySignature(
        secret: secret,
        body: body,
        signatureHeader: sign(t),
        toleranceSeconds: 300,
        now: DateTime.fromMillisecondsSinceEpoch(t * 1000),
      );
      expect(ok, isTrue);
    });

    test('rejects when signature does not match', () {
      final t = 1746500000;
      final ok = IdzWebhooks.verifySignature(
        secret: 'wrong_secret',
        body: body,
        signatureHeader: sign(t),
        now: DateTime.fromMillisecondsSinceEpoch(t * 1000),
      );
      expect(ok, isFalse);
    });

    test('rejects when timestamp is older than tolerance', () {
      final t = 1746500000;
      final ok = IdzWebhooks.verifySignature(
        secret: secret,
        body: body,
        signatureHeader: sign(t),
        toleranceSeconds: 60,
        now: DateTime.fromMillisecondsSinceEpoch((t + 3600) * 1000),
      );
      expect(ok, isFalse);
    });

    test('rejects when header is malformed', () {
      final t = 1746500000;
      expect(
        IdzWebhooks.verifySignature(
          secret: secret,
          body: body,
          signatureHeader: 'not-a-valid-header',
          now: DateTime.fromMillisecondsSinceEpoch(t * 1000),
        ),
        isFalse,
      );
      expect(
        IdzWebhooks.verifySignature(
          secret: secret,
          body: body,
          signatureHeader: 'v1=onlysig',
          now: DateTime.fromMillisecondsSinceEpoch(t * 1000),
        ),
        isFalse,
      );
    });

    test('rejects body tampering', () {
      final t = 1746500000;
      final tamperedBody = utf8.encode('{"id":"evt_1","tampered":true}');
      final ok = IdzWebhooks.verifySignature(
        secret: secret,
        body: tamperedBody,
        signatureHeader: sign(t),
        now: DateTime.fromMillisecondsSinceEpoch(t * 1000),
      );
      expect(ok, isFalse);
    });
  });
}
