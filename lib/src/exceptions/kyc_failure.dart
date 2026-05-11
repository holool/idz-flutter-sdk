import '../models/verification.dart';

/// All possible failures the IDz SDK can surface to your code.
///
/// Pattern-match on the variant to handle each case:
///
/// ```dart
/// switch (failure) {
///   KycFailureNetwork() => showOffline(),
///   KycFailureUnauthorized() => promptForApiKey(),
///   KycFailureVerificationRejected(verification: final v) =>
///       showRejection(v.checks.document?.failureReason),
///   _ => showGenericError(),
/// }
/// ```
sealed class KycFailure {
  const KycFailure();
}

/// No internet, DNS failure, connection refused.
final class KycFailureNetwork extends KycFailure {
  const KycFailureNetwork();
  @override
  String toString() => 'KycFailureNetwork()';
}

/// Request exceeded the configured timeout.
///
/// For HTTP timeouts (Dio request) this is set when the request itself
/// timed out — neither [lastStatus] nor [elapsed] is meaningful.
///
/// For polling timeouts (verify methods) this fires when the SDK gave
/// up waiting for the verification to reach a terminal status. In that
/// case [lastStatus] is the most recently observed `status` (typically
/// `in_progress`) and [elapsed] is the wall-clock time spent polling.
/// The backend still has its own 5 min sweeper, so a session that hits
/// this client-side timeout will eventually flip to `failed` server-
/// side; callers can either surface "still processing" UX or just
/// retry the verification.
final class KycFailureTimeout extends KycFailure {
  /// Last status observed before the SDK gave up. Null when the
  /// timeout fired before any status was read.
  final String? lastStatus;

  /// Wall-clock time spent waiting. Null for non-poll timeouts.
  final Duration? elapsed;

  const KycFailureTimeout({this.lastStatus, this.elapsed});

  @override
  String toString() {
    if (lastStatus == null && elapsed == null) return 'KycFailureTimeout()';
    final parts = <String>[
      if (lastStatus != null) 'lastStatus=$lastStatus',
      if (elapsed != null) 'elapsed=${elapsed!.inSeconds}s',
    ];
    return 'KycFailureTimeout(${parts.join(', ')})';
  }
}

/// 401 — missing or invalid API key.
final class KycFailureUnauthorized extends KycFailure {
  final String message;
  const KycFailureUnauthorized(this.message);
  @override
  String toString() => 'KycFailureUnauthorized($message)';
}

/// 403 — credential is otherwise wrong (denied IP, dashboard-only path,
/// wrong product prefix).
final class KycFailureForbidden extends KycFailure {
  final String message;
  const KycFailureForbidden(this.message);
  @override
  String toString() => 'KycFailureForbidden($message)';
}

/// 400 / 422 — malformed input. Includes `unsupported_document_type`.
final class KycFailureInvalidInput extends KycFailure {
  final String message;
  final String? errorCode;
  const KycFailureInvalidInput(this.message, {this.errorCode});
  @override
  String toString() => 'KycFailureInvalidInput($message, code=$errorCode)';
}

/// 409 — same `Idempotency-Key` is still in flight from a prior request.
/// Wait for the first call to finish, then retry.
final class KycFailureIdempotencyConflict extends KycFailure {
  final String message;
  const KycFailureIdempotencyConflict(this.message);
  @override
  String toString() => 'KycFailureIdempotencyConflict($message)';
}

/// 5xx server-side failure. Safe to retry with the same `Idempotency-Key`.
final class KycFailureServerError extends KycFailure {
  final int statusCode;
  final String message;
  const KycFailureServerError(this.statusCode, this.message);
  @override
  String toString() => 'KycFailureServerError($statusCode, $message)';
}

/// 404 — verification ID, artifact ID, or webhook endpoint doesn't
/// exist (or belongs to a different org — the API doesn't distinguish).
final class KycFailureNotFound extends KycFailure {
  final String message;
  const KycFailureNotFound(this.message);
  @override
  String toString() => 'KycFailureNotFound($message)';
}

/// 200 OK with `status: "rejected"` — the pipeline ran and flagged a
/// problem. The full [Verification] is attached so you can render the
/// per-check `failure_reason`.
final class KycFailureVerificationRejected extends KycFailure {
  final Verification verification;
  const KycFailureVerificationRejected(this.verification);
  @override
  String toString() =>
      'KycFailureVerificationRejected(id=${verification.id}, '
      'document=${verification.checks.document?.failureReason}, '
      'face_match=${verification.checks.faceMatch?.failureReason}, '
      'liveness=${verification.checks.liveness?.failureReason})';
}

/// `status: "failed"` with `failure_reason` starting with `Abandoned:` —
/// the backend's stuck-session sweeper marked the verification failed
/// because the worker crashed or restarted mid-pipeline. This is an
/// **infrastructure hiccup, not a user-visible OCR/biometric failure**:
/// re-submitting the same images is the correct remediation, and apps
/// should distinguish it from a real failure in the UI.
final class KycFailureVerificationAbandoned extends KycFailure {
  final Verification verification;
  const KycFailureVerificationAbandoned(this.verification);

  /// The full server-side reason. Always begins with `Abandoned:`.
  String? get reason => verification.checks.document?.failureReason;

  @override
  String toString() =>
      'KycFailureVerificationAbandoned(id=${verification.id}, reason=$reason)';
}

/// `status: "failed"` for any reason other than [KycFailureVerificationAbandoned].
/// The pipeline ran but couldn't complete — typically a malformed input
/// the OCR couldn't parse, a missing back-side image, etc. The full
/// [Verification] is attached so callers can render the per-check
/// `failure_reason`.
final class KycFailureVerificationFailed extends KycFailure {
  final Verification verification;
  const KycFailureVerificationFailed(this.verification);

  String? get reason => verification.checks.document?.failureReason;

  @override
  String toString() =>
      'KycFailureVerificationFailed(id=${verification.id}, reason=$reason)';
}

/// Local file is unsupported or exceeds [IdzConfig.maxFileSizeMb].
final class KycFailureFileValidation extends KycFailure {
  final String message;
  const KycFailureFileValidation(this.message);
  @override
  String toString() => 'KycFailureFileValidation($message)';
}

/// Camera initialization failed.
final class KycFailureCamera extends KycFailure {
  final String message;
  const KycFailureCamera(this.message);
  @override
  String toString() => 'KycFailureCamera($message)';
}

/// Runtime permission denied (camera, gallery, microphone, …).
final class KycFailurePermissionDenied extends KycFailure {
  final String permission;
  const KycFailurePermissionDenied(this.permission);
  @override
  String toString() => 'KycFailurePermissionDenied($permission)';
}

/// Unknown / unexpected error. Always carries a message.
final class KycFailureUnknown extends KycFailure {
  final String message;
  const KycFailureUnknown(this.message);
  @override
  String toString() => 'KycFailureUnknown($message)';
}
