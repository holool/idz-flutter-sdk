/// Structured error returned by the IDz API on a failed check or
/// failed verification.
///
/// The legacy `failure_reason` string is still emitted alongside as a
/// copy of [code] for backward compat. New code should switch on [code]
/// and render [userMessage] / take action on [userAction]; the
/// developer-facing context lives in [developerMessage].
///
/// **Don't render dev-only codes** (`AUTH_REQUIRED`, `RESOURCE_NOT_FOUND`,
/// etc.) — those carry `userMessage = ""` deliberately. Gate rendering
/// on [hasUserContent].
class ApiError {
  const ApiError({
    required this.code,
    this.developerMessage = '',
    this.userMessage = '',
    this.userAction = UserAction.none,
    this.retryable = false,
  });

  /// Machine-readable identifier — switch on this rather than parsing
  /// the messages. Stable across releases; the message strings may
  /// shift as copy is tuned.
  ///
  /// Examples: `LOW_QUALITY_IMAGE`, `FACE_MATCH_FAILED`,
  /// `LIVENESS_FAILED`, `INVALID_DOCUMENT_TYPE`, `MRZ_PARSE_FAILED`,
  /// `MISSING_REQUIRED_FIELDS`. Full list lives server-side in
  /// `services/api/kyc/errors.py`.
  final String code;

  /// Long-form context for engineers reading logs. Empty for some
  /// production errors; treat as advisory, not user-facing.
  final String developerMessage;

  /// Short, end-user-safe explanation. Empty for dev-only codes
  /// (auth / not-found / rate-limit) — those should never reach a
  /// human-facing screen.
  final String userMessage;

  /// CTA hint for the end user. See [UserAction].
  final UserAction userAction;

  /// Whether re-running the same request with the same inputs has a
  /// chance of success. Network blips and transient pipeline failures
  /// are `retryable: true`; permanent validation failures and
  /// unsupported documents are `false`.
  final bool retryable;

  /// True iff [userMessage] is set — i.e. this is an end-user-facing
  /// error, not a developer-only one. UI code should gate
  /// rendering on this.
  bool get hasUserContent => userMessage.isNotEmpty;

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      code: (json['code'] as String?) ?? '',
      developerMessage: (json['developer_message'] as String?) ?? '',
      userMessage: (json['user_message'] as String?) ?? '',
      userAction: UserAction.fromWire(json['user_action'] as String?),
      retryable: (json['retryable'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'code': code,
    if (developerMessage.isNotEmpty) 'developer_message': developerMessage,
    if (userMessage.isNotEmpty) 'user_message': userMessage,
    'user_action': userAction.wireValue,
    'retryable': retryable,
  };

  @override
  String toString() =>
      'ApiError(code: $code, action: ${userAction.wireValue}, '
      'retryable: $retryable)';
}


/// CTA hint the API recommends surfacing alongside a failed check.
///
/// Map each value to a button label in your locale. Don't hardcode the
/// recommendation in client code — let the server tell you what the
/// recovery path is so it stays in sync with pipeline updates.
enum UserAction {
  /// Re-capture the document image(s) and resubmit.
  retakeDocument('retake_document'),

  /// Re-capture the selfie image and resubmit.
  retakeSelfie('retake_selfie'),

  /// Re-record the liveness video and resubmit.
  retakeLiveness('retake_liveness'),

  /// Same input is fine but lighting / focus / glare needs work.
  improveImageQuality('improve_image_quality'),

  /// Transient backend issue; same request should succeed shortly.
  waitAndRetry('wait_and_retry'),

  /// Not recoverable client-side. Surface a support contact link.
  contactSupport('contact_support'),

  /// No specific action recommended. Render the message without a CTA.
  none('none');

  const UserAction(this.wireValue);

  /// Snake-case wire value as it appears in the API JSON.
  final String wireValue;

  static UserAction fromWire(String? raw) {
    if (raw == null) return UserAction.none;
    for (final value in UserAction.values) {
      if (value.wireValue == raw) return value;
    }
    return UserAction.none;
  }
}
