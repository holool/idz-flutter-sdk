/// Per-field OCR extraction result from the IDz API.
///
/// `normalized` is intentionally typed as `Object?` because the server
/// returns different shapes for different fields:
///
///   - Most fields: a String (e.g. "MOHAMED", "1990/01/01").
///   - Driving-licence `categories`: a `List<String>`.
///   - MRZ: a `Map<String, dynamic>` of parsed TD1 fields plus a nested
///     `checks.*` map of ICAO 9303 check-digit booleans.
///
/// Use the typed helpers below — `asString`, `asStringList`, `asMrz` —
/// rather than down-casting at the call site.
class FieldResult {
  final Object? raw;
  final Object? normalized;
  final bool? valid;
  final String? side;

  /// Per-field issues raised by the pipeline (e.g. `low_quality_field`,
  /// `invalid_field_value`). Empty when nothing's wrong. Each entry
  /// carries a short `code`, a human-readable `message`, and an optional
  /// `details` map (e.g. `{"confidence": 0.50}` for low-quality fields).
  final List<FieldIssue> issues;

  const FieldResult({
    this.raw,
    this.normalized,
    this.valid,
    this.side,
    this.issues = const [],
  });

  factory FieldResult.fromJson(Object? json) {
    if (json is Map<String, dynamic>) {
      final rawIssues = json['issues'];
      final issues = rawIssues is List
          ? rawIssues
              .whereType<Map>()
              .map((e) => FieldIssue.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const <FieldIssue>[];
      return FieldResult(
        raw: json['raw'],
        normalized: json['normalized'],
        valid: json['valid'] as bool?,
        side: json['side'] as String?,
        issues: issues,
      );
    }
    return FieldResult(raw: json, normalized: json);
  }

  /// Convenience: the lowest-confidence `low_quality_field` issue if any,
  /// else null. UI renders a "Low quality" chip when this returns
  /// non-null; tooltip uses the issue's `message`.
  FieldIssue? get lowQualityIssue {
    for (final i in issues) {
      if (i.code == 'low_quality_field') return i;
    }
    return null;
  }

  /// `normalized` as a String, or null if it's any other shape.
  String? get asString {
    final v = normalized;
    return v is String ? v : null;
  }

  /// `normalized` as a list of strings (e.g. driving-licence categories),
  /// or null if it's any other shape.
  List<String>? get asStringList {
    final v = normalized;
    if (v is List) return v.whereType<String>().toList();
    return null;
  }

  /// `normalized` parsed as an MRZ object, or null if this isn't an MRZ
  /// field (or the server didn't manage to parse it).
  ///
  /// Use `asMrz?.valid` as the trust signal for the whole MRZ. Use the
  /// per-field booleans on `asMrz?.checks` (`documentNumber`, `dateOfBirth`,
  /// `expiryDate`, `composite`) when you want to trust individual fields
  /// even when the overall MRZ failed.
  MrzNormalized? get asMrz {
    final v = normalized;
    if (v is! Map) return null;
    return MrzNormalized.fromJson(v.cast<String, dynamic>());
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'raw': raw,
    'normalized': normalized,
    'valid': valid,
    'side': side,
    if (issues.isNotEmpty)
      'issues': issues.map((i) => i.toJson()).toList(),
  };
}


/// One pipeline-emitted issue attached to a [FieldResult].
///
/// Known codes (non-exhaustive — match defensively, fall back to
/// rendering the raw `message`):
///   - `low_quality_field`: OCR confidence below the warning floor.
///     `details.confidence` is a 0..1 float when present.
///   - `invalid_field_value`: validator rejected the normalized value.
///     `details` is usually absent.
class FieldIssue {
  const FieldIssue({
    required this.code,
    required this.message,
    this.severity,
    this.details,
  });

  final String code;
  final String message;

  /// `info` | `warning` | `error`. Often null — most issues are warnings.
  final String? severity;

  /// Optional structured payload. Read defensively — keys vary by `code`.
  final Map<String, dynamic>? details;

  factory FieldIssue.fromJson(Map<String, dynamic> json) {
    final rawDetails = json['details'];
    return FieldIssue(
      code: (json['code'] as String?) ?? '',
      message: (json['message'] as String?) ?? '',
      severity: json['severity'] as String?,
      details: rawDetails is Map ? rawDetails.cast<String, dynamic>() : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'code': code,
    'message': message,
    if (severity != null) 'severity': severity,
    if (details != null) 'details': details,
  };

  /// Confidence as a 0..1 double, only set on `low_quality_field`. Null
  /// for any other code or when details are absent / malformed.
  double? get confidence {
    final v = details?['confidence'];
    return v is num ? v.toDouble() : null;
  }
}

/// Parsed Machine-Readable Zone (TD1 layout, three lines × 30 chars) of
/// an Algerian driving licence or national ID.
///
/// `checks` exposes the per-field ICAO 9303 check-digit results — it is
/// safe to trust an individual MRZ field if its corresponding check
/// passed even when [valid] (the composite) is false.
class MrzNormalized {
  /// Document type code (e.g. "DL", "ID").
  final String? documentType;

  /// Document number from MRZ — for a DL this is the licence number,
  /// for an ID this is the card number.
  final String? documentNumber;

  /// `YYYY/MM/DD`.
  final String? dateOfBirth;

  /// `YYYY/MM/DD`.
  final String? expiryDate;

  /// `M` or `F`.
  final String? sex;

  /// ISO 3166 alpha-3 (e.g. `DZA`).
  final String? nationality;

  /// Latin-script surname.
  final String? surname;

  /// Latin-script given names (may be a single concatenated string).
  final String? givenNames;

  /// True iff every check digit (document number, DOB, expiry, composite)
  /// passed. Surface this as the headline trust signal for the MRZ
  /// section of the result UI.
  final bool? valid;

  /// Per-field check-digit results.
  final MrzChecks? checks;

  const MrzNormalized({
    this.documentType,
    this.documentNumber,
    this.dateOfBirth,
    this.expiryDate,
    this.sex,
    this.nationality,
    this.surname,
    this.givenNames,
    this.valid,
    this.checks,
  });

  factory MrzNormalized.fromJson(Map<String, dynamic> json) {
    return MrzNormalized(
      documentType: json['document_type'] as String?,
      documentNumber: json['document_number'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      expiryDate: json['expiry_date'] as String?,
      sex: json['sex'] as String?,
      nationality: json['nationality'] as String?,
      surname: json['surname'] as String?,
      givenNames: json['given_names'] as String?,
      valid: json['valid'] as bool?,
      checks: json['checks'] is Map
          ? MrzChecks.fromJson((json['checks'] as Map).cast<String, dynamic>())
          : null,
    );
  }
}

/// ICAO 9303 check-digit results for a single MRZ.
///
/// Each boolean is true iff the corresponding check digit matched. Use
/// these to selectively trust individual fields (e.g. trust DOB when
/// [dateOfBirth] is true even if [composite] is false).
class MrzChecks {
  final bool? documentNumber;
  final bool? dateOfBirth;
  final bool? expiryDate;
  final bool? composite;

  const MrzChecks({
    this.documentNumber,
    this.dateOfBirth,
    this.expiryDate,
    this.composite,
  });

  factory MrzChecks.fromJson(Map<String, dynamic> json) {
    return MrzChecks(
      documentNumber: json['document_number'] as bool?,
      dateOfBirth: json['date_of_birth'] as bool?,
      expiryDate: json['expiry_date'] as bool?,
      composite: json['composite'] as bool?,
    );
  }
}
