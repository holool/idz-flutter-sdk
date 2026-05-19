/// Typed accessors over `Verification.metadata` for the structured
/// advisory blobs the server attaches on rejected / `needs_review`
/// rows. The wire shape is documented under "Why `metadata` may carry
/// extra detail" in the API errors page; this file is the SDK mirror.
///
/// All accessors are tolerant — if the key is missing, the value is
/// the wrong shape, or the list is empty, you get an empty list /
/// `null` rather than an exception. None of these blobs are required
/// to be present, even on a rejected verification — only the ones
/// produced by the path that actually ran show up. Branch on
/// `Verification.error.code` for routing; use these for reviewer /
/// triage UI.
library;

/// One row in `metadata.quality_failures` or `metadata.quality_scores_all`.
///
/// `quality_failures` lists only the regions that tripped the gate.
/// `quality_scores_all` (added when the gate landed on every region)
/// lists every scored region — passing and failing — so triage UIs can
/// render the distribution next to an `IMAGE_QUALITY_REJECTED`
/// rejection.
class QualityScore {
  /// `"front"` or `"back"`.
  final String? side;

  /// YOLO field class (e.g. `last_name_fr`, `blood_type`).
  final String? field;

  /// Laplacian variance. Lower = blurrier. Compared against a
  /// per-field floor server-side.
  final double? blurVar;

  /// Fraction of the crop that's washed out by specular highlight
  /// (0..1). Higher = more glare.
  final double? glareRatio;

  /// True iff both [blurVar] and [glareRatio] cleared their thresholds.
  final bool? passed;

  /// Short server-side label when [passed] is false: e.g. `blurry`,
  /// `glare`, `empty`.
  final String? reason;

  const QualityScore({
    this.side,
    this.field,
    this.blurVar,
    this.glareRatio,
    this.passed,
    this.reason,
  });

  factory QualityScore.fromJson(Map<String, dynamic> json) {
    return QualityScore(
      side: json['side'] as String?,
      field: json['field'] as String?,
      blurVar: _doubleOrNull(json['blur_var']),
      glareRatio: _doubleOrNull(json['glare_ratio']),
      passed: json['passed'] as bool?,
      reason: json['reason'] as String?,
    );
  }
}

/// One entry in `metadata.mrz_viz_disagreements`.
///
/// Raised when the MRZ-side OCR and the visible-zone OCR landed on
/// different values for the same field. The reviewer decides which
/// side to trust; common pattern is to trust VIZ when its check digit
/// failed on the MRZ.
class MrzVizDisagreement {
  /// Snake-case MRZ field name (`document_number`, `date_of_birth`,
  /// `expiry_date`, `surname`, `given_names`, `sex`).
  final String? field;

  /// What the MRZ parse produced.
  final String? mrzValue;

  /// What the front-side VIZ OCR produced.
  final String? vizValue;

  /// Stable identifier for the kind of mismatch (e.g. `field_mismatch`).
  final String? code;

  /// Human-readable explanation, ready to render in the reviewer UI.
  final String? message;

  const MrzVizDisagreement({
    this.field,
    this.mrzValue,
    this.vizValue,
    this.code,
    this.message,
  });

  factory MrzVizDisagreement.fromJson(Map<String, dynamic> json) {
    return MrzVizDisagreement(
      field: json['field'] as String?,
      mrzValue: json['mrz_value'] as String?,
      vizValue: json['viz_value'] as String?,
      code: json['code'] as String?,
      message: json['message'] as String?,
    );
  }
}

/// One entry in `metadata.consistency_issues` (cross-field date /
/// validity-window checks) or `metadata.gazette_misses` (a name or
/// place wasn't in the reference gazette).
///
/// Same shape for both — kept as one class because they're handled
/// identically in reviewer UI: render the message, group by field.
class FieldFinding {
  /// Field this finding is attached to (e.g. `date_of_expiry`,
  /// `place_of_birth`).
  final String? field;

  /// Stable identifier (e.g. `validity_window_off`, `name_not_in_gazette`).
  final String? code;

  /// Human-readable explanation, ready to render.
  final String? message;

  const FieldFinding({this.field, this.code, this.message});

  factory FieldFinding.fromJson(Map<String, dynamic> json) {
    return FieldFinding(
      field: json['field'] as String?,
      code: json['code'] as String?,
      message: json['message'] as String?,
    );
  }
}

/// `metadata.routing` — present on every terminal verification.
///
/// Tells you what verdict the routing logic landed on and which field
/// buckets it weighed. Useful for showing reviewers the "why" behind a
/// `needs_review` flag without having to re-run the pipeline.
class RoutingDecision {
  /// Final verdict the router picked. Mirrors the rejection / review
  /// outcome — examples: `approve`, `reject`, `needs_review`,
  /// `index_invalid`, `core_invalid`.
  final String? verdict;

  /// How many of the document's core identity-bearing fields validated.
  final int? coreValidCount;

  /// Field names whose validators failed at the index level (the
  /// primary identifier — NIN / licence number / passport number).
  /// Hard-rejects when non-empty; we can't index the verification
  /// without one. Empty when the index is fine.
  final List<String> indexFailures;

  /// Field names whose validators failed at the core identity level
  /// (names, DOB, etc.). When this is all of them you typically get a
  /// `CORE_FIELDS_INVALID` rejection.
  final List<String> coreFailures;

  /// Field names that failed soft-validation checks — cross-field
  /// consistency, gazette membership, MRZ-VIZ reconciliation. These
  /// route to `needs_review` rather than rejecting outright.
  final List<String> softFailures;

  /// Short human-readable strings explaining why the verification was
  /// flagged for review (e.g. `"mrz_viz_disagrees:given_names"`).
  /// Empty when no review was queued.
  final List<String> reviewReasons;

  const RoutingDecision({
    this.verdict,
    this.coreValidCount,
    this.indexFailures = const <String>[],
    this.coreFailures = const <String>[],
    this.softFailures = const <String>[],
    this.reviewReasons = const <String>[],
  });

  factory RoutingDecision.fromJson(Map<String, dynamic> json) {
    return RoutingDecision(
      verdict: json['verdict'] as String?,
      coreValidCount: json['core_valid_count'] as int?,
      indexFailures: _stringList(json['index_failures']),
      coreFailures: _stringList(json['core_failures']),
      softFailures: _stringList(json['soft_failures']),
      reviewReasons: _stringList(json['review_reasons']),
    );
  }
}

List<String> _stringList(Object? value) {
  if (value is List) return value.whereType<String>().toList();
  return const <String>[];
}

double? _doubleOrNull(Object? value) {
  if (value is num) return value.toDouble();
  return null;
}
