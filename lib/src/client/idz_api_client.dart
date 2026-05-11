import 'dart:io';

import 'package:dio/dio.dart';

import '../exceptions/either.dart';
import '../exceptions/kyc_failure.dart';
import '../idz_config.dart';
import '../models/artifacts_catalog.dart';
import '../models/document_type.dart';
import '../models/verification.dart';
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

  /// Default for [pollTimeout] on every verify method.
  ///
  /// 90 s leaves headroom for the slowest CPU-only DL flow (~60 s in
  /// the wild) while firing well before the backend's 5 min stuck-
  /// session sweeper. Apps wanting different envelopes pass their own
  /// [Duration] per call.
  static const Duration defaultPollTimeout = Duration(seconds: 90);

  /// `POST /v1/verifications/document` — document-only verification.
  /// No biometric check.
  ///
  /// [pollTimeout] is the wall-clock budget for waiting on the queued
  /// pipeline to reach a terminal status (`completed`, `rejected`,
  /// `failed`). When it elapses the SDK returns
  /// [KycFailureTimeout] with `lastStatus` and `elapsed` populated;
  /// the backend's 5 min sweeper still flips the row to `failed` later
  /// so the caller can either refresh from `getVerification` or just
  /// retry. Defaults to [defaultPollTimeout] (90 s).
  KycResult<Verification> verifyDocument({
    required File idFront,
    required File idBack,
    DocumentType documentType = DocumentType.algerianNationalId,
    String? idempotencyKey,
    Duration pollTimeout = defaultPollTimeout,
  }) {
    return _runPost(
      path: '/v1/verifications/document',
      formData: <String, MultipartFile>{
        'id_front': MultipartFile.fromFileSync(idFront.path),
        'id_back': MultipartFile.fromFileSync(idBack.path),
      },
      documentType: documentType,
      idempotencyKey: idempotencyKey,
      pollTimeout: pollTimeout,
    );
  }

  /// `POST /v1/verifications/identity` — document + selfie face match.
  /// No liveness.
  ///
  /// See [verifyDocument] for [pollTimeout] semantics.
  KycResult<Verification> verifyIdentity({
    required File idFront,
    required File idBack,
    required File selfie,
    DocumentType documentType = DocumentType.algerianNationalId,
    String? idempotencyKey,
    Duration pollTimeout = defaultPollTimeout,
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
      pollTimeout: pollTimeout,
    );
  }

  /// `POST /v1/verifications/identity_live` — document + selfie + passive
  /// liveness from video.
  ///
  /// See [verifyDocument] for [pollTimeout] semantics. Heavier flows
  /// (DL with the four-engine OCR ensemble on CPU) sometimes want a
  /// higher value — pass `Duration(seconds: 120)` if you see
  /// [KycFailureTimeout] in production.
  KycResult<Verification> verifyIdentityLive({
    required File idFront,
    required File idBack,
    required File selfie,
    required File video,
    DocumentType documentType = DocumentType.algerianNationalId,
    String? idempotencyKey,
    Duration pollTimeout = defaultPollTimeout,
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
      pollTimeout: pollTimeout,
    );
  }

  Future<Either<KycFailure, Verification>> _runPost({
    required String path,
    required Map<String, MultipartFile> formData,
    required DocumentType documentType,
    required String? idempotencyKey,
    required Duration pollTimeout,
  }) async {
    try {
      final form = FormData.fromMap(<String, dynamic>{
        ...formData,
        'document_type': documentType.wireValue,
      });
      final headers = <String, dynamic>{};
      if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
        headers['Idempotency-Key'] = idempotencyKey;
      }
      final response = await _dio.requestWithRetry(
        () => _dio.dio.post<Map<String, dynamic>>(
          path,
          data: form,
          options: Options(
            contentType: 'multipart/form-data',
            headers: headers,
          ),
        ),
      );
      final data = response.data;
      if (data == null) {
        return const Left(KycFailureUnknown('Empty response body'));
      }
      final verification = Verification.fromJson(data);
      // Server moved the heavy pipeline behind a 202 + queue. If we got
      // anything non-terminal back (including the legacy 200 path), poll
      // GET /v1/verifications/{id} until the status flips.
      final terminal = await _waitForTerminal(
        verification,
        pollTimeout: pollTimeout,
      );
      return terminal.fold(Left.new, _classifyTerminal);
    } on DioException catch (e) {
      return Left(_failureFromDio(e));
    } catch (e) {
      return Left(KycFailureUnknown(e.toString()));
    }
  }

  /// Map a terminal-status [Verification] into the right
  /// `Right(Verification)` / `Left(KycFailure)` outcome.
  ///
  /// - `completed` → success.
  /// - `rejected`  → [KycFailureVerificationRejected] (real biometric /
  ///   document failure, the user must re-do).
  /// - `failed`    → either [KycFailureVerificationAbandoned] (the
  ///   server-side stuck-session sweeper marked it; retriable with the
  ///   same images) or [KycFailureVerificationFailed] (other backend
  ///   failure — usually malformed input).
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

  /// Poll [getVerification] until the row reaches a terminal status.
  ///
  /// `completed`, `rejected`, and `failed` are terminal. Anything else
  /// (`in_progress`, `processing`, etc.) means the background pipeline
  /// is still running on the server.
  ///
  /// Polls every 2 s with a wall-clock cap of [pollTimeout]. When the
  /// deadline elapses returns [KycFailureTimeout] populated with the
  /// last-observed status and elapsed time — independent of any
  /// transient network errors during polling. The deadline is measured
  /// from poll-start, not a count of polls, so variable network
  /// conditions don't extend it.
  Future<Either<KycFailure, Verification>> _waitForTerminal(
    Verification initial, {
    required Duration pollTimeout,
  }) async {
    if (_isTerminalStatus(initial.status)) {
      return Right(initial);
    }
    final pollEvery = const Duration(seconds: 2);
    final start = DateTime.now();
    final deadline = start.add(pollTimeout);
    Verification current = initial;
    while (!_isTerminalStatus(current.status)) {
      if (DateTime.now().isAfter(deadline)) {
        return Left(
          KycFailureTimeout(
            lastStatus: current.status,
            elapsed: DateTime.now().difference(start),
          ),
        );
      }
      await Future<void>.delayed(pollEvery);
      final result = await getVerification(current.id);
      final next = result.fold<Verification?>((_) => null, (v) => v);
      if (next == null) {
        // Transient GET failure (network blip, 5xx). Try again on next tick.
        continue;
      }
      current = next;
    }
    return Right(current);
  }

  static bool _isTerminalStatus(String status) {
    return status == 'completed' || status == 'rejected' || status == 'failed';
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
  /// client-side. Each [ArtifactItem.url] is server-relative; fetch the
  /// bytes with [getArtifactBytes] using the `id` (or your own GET to
  /// the `url` with the same `Authorization` header).
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
