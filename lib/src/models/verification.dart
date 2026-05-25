import 'api_error.dart';
import 'document_type.dart';
import 'field_result.dart';
import 'verification_metadata.dart';

class Verification {
  final String id;
  final String mode;
  final String status;

  /// Review-queue state for a `completed` row. `null` everywhere else,
  /// and `null` on `completed` rows the pipeline approved outright. See
  /// [ReviewState].
  final ReviewState? reviewState;

  final DateTime createdAt;
  final DateTime? completedAt;
  final VerificationDocument? document;
  final VerificationChecks checks;
  final List<VerificationArtifact> artifacts;
  final Map<String, dynamic>? metadata;

  /// Top-level structured error when the whole verification failed
  /// (e.g. all checks aborted, an upstream service was unreachable).
  /// Per-check failures live on [VerificationChecks.document.error] /
  /// `faceMatch.error` / `liveness.error` instead.
  ///
  /// `null` when there's no top-level error — the common case even on
  /// `status: "rejected"` (the rejection lives on a per-check error).
  final ApiError? error;

  const Verification({
    required this.id,
    required this.mode,
    required this.status,
    this.reviewState,
    required this.createdAt,
    this.completedAt,
    this.document,
    required this.checks,
    this.artifacts = const <VerificationArtifact>[],
    this.metadata,
    this.error,
  });

  /// True iff the pipeline ran and approved the verification outright —
  /// no manual review queued. `status == 'completed' && reviewState ==
  /// null`. Use this as the green-check gate; `status == 'completed'`
  /// alone is not enough now that the server can return "approved but
  /// pending human review".
  bool get isPassed => status == 'completed' && reviewState == null;

  /// `status == 'completed'` but the server queued the row for human
  /// review. Render amber, not green. The fields are extracted and
  /// available; the verdict is just pending.
  bool get isUnderReview =>
      status == 'completed' && reviewState == ReviewState.pending;

  bool get isRejected => status == 'rejected';
  bool get isFailed => status == 'failed';

  /// True iff [status] is one of `completed`, `rejected`, `failed`. The
  /// pipeline won't progress past a terminal status; the only mutation
  /// after this point is a reviewer flipping [reviewState].
  bool get isTerminal =>
      status == 'completed' || status == 'rejected' || status == 'failed';

  /// True iff the pipeline hasn't reached a terminal status yet (the
  /// row is still being worked on by the async worker).
  bool get isInProgress => !isTerminal;

  /// Pipeline-emitted hints surfaced via `metadata.postprocess_notes`.
  /// Common patterns:
  ///   - `name_csv_snap:<field>` — OCR snapped to a curated CSV entry.
  ///   - `validity_window:Xd expected~Yd (...)` — issue→expiry delta off.
  ///   - `categories:*` / `categories_table:*` — DL categories merge note.
  /// Empty list when no notes were emitted.
  List<String> get postprocessNotes => _stringListFromMetadata('postprocess_notes');

  /// YOLO field classes the detector couldn't find on the front side.
  /// Populated alongside an `error.code == 'MISSING_REQUIRED_FIELDS'`
  /// rejection. Empty list when the front extracted cleanly (or when
  /// the rejection lives on the back side).
  List<String> get missingFrontFields => _stringListFromMetadata('missing_front_fields');

  /// YOLO field classes the detector couldn't find on the back side.
  /// See [missingFrontFields].
  List<String> get missingBackFields => _stringListFromMetadata('missing_back_fields');

  /// Per-region quality scores for the regions that *failed* the gate.
  /// Populated alongside an `error.code == 'IMAGE_QUALITY_REJECTED'`
  /// rejection. Use [qualityScoresAll] when you want passing regions
  /// too (e.g. to show the distribution).
  List<QualityScore> get qualityFailures => _objectListFromMetadata(
        'quality_failures',
        QualityScore.fromJson,
      );

  /// Per-region quality scores for *every* scored region — passing AND
  /// failing. Populated when the gate ran end-to-end (so the reviewer
  /// can triage false positives). Empty when the gate short-circuited
  /// on the first failure or was skipped entirely.
  List<QualityScore> get qualityScoresAll => _objectListFromMetadata(
        'quality_scores_all',
        QualityScore.fromJson,
      );

  /// MRZ ↔ VIZ field-level disagreements the reviewer should look at.
  /// Empty when both sides agreed or only one of them was available.
  /// A non-empty list does not by itself imply a rejection — most
  /// disagreements flag the row for `needs_review`.
  List<MrzVizDisagreement> get mrzVizDisagreements => _objectListFromMetadata(
        'mrz_viz_disagreements',
        MrzVizDisagreement.fromJson,
      );

  /// Cross-field consistency issues (date math, validity-window) the
  /// pipeline flagged. Empty when every cross-field check passed.
  List<FieldFinding> get consistencyIssues => _objectListFromMetadata(
        'consistency_issues',
        FieldFinding.fromJson,
      );

  /// Names or places that weren't found in the reference gazette.
  /// Advisory only — a non-empty list typically flags the row for
  /// `needs_review` rather than rejecting it.
  List<FieldFinding> get gazetteMisses => _objectListFromMetadata(
        'gazette_misses',
        FieldFinding.fromJson,
      );

  /// Routing decision the pipeline landed on. Present on every
  /// terminal verification; `null` while `isInProgress`.
  RoutingDecision? get routing {
    final raw = metadata?['routing'];
    if (raw is Map) return RoutingDecision.fromJson(raw.cast<String, dynamic>());
    return null;
  }

  List<String> _stringListFromMetadata(String key) {
    final raw = metadata?[key];
    if (raw is List) return raw.whereType<String>().toList();
    return const <String>[];
  }

  List<T> _objectListFromMetadata<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = metadata?[key];
    if (raw is! List) return const <Never>[].cast<T>();
    return raw
        .whereType<Map>()
        .map((item) => fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  factory Verification.fromJson(Map<String, dynamic> json) {
    return Verification(
      id: json['id'] as String,
      mode: json['mode'] as String,
      status: json['status'] as String,
      reviewState: ReviewState.fromWire(json['review_state'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: _dateTimeOrNull(json['completed_at']),
      document: json['document'] is Map<String, dynamic>
          ? VerificationDocument.fromJson(
              json['document'] as Map<String, dynamic>,
            )
          : null,
      checks: VerificationChecks.fromJson(
        (json['checks'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      artifacts: (json['artifacts'] as List? ?? const <Object?>[])
          .whereType<Map>()
          .map(
            (item) =>
                VerificationArtifact.fromJson(item.cast<String, dynamic>()),
          )
          .toList(),
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>(),
      error: json['error'] is Map<String, dynamic>
          ? ApiError.fromJson(json['error'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Server-side review queue state for a `completed` verification.
///
/// Only meaningful when [Verification.status] is `completed`. A `null`
/// value means "no review queued — approved outright". A `pending`
/// value means "approved by the pipeline but flagged for human review;
/// the reviewer hasn't decided yet".
///
/// In the dashboard a reviewer eventually flips this to `approved` or
/// `rejected`; the SDK doesn't model those terminal review verdicts as
/// a separate enum because they collapse onto [Verification.status] in
/// the final row.
enum ReviewState {
  pending('pending');

  final String wireValue;
  const ReviewState(this.wireValue);

  static ReviewState? fromWire(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final state in ReviewState.values) {
      if (state.wireValue == value) return state;
    }
    return null;
  }
}

class VerificationDocument {
  final String? type;
  final String? country;
  final Map<String, FieldResult>? fields;

  const VerificationDocument({this.type, this.country, this.fields});

  DocumentType? get documentType => DocumentType.fromWireValue(type);

  factory VerificationDocument.fromJson(Map<String, dynamic> json) {
    return VerificationDocument(
      type: json['type'] as String?,
      country: json['country'] as String?,
      fields: _fieldsFromJson(json['fields']),
    );
  }
}

class CheckResult {
  final bool? passed;
  final double? score;

  /// Legacy snake-case failure code (e.g. `face_match_failed`). Still
  /// emitted by the server as a copy of [error.code] for backward
  /// compat. New code should prefer [error] — switch on `error.code`
  /// and render `error.userMessage` / use `error.userAction` for the
  /// CTA.
  final String? failureReason;

  /// Structured error when this check failed. `null` when the check
  /// passed (or wasn't evaluated). Has end-user-safe copy + a CTA hint
  /// + a `retryable` flag.
  final ApiError? error;

  const CheckResult({
    this.passed,
    this.score,
    this.failureReason,
    this.error,
  });

  factory CheckResult.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return const CheckResult();
    return CheckResult(
      passed: json['passed'] as bool?,
      score: _doubleOrNull(json['score']),
      failureReason: json['failure_reason'] as String?,
      error: json['error'] is Map<String, dynamic>
          ? ApiError.fromJson(json['error'] as Map<String, dynamic>)
          : null,
    );
  }
}

class VerificationChecks {
  final CheckResult? document;
  final CheckResult? faceMatch;
  final CheckResult? liveness;

  const VerificationChecks({this.document, this.faceMatch, this.liveness});

  factory VerificationChecks.fromJson(Map<String, dynamic> json) {
    return VerificationChecks(
      document: json['document'] == null
          ? null
          : CheckResult.fromJson(json['document']),
      faceMatch: json['face_match'] == null
          ? null
          : CheckResult.fromJson(json['face_match']),
      liveness: json['liveness'] == null
          ? null
          : CheckResult.fromJson(json['liveness']),
    );
  }
}

class VerificationArtifact {
  final String id;
  final String type;
  final String? mime;
  final int? size;
  final String? href;

  const VerificationArtifact({
    required this.id,
    required this.type,
    this.mime,
    this.size,
    this.href,
  });

  factory VerificationArtifact.fromJson(Map<String, dynamic> json) {
    return VerificationArtifact(
      id: json['id'] as String,
      type: json['type'] as String,
      mime: json['mime'] as String?,
      size: json['size'] as int?,
      href: json['href'] as String?,
    );
  }
}

class VerificationList {
  final String object;
  final List<Verification> data;
  final bool hasMore;
  final String? nextCursor;

  const VerificationList({
    required this.object,
    required this.data,
    required this.hasMore,
    this.nextCursor,
  });

  factory VerificationList.fromJson(Map<String, dynamic> json) {
    return VerificationList(
      object: json['object'] as String? ?? 'list',
      data: (json['data'] as List? ?? const <Object?>[])
          .whereType<Map>()
          .map((item) => Verification.fromJson(item.cast<String, dynamic>()))
          .toList(),
      hasMore: json['has_more'] as bool? ?? false,
      nextCursor: json['next_cursor'] as String?,
    );
  }
}

class VerificationAuditEntry {
  final DateTime timestamp;
  final String action;
  final String? actorKind;
  final Map<String, dynamic>? details;

  const VerificationAuditEntry({
    required this.timestamp,
    required this.action,
    this.actorKind,
    this.details,
  });

  factory VerificationAuditEntry.fromJson(Map<String, dynamic> json) {
    return VerificationAuditEntry(
      timestamp: DateTime.parse(json['timestamp'] as String),
      action: json['action'] as String,
      actorKind: json['actor_kind'] as String?,
      details: (json['details'] as Map?)?.cast<String, dynamic>(),
    );
  }
}

Map<String, FieldResult>? _fieldsFromJson(Object? value) {
  if (value is! Map) return null;
  return value.map(
    (key, field) => MapEntry(key.toString(), FieldResult.fromJson(field)),
  );
}

DateTime? _dateTimeOrNull(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.parse(value);
}

double? _doubleOrNull(Object? value) {
  if (value is num) return value.toDouble();
  return null;
}
