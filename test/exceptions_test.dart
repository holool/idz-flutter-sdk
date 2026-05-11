import 'package:flutter_test/flutter_test.dart';
import 'package:idz_flutter/idz_flutter.dart';

void main() {
  group('Either', () {
    test('Right.fold returns the right branch', () {
      final result = Right<KycFailure, String>('ok');
      final matched = result.fold((_) => 'L', (r) => r);
      expect(matched, 'ok');
      expect(result.isRight, isTrue);
      expect(result.isLeft, isFalse);
    });

    test('Left.fold returns the left branch', () {
      final result = Left<KycFailure, String>(const KycFailureNetwork());
      final matched = result.fold((l) => l.toString(), (_) => 'R');
      expect(matched, 'KycFailureNetwork()');
      expect(result.isLeft, isTrue);
      expect(result.isRight, isFalse);
    });
  });

  group('KycFailure variants', () {
    test('all status-code variants instantiate', () {
      const cases = <KycFailure>[
        KycFailureNetwork(),
        KycFailureTimeout(),
        KycFailureUnauthorized('missing_credentials'),
        KycFailureForbidden('ip_not_allowed'),
        KycFailureInvalidInput(
          'document_type missing',
          errorCode: 'unsupported_document_type',
        ),
        KycFailureIdempotencyConflict('still in flight'),
        KycFailureNotFound('not in this org'),
        KycFailureServerError(500, 'boom'),
        KycFailureFileValidation('too large'),
        KycFailureCamera('init failed'),
        KycFailurePermissionDenied('camera'),
        KycFailureUnknown('?'),
      ];
      for (final c in cases) {
        expect(c, isA<KycFailure>());
      }
    });

    test('invalidInput exposes error_code from server', () {
      const f = KycFailureInvalidInput(
        'document_type unknown',
        errorCode: 'unsupported_document_type',
      );
      expect(f.errorCode, 'unsupported_document_type');
    });

    test('switch is exhaustive', () {
      String describe(KycFailure f) => switch (f) {
        KycFailureNetwork() => 'net',
        KycFailureTimeout() => 'timeout',
        KycFailureUnauthorized() => 'auth',
        KycFailureForbidden() => 'forbidden',
        KycFailureInvalidInput() => 'invalid',
        KycFailureIdempotencyConflict() => 'idem',
        KycFailureNotFound() => 'nf',
        KycFailureServerError() => '5xx',
        KycFailureVerificationRejected() => 'rejected',
        KycFailureVerificationAbandoned() => 'abandoned',
        KycFailureVerificationFailed() => 'failed',
        KycFailureFileValidation() => 'file',
        KycFailureCamera() => 'cam',
        KycFailurePermissionDenied() => 'perm',
        KycFailureUnknown() => 'unknown',
      };
      expect(describe(const KycFailureNetwork()), 'net');
    });
  });
}
