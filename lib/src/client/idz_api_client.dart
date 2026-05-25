import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../exceptions/either.dart';
import '../exceptions/kyc_failure.dart';
import '../idz_config.dart';
import '../models/artifacts_catalog.dart';
import '../models/document_type.dart';
import '../models/verification.dart';
import '../utils/idempotency.dart';
import 'dio_client.dart';

/// Client for the IDz `/v1/verifications/*` API.
///
/// Constructed by [IdzFlutter]; do not instantiate directly.
class IdzApiClient {
  final IdzConfig _config;
  final DioClient _dio;

  IdzApiClient({required IdzConfig config})
    : _config = config,
      _dio = DioClient(config: config);

  /// Inject a custom [DioClient]. Test-only.
  IdzApiClient.withClient({
    required IdzConfig config,
    required DioClient client,
  }) : _config = config,
       _dio = client;

  // ---------------------------------------------------------------------
  // Health
  // ---------------------------------------------------------------------

  /// `GET /health`. Resolves to `true` when the API is reachable and
  /// returns `{"status": "ok"}`.
  KycResult<bool> health() async {
    try {
      final response = await _dio.requestWithRetry(
        () => _dio.dio.get<Map<String, dynamic>>('/health'),
      );
      final ok = response.data?['status'] == 'ok';
      return Right(ok);
    } on DioException catch (e) {
      return Left(_failureFromDio(e));
    } catch (e) {
      return Left(KycFailureUnknown(e.toString()));
    }
  }

  // ---------------------------------------------------------------------
  // Verifications — POST
  // ---------------------------------------------------------------------

  /// Deprecated — retained only for source-compat with apps that still
  /// pass `pollTimeout: …`. The SDK no longer blocks on a poll loop;
  /// verifications resolve asynchronously and the app drives refreshes
  /// via [fetchVerification].
  @Deprecated('SDK no longer blocks on a poll loop. Use fetchVerification.')
  static const Duration defaultPollTimeout = Duration.zero;

  /// `POST /v1/verifications/document` — document-only verification.
  /// No biometric check.
  ///
  /// Returns as soon as the server's `202 Accepted` lands; the
  /// [Verification] will carry `status: in_progress` until the worker
  /// finishes. Call [fetchVerification] (or wait for a webhook) to read
  /// the terminal state.
  ///
  /// [idempotencyKey] — pass your own to enable submit-retry replay (the
  /// server replays the cached 202 instead of running a duplicate
  /// worker). When omitted the SDK generates a fresh v4 UUID per call;
  /// the header is always sent. The SDK does not cache the generated
  /// key — host apps that want submit-retry replay must supply (and
  /// persist) their own.
  ///
  /// [nfcCardReading] — optional NFC chip payload. When non-null it is
  /// JSON-encoded and submitted as the `nfc_card_reading` multipart
  /// field. Use `NfcResult.toApiJson()` to build it from the bundled
  /// `NfcReadingScreen`. Missing NFC data is valid; the backend treats
  /// it as image-only verification.
  ///
  /// [pollTimeout] is accepted but ignored. It only existed for the old
  /// blocking flow; kept here so existing call sites compile.
  KycResult<Verification> verifyDocument({
    required File idFront,
    required File idBack,
    DocumentType documentType = DocumentType.algerianNationalId,
    String? idempotencyKey,
    Map<String, dynamic>? nfcCardReading,
    @Deprecated('Ignored. The SDK no longer polls.')
    Duration? pollTimeout,
  }) {
    return _runPost(
      path: '/v1/verifications/document',
      formData: <String, MultipartFile>{
        'id_front': MultipartFile.fromFileSync(idFront.path),
        'id_back': MultipartFile.fromFileSync(idBack.path),
      },
      documentType: documentType,
      idempotencyKey: idempotencyKey,
      nfcCardReading: nfcCardReading,
    );
  }

  /// `POST /v1/verifications/identity` — document + selfie face match.
  /// No liveness.
  ///
  /// See [verifyDocument] for return semantics and [nfcCardReading]
  /// behaviour. The 202 hands you back a [Verification] with
  /// `status: in_progress`; resolve via [fetchVerification] or a webhook.
  KycResult<Verification> verifyIdentity({
    required File idFront,
    required File idBack,
    required File selfie,
    DocumentType documentType = DocumentType.algerianNationalId,
    String? idempotencyKey,
    Map<String, dynamic>? nfcCardReading,
    @Deprecated('Ignored. The SDK no longer polls.')
    Duration? pollTimeout,
  }) {
    return _runPost(
      path: '/v1/verifications/identity',
      formData: <String, MultipartFile>{
        'id_front': MultipartFile.fromFileSync(idFront.path),
        'id_back': MultipartFile.fromFileSync(idBack.path),
        'selfie': MultipartFile.fromFileSync(selfie.path),
      },
      documentType: documentType,
      idempotencyKey: idempotencyKey,
      nfcCardReading: nfcCardReading,
    );
  }

  /// `POST /v1/verifications/identity_live` — document + selfie + passive
  /// liveness from video.
  ///
  /// See [verifyDocument] for return semantics and [nfcCardReading]
  /// behaviour.
  KycResult<Verification> verifyIdentityLive({
    required File idFront,
    required File idBack,
    required File selfie,
    required File video,
    DocumentType documentType = DocumentType.algerianNationalId,
    String? idempotencyKey,
    Map<String, dynamic>? nfcCardReading,
    @Deprecated('Ignored. The SDK no longer polls.')
    Duration? pollTimeout,
  }) {
    return _runPost(
      path: '/v1/verifications/identity_live',
      formData: <String, MultipartFile>{
        'id_front': MultipartFile.fromFileSync(idFront.path),
        'id_back': MultipartFile.fromFileSync(idBack.path),
        'selfie': MultipartFile.fromFileSync(selfie.path),
        'video': MultipartFile.fromFileSync(video.path),
      },
      documentType: documentType,
      idempotencyKey: idempotencyKey,
      nfcCardReading: nfcCardReading,
    );
  }

  Future<Either<KycFailure, Verification>> _runPost({
    required String path,
    required Map<String, MultipartFile> formData,
    required DocumentType documentType,
    required String? idempotencyKey,
    Map<String, dynamic>? nfcCardReading,
  }) async {
    try {
      final form = FormData.fromMap(<String, dynamic>{
        ...formData,
        'document_type': documentType.wireValue,
        if (nfcCardReading != null && nfcCardReading.isNotEmpty)
          'nfc_card_reading': jsonEncode(nfcCardReading),
      });
      final key = (idempotencyKey != null && idempotencyKey.isNotEmpty)
          ? idempotencyKey
          : IdempotencyKey.generate();
      final response = await _dio.requestWithRetry(
        () => _dio.dio.post<Map<String, dynamic>>(
          path,
          data: form,
          options: Options(
            contentType: 'multipart/form-data',
            headers: <String, dynamic>{'Idempotency-Key': key},
          ),
        ),
      );
      final data = response.data;
      if (data == null) {
        return const Left(KycFailureUnknown('Empty response body'));
      }
      final verification = Verification.fromJson(data);
      // The server may still emit 200 OK with a synchronous rejection in
      // some early-path failures (schema rejects that don't need a
      // worker). Classify those so callers see the right KycFailure*.
      // For the common 202 in_progress path the classifier returns Right.
      return _classifyTerminal(verification);
    } on DioException catch (e) {
      return Left(_failureFromDio(e));
    } catch (e) {
      return Left(KycFailureUnknown(e.toString()));
    }
  }

  /// Map a [Verification] into the right `Right(Verification)` /
  /// `Left(KycFailure)` outcome.
  ///
  /// - `in_progress` → success (the app drives a refresh later).
  /// - `completed`   → success, regardless of review queue state.
  /// - `rejected`    → [KycFailureVerificationRejected].
  /// - `failed`      → [KycFailureVerificationAbandoned] (the stuck-
  ///   session sweeper; retriable with the same images) or
  ///   [KycFailureVerificationFailed] otherwise.
  Either<KycFailure, Verification> _classifyTerminal(Verification v) {
    if (v.isRejected) {
      return Left(KycFailureVerificationRejected(v));
    }
    if (v.status == 'failed') {
      final reason = v.checks.document?.failureReason ?? '';
      if (reason.startsWith('Abandoned:')) {
        return Left(KycFailureVerificationAbandoned(v));
      }
      return Left(KycFailureVerificationFailed(v));
    }
    return Right(v);
  }

  // ---------------------------------------------------------------------
  // Verifications — GET
  // ---------------------------------------------------------------------

  /// `GET /v1/verifications` — paginated list. `document.fields` is
  /// omitted on list rows. Use [getVerification] to fetch the full map.
  KycResult<VerificationList> listVerifications({
    String? status,
    DateTime? createdAfter,
    DateTime? createdBefore,
    int limit = 20,
    String? cursor,
  }) async {
    try {
      final response = await _dio.requestWithRetry(
        () => _dio.dio.get<Map<String, dynamic>>(
          '/v1/verifications',
          queryParameters: <String, dynamic>{
            if (status != null) 'status': status,
            if (createdAfter != null)
              'created_after': createdAfter.toIso8601String(),
            if (createdBefore != null)
              'created_before': createdBefore.toIso8601String(),
            'limit': limit,
            if (cursor != null) 'cursor': cursor,
          },
        ),
      );
      final data = response.data;
      if (data == null) {
        return const Left(KycFailureUnknown('Empty response body'));
      }
      return Right(VerificationList.fromJson(data));
    } on DioException catch (e) {
      return Left(_failureFromDio(e));
    } catch (e) {
      return Left(KycFailureUnknown(e.toString()));
    }
  }

  /// `GET /v1/verifications/{id}` — full Verification including
  /// `document.fields`.
  KycResult<Verification> getVerification(String id) async {
    try {
      final response = await _dio.requestWithRetry(
        () => _dio.dio.get<Map<String, dynamic>>('/v1/verifications/$id'),
      );
      final data = response.data;
      if (data == null) {
        return const Left(KycFailureUnknown('Empty response body'));
      }
      return Right(Verification.fromJson(data));
    } on DioException catch (e) {
      return Left(_failureFromDio(e));
    } catch (e) {
      return Left(KycFailureUnknown(e.toString()));
    }
  }

  /// Single GET against `/v1/verifications/{id}` — same as
  /// [getVerification], but named to match how apps now drive refreshes
  /// (lifecycle resume, pull-to-refresh, tab-switch). Returns the
  /// freshest [Verification] without ever blocking on a poll loop.
  KycResult<Verification> fetchVerification(String id) => getVerification(id);

  /// `GET /v1/verifications/{id}/audit` — append-only audit trail.
  KycResult<List<VerificationAuditEntry>> getVerificationAudit(
    String id, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.requestWithRetry(
        () => _dio.dio.get<dynamic>(
          '/v1/verifications/$id/audit',
          queryParameters: <String, dynamic>{'limit': limit, 'offset': offset},
        ),
      );
      final data = response.data;
      if (data is! List) {
        return const Left(KycFailureUnknown('Audit response was not a list'));
      }
      return Right(
        data
            .whereType<Map<String, dynamic>>()
            .map(VerificationAuditEntry.fromJson)
            .toList(),
      );
    } on DioException catch (e) {
      return Left(_failureFromDio(e));
    } catch (e) {
      return Left(KycFailureUnknown(e.toString()));
    }
  }

  /// `GET /v1/verifications/{id}/artifacts` — server-side categorised
  /// catalog of every artifact the pipeline produced (uploads, ROI
  /// detections, crops, face-match outputs, liveness, other).
  ///
  /// Use this to render an "Artifacts" tab without bucketing items
  /// client-side. Each [ArtifactItem.href] is server-relative; fetch the
  /// bytes with [getArtifactBytes] using the `id` (or your own GET to
  /// the `href` with the same `Authorization` header).
  KycResult<ArtifactsCatalog> getArtifactsCatalog(String verificationId) async {
    try {
      final response = await _dio.requestWithRetry(
        () => _dio.dio.get<Map<String, dynamic>>(
          '/v1/verifications/$verificationId/artifacts',
        ),
      );
      final data = response.data;
      if (data == null) {
        return const Left(KycFailureUnknown('Empty response body'));
      }
      return Right(ArtifactsCatalog.fromJson(data));
    } on DioException catch (e) {
      return Left(_failureFromDio(e));
    } catch (e) {
      return Left(KycFailureUnknown(e.toString()));
    }
  }

  /// `GET /v1/verifications/{id}/artifacts/{artifactId}` — stream the
  /// stored bytes of one artifact (image or video). Returns the raw
  /// bytes plus the `Content-Type` so callers can decide how to render.
  KycResult<ArtifactBytes> getArtifactBytes(
    String verificationId,
    String artifactId,
  ) async {
    try {
      final response = await _dio.requestWithRetry(
        () => _dio.dio.get<List<int>>(
          '/v1/verifications/$verificationId/artifacts/$artifactId',
          options: Options(responseType: ResponseType.bytes),
        ),
      );
      return Right(
        ArtifactBytes(
          bytes: response.data ?? const <int>[],
          contentType: response.headers.value('content-type'),
        ),
      );
    } on DioException catch (e) {
      return Left(_failureFromDio(e));
    } catch (e) {
      return Left(KycFailureUnknown(e.toString()));
    }
  }

  /// Underlying [IdzConfig] this client was built with.
  IdzConfig get config => _config;

  KycFailure _failureFromDio(DioException e) {
    final error = e.error;
    if (error is KycFailure) return error;
    return _dio.mapDioError(e);
  }

  void dispose() => _dio.dispose();
}

/// Bytes returned by [IdzApiClient.getArtifactBytes].
class ArtifactBytes {
  final List<int> bytes;
  final String? contentType;
  const ArtifactBytes({required this.bytes, this.contentType});
}
