import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:idz_flutter/idz_flutter.dart';
import 'package:idz_flutter/src/client/dio_client.dart';

/// Tiny fake images / videos so MultipartFile.fromFileSync works without
/// hitting the file_validator's content checks (the new client doesn't
/// run the validator, so any non-empty file is fine).
final _bytes = Uint8List.fromList(List<int>.filled(256, 0x42));

void main() {
  late Directory tempDir;
  late File idFront;
  late File idBack;
  late File selfie;
  late File video;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('idz_sdk_test_');
    idFront = File('${tempDir.path}/front.jpg')..writeAsBytesSync(_bytes);
    idBack = File('${tempDir.path}/back.jpg')..writeAsBytesSync(_bytes);
    selfie = File('${tempDir.path}/selfie.jpg')..writeAsBytesSync(_bytes);
    video = File('${tempDir.path}/clip.mp4')..writeAsBytesSync(_bytes);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Fixture matching the API's Verification shape for a successful DL run.
  Map<String, dynamic> verificationOk({
    String mode = 'document',
    String documentType = 'algerian_driving_license',
  }) => <String, dynamic>{
    'id': 'kyc_test0000000001',
    'mode': mode,
    'status': 'completed',
    'created_at': '2026-05-06T12:00:00',
    'completed_at': '2026-05-06T12:00:04',
    'document': {
      'type': documentType,
      'country': 'DZA',
      'fields': {
        'last_name_fr': {
          'raw': 'EXAMPLE',
          'normalized': 'EXAMPLE',
          'valid': true,
          'side': 'front',
        },
      },
    },
    'checks': {
      'document': {'passed': true, 'failure_reason': null},
      'face_match': null,
      'liveness': null,
    },
    'artifacts': const [],
    'metadata': null,
  };

  ({IdzApiClient client, DioAdapter adapter, Dio dio}) makeClient({
    String apiKey = 'idz_test_abc',
  }) {
    final config = IdzConfig(apiKey: apiKey, baseUrl: 'https://test.idz.local');
    final dio = Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        headers: <String, dynamic>{'Authorization': 'Bearer $apiKey'},
      ),
    );
    final adapter = DioAdapter(dio: dio);
    final client = IdzApiClient.withClient(
      config: config,
      client: DioClient.test(dio),
    );
    return (client: client, adapter: adapter, dio: dio);
  }

  group('verifyDocument', () {
    test('sends document_type=algerian_national_id by default', () async {
      final h = makeClient();
      final captured = <RequestOptions>[];
      h.adapter.onPost(
        '/v1/verifications/document',
        (server) => server.reply(
          200,
          verificationOk(documentType: 'algerian_national_id'),
        ),
        data: Matchers.any,
      );
      h.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, handler) {
            captured.add(o);
            handler.next(o);
          },
        ),
      );

      final result = await h.client.verifyDocument(
        idFront: idFront,
        idBack: idBack,
      );

      expect(
        result.isRight,
        isTrue,
        reason: 'expected success, got ${result.fold((l) => l, (r) => r)}',
      );
      result.fold((l) => fail('left: $l'), (v) {
        expect(v.id, 'kyc_test0000000001');
        expect(v.document!.documentType, DocumentType.algerianNationalId);
      });
      expect(
        captured.single.headers['Authorization'],
        equals('Bearer idz_test_abc'),
      );
      final form = captured.single.data as FormData;
      final docType = form.fields
          .firstWhere((e) => e.key == 'document_type')
          .value;
      expect(docType, 'algerian_national_id');
    });

    test('sends explicit document_type and idempotency-key', () async {
      final h = makeClient();
      final captured = <RequestOptions>[];
      h.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, handler) {
            captured.add(o);
            handler.next(o);
          },
        ),
      );
      h.adapter.onPost(
        '/v1/verifications/document',
        (server) => server.reply(200, verificationOk()),
        data: Matchers.any,
      );

      await h.client.verifyDocument(
        idFront: idFront,
        idBack: idBack,
        documentType: DocumentType.algerianDrivingLicense,
        idempotencyKey: 'idem-123',
      );

      expect(captured.single.headers['Idempotency-Key'], 'idem-123');
      final form = captured.single.data as FormData;
      expect(
        form.fields.firstWhere((e) => e.key == 'document_type').value,
        'algerian_driving_license',
      );
    });

    test(
      '400 unsupported_document_type maps to KycFailureInvalidInput',
      () async {
        final h = makeClient();
        h.adapter.onPost(
          '/v1/verifications/document',
          (server) => server.reply(400, {
            'detail': {
              'error': 'unsupported_document_type',
              'message': 'document_type "moroccan_passport" is not supported.',
            },
          }),
          data: Matchers.any,
        );

        final result = await h.client.verifyDocument(
          idFront: idFront,
          idBack: idBack,
        );

        expect(result.isLeft, isTrue);
        result.fold((l) {
          expect(l, isA<KycFailureInvalidInput>());
          final f = l as KycFailureInvalidInput;
          expect(f.errorCode, 'unsupported_document_type');
        }, (_) => fail('expected failure'));
      },
    );

    test(
      '200 with status=rejected wraps Verification in KycFailureVerificationRejected',
      () async {
        final h = makeClient();
        h.adapter.onPost(
          '/v1/verifications/document',
          (server) => server.reply(200, {
            ...verificationOk(),
            'status': 'rejected',
            'checks': {
              'document': {
                'passed': false,
                'failure_reason': 'missing_required_fields',
              },
              'face_match': null,
              'liveness': null,
            },
          }),
          data: Matchers.any,
        );

        final result = await h.client.verifyDocument(
          idFront: idFront,
          idBack: idBack,
        );

        expect(result.isLeft, isTrue);
        result.fold((l) {
          expect(l, isA<KycFailureVerificationRejected>());
          final f = l as KycFailureVerificationRejected;
          expect(
            f.verification.checks.document?.failureReason,
            'missing_required_fields',
          );
        }, (_) => fail('expected failure'));
      },
    );

    test('401 maps to KycFailureUnauthorized', () async {
      final h = makeClient(apiKey: 'idz_bogus');
      h.adapter.onPost(
        '/v1/verifications/document',
        (server) => server.reply(401, {
          'error': 'invalid_api_key',
          'message': 'Key is invalid, expired, or wrong product',
        }),
        data: Matchers.any,
      );

      final result = await h.client.verifyDocument(
        idFront: idFront,
        idBack: idBack,
      );

      expect(result.isLeft, isTrue);
      result.fold(
        (l) => expect(l, isA<KycFailureUnauthorized>()),
        (_) => fail('expected failure'),
      );
    });

    test('409 maps to KycFailureIdempotencyConflict', () async {
      final h = makeClient();
      h.adapter.onPost(
        '/v1/verifications/document',
        (server) => server.reply(409, {
          'error': 'idempotency_conflict',
          'message': 'still in flight',
        }),
        data: Matchers.any,
      );
      final result = await h.client.verifyDocument(
        idFront: idFront,
        idBack: idBack,
        idempotencyKey: 'idem-1',
      );
      expect(result.isLeft, isTrue);
      result.fold(
        (l) => expect(l, isA<KycFailureIdempotencyConflict>()),
        (_) => fail('expected failure'),
      );
    });

    test(
      'status=failed with Abandoned: prefix maps to KycFailureVerificationAbandoned',
      () async {
        final h = makeClient();
        const reason =
            'Abandoned: server stalled or restarted while processing. '
            'Re-submit the verification.';
        h.adapter.onPost(
          '/v1/verifications/document',
          (server) => server.reply(200, {
            ...verificationOk(),
            'status': 'failed',
            'checks': {
              'document': {'passed': null, 'failure_reason': reason},
              'face_match': null,
              'liveness': null,
            },
          }),
          data: Matchers.any,
        );

        final result = await h.client.verifyDocument(
          idFront: idFront,
          idBack: idBack,
        );

        expect(result.isLeft, isTrue);
        result.fold((l) {
          expect(l, isA<KycFailureVerificationAbandoned>());
          final f = l as KycFailureVerificationAbandoned;
          expect(f.reason, startsWith('Abandoned:'));
        }, (_) => fail('expected abandoned failure'));
      },
    );

    test(
      'status=failed without Abandoned: prefix maps to KycFailureVerificationFailed',
      () async {
        final h = makeClient();
        h.adapter.onPost(
          '/v1/verifications/document',
          (server) => server.reply(200, {
            ...verificationOk(),
            'status': 'failed',
            'checks': {
              'document': {
                'passed': false,
                'failure_reason': 'malformed_input',
              },
              'face_match': null,
              'liveness': null,
            },
          }),
          data: Matchers.any,
        );

        final result = await h.client.verifyDocument(
          idFront: idFront,
          idBack: idBack,
        );

        expect(result.isLeft, isTrue);
        result.fold((l) {
          expect(l, isA<KycFailureVerificationFailed>());
          expect(l, isNot(isA<KycFailureVerificationAbandoned>()));
        }, (_) => fail('expected generic failed'));
      },
    );

    test(
      'pollTimeout fires KycFailureTimeout with lastStatus + elapsed when status never goes terminal',
      () async {
        final h = makeClient();
        // POST returns 202-style in_progress. GET keeps returning in_progress.
        h.adapter.onPost(
          '/v1/verifications/document',
          (server) => server.reply(202, {
            ...verificationOk(),
            'status': 'in_progress',
            'completed_at': null,
            'document': null,
          }),
          data: Matchers.any,
        );
        h.adapter.onGet(
          '/v1/verifications/kyc_test0000000001',
          (server) => server.reply(200, {
            ...verificationOk(),
            'status': 'in_progress',
            'completed_at': null,
            'document': null,
          }),
        );

        // 4 s budget — fires after the 2 s poll cadence has at least one tick.
        final result = await h.client.verifyDocument(
          idFront: idFront,
          idBack: idBack,
          pollTimeout: const Duration(seconds: 4),
        );

        expect(result.isLeft, isTrue);
        result.fold((l) {
          expect(l, isA<KycFailureTimeout>());
          final t = l as KycFailureTimeout;
          expect(t.lastStatus, 'in_progress');
          expect(t.elapsed, isNotNull);
          expect(t.elapsed!.inSeconds, greaterThanOrEqualTo(4));
        }, (_) => fail('expected timeout'));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });

  group('verifyIdentity / verifyIdentityLive', () {
    test('verifyIdentity sends selfie alongside id_front + id_back', () async {
      final h = makeClient();
      final captured = <RequestOptions>[];
      h.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, handler) {
            captured.add(o);
            handler.next(o);
          },
        ),
      );
      h.adapter.onPost(
        '/v1/verifications/identity',
        (server) => server.reply(200, verificationOk(mode: 'identity')),
        data: Matchers.any,
      );

      final result = await h.client.verifyIdentity(
        idFront: idFront,
        idBack: idBack,
        selfie: selfie,
      );

      expect(result.isRight, isTrue);
      final form = captured.single.data as FormData;
      final fileKeys = form.files.map((e) => e.key).toSet();
      expect(fileKeys, equals({'id_front', 'id_back', 'selfie'}));
    });

    test('verifyIdentityLive sends video', () async {
      final h = makeClient();
      final captured = <RequestOptions>[];
      h.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, handler) {
            captured.add(o);
            handler.next(o);
          },
        ),
      );
      h.adapter.onPost(
        '/v1/verifications/identity_live',
        (server) => server.reply(200, verificationOk(mode: 'identity_live')),
        data: Matchers.any,
      );

      final result = await h.client.verifyIdentityLive(
        idFront: idFront,
        idBack: idBack,
        selfie: selfie,
        video: video,
      );

      expect(result.isRight, isTrue);
      final form = captured.single.data as FormData;
      final fileKeys = form.files.map((e) => e.key).toSet();
      expect(fileKeys, equals({'id_front', 'id_back', 'selfie', 'video'}));
    });
  });

  group('GET endpoints', () {
    test('listVerifications passes status + limit + cursor', () async {
      final h = makeClient();
      final captured = <RequestOptions>[];
      h.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, handler) {
            captured.add(o);
            handler.next(o);
          },
        ),
      );
      h.adapter.onGet(
        '/v1/verifications',
        (server) => server.reply(200, {
          'object': 'list',
          'data': const [],
          'has_more': false,
          'next_cursor': null,
        }),
      );

      final result = await h.client.listVerifications(
        status: 'completed',
        limit: 50,
        cursor: 'abc',
      );

      expect(result.isRight, isTrue);
      final qp = captured.single.queryParameters;
      expect(qp['status'], 'completed');
      expect(qp['limit'], 50);
      expect(qp['cursor'], 'abc');
    });

    test('getVerification returns the full Verification', () async {
      final h = makeClient();
      h.adapter.onGet(
        '/v1/verifications/kyc_test0000000001',
        (server) => server.reply(200, verificationOk()),
      );

      final result = await h.client.getVerification('kyc_test0000000001');
      expect(result.isRight, isTrue);
      result.fold((l) => fail('left'), (v) {
        expect(v.id, 'kyc_test0000000001');
        expect(v.document!.fields, isNotNull);
      });
    });

    test('getVerification 404 maps to KycFailureNotFound', () async {
      final h = makeClient();
      h.adapter.onGet(
        '/v1/verifications/kyc_unknown',
        (server) => server.reply(404, {'error': 'not_found'}),
      );
      final result = await h.client.getVerification('kyc_unknown');
      expect(result.isLeft, isTrue);
      result.fold(
        (l) => expect(l, isA<KycFailureNotFound>()),
        (_) => fail('expected failure'),
      );
    });
  });
}
