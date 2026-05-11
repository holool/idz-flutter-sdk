import 'document_type.dart';
import 'field_result.dart';

class Verification {
  final String id;
  final String mode;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final VerificationDocument? document;
  final VerificationChecks checks;
  final List<VerificationArtifact> artifacts;
  final Map<String, dynamic>? metadata;

  const Verification({
    required this.id,
    required this.mode,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.document,
    required this.checks,
    this.artifacts = const <VerificationArtifact>[],
    this.metadata,
  });

  bool get isPassed => status == 'completed';
  bool get isRejected => status == 'rejected';

  /// Pipeline-emitted hints surfaced via `metadata.postprocess_notes`.
  /// Common patterns:
  ///   - `name_csv_snap:<field>` — OCR snapped to a curated CSV entry.
  ///   - `validity_window:Xd expected~Yd (...)` — issue→expiry delta off.
  ///   - `categories:*` / `categories_table:*` — DL categories merge note.
  /// Empty list when no notes were emitted.
  List<String> get postprocessNotes {
    final raw = metadata?['postprocess_notes'];
    if (raw is List) return raw.whereType<String>().toList();
    return const <String>[];
  }

  factory Verification.fromJson(Map<String, dynamic> json) {
    return Verification(
      id: json['id'] as String,
      mode: json['mode'] as String,
      status: json['status'] as String,
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
    );
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
  final String? failureReason;

  const CheckResult({this.passed, this.score, this.failureReason});

  factory CheckResult.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return const CheckResult();
    return CheckResult(
      passed: json['passed'] as bool?,
      score: _doubleOrNull(json['score']),
      failureReason: json['failure_reason'] as String?,
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
