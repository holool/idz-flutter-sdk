/// Typed wrapper for the `GET /v1/verifications/{id}/artifacts` catalog.
///
/// Each entry is server-side categorised so the client can render
/// section-by-section (Uploads / Detections / Crops / Face match /
/// Liveness / Other) instead of doing the bucketing itself.
///
/// `face_match` is its own object — not a list — so a UI can render the
/// selfie crop + document-face crop side by side with the similarity
/// score below.
class ArtifactsCatalog {
  final List<ArtifactItem> uploads;
  final List<ArtifactItem> detections;
  final List<ArtifactItem> crops;
  final FaceMatchArtifacts? faceMatch;
  final List<ArtifactItem> liveness;
  final List<ArtifactItem> other;

  const ArtifactsCatalog({
    this.uploads = const <ArtifactItem>[],
    this.detections = const <ArtifactItem>[],
    this.crops = const <ArtifactItem>[],
    this.faceMatch,
    this.liveness = const <ArtifactItem>[],
    this.other = const <ArtifactItem>[],
  });

  factory ArtifactsCatalog.fromJson(Map<String, dynamic> json) {
    return ArtifactsCatalog(
      uploads: _list(json['uploads']),
      detections: _list(json['detections']),
      crops: _list(json['crops']),
      faceMatch: json['face_match'] is Map
          ? FaceMatchArtifacts.fromJson(
              (json['face_match'] as Map).cast<String, dynamic>(),
            )
          : null,
      liveness: _list(json['liveness']),
      other: _list(json['other']),
    );
  }

  static List<ArtifactItem> _list(Object? value) {
    if (value is! List) return const <ArtifactItem>[];
    return value
        .whereType<Map>()
        .map((m) => ArtifactItem.fromJson(m.cast<String, dynamic>()))
        .toList();
  }
}

/// One artifact entry in the catalog.
///
/// [href] is server-relative (`/v1/verifications/{vid}/artifacts/{aid}`)
/// and streams the bytes back. Fetch with the same `Authorization:
/// Bearer …` header used for the rest of the API. [fieldName] carries
/// the YOLO class for per-field crops (e.g. `first_name_fr`,
/// `blood_type`) so the UI can attach the right thumbnail to the right
/// row without filename-substring matching. Null for full-image
/// uploads / detection visualisations and for legacy rows persisted
/// before field-name plumbing.
class ArtifactItem {
  final String id;
  final String href;
  final String? mime;
  final int? size;
  final String? category;
  final String? side;
  final String? fieldName;

  const ArtifactItem({
    required this.id,
    required this.href,
    this.mime,
    this.size,
    this.category,
    this.side,
    this.fieldName,
  });

  factory ArtifactItem.fromJson(Map<String, dynamic> json) {
    return ArtifactItem(
      id: (json['id'] as Object?)?.toString() ?? '',
      href: (json['href'] as String?) ?? (json['url'] as String?) ?? '',
      mime: json['mime'] as String?,
      size: json['size'] as int?,
      category: json['category'] as String?,
      side: json['side'] as String?,
      fieldName: json['field_name'] as String?,
    );
  }
}

/// Face-match section of the catalog.
///
/// [selfieCrop] is the cropped selfie face, [documentFaceCrop] is the
/// cropped face from the document. [similarity] is in [0, 1] and should
/// match `checks.face_match.score` from the verification detail. [other]
/// collects any face-related artifacts that don't fit the two-crop
/// split.
class FaceMatchArtifacts {
  final ArtifactItem? selfieCrop;
  final ArtifactItem? documentFaceCrop;
  final double? similarity;
  final List<ArtifactItem> other;

  const FaceMatchArtifacts({
    this.selfieCrop,
    this.documentFaceCrop,
    this.similarity,
    this.other = const <ArtifactItem>[],
  });

  factory FaceMatchArtifacts.fromJson(Map<String, dynamic> json) {
    return FaceMatchArtifacts(
      selfieCrop:
          _itemOrNull(json['selfie_crop']) ?? _itemOrNull(json['selfie']),
      documentFaceCrop: _itemOrNull(json['document_face_crop']) ??
          _itemOrNull(json['id_photo']),
      similarity: (json['similarity'] as num?)?.toDouble(),
      other: json['other'] is List
          ? (json['other'] as List)
                .whereType<Map>()
                .map((m) => ArtifactItem.fromJson(m.cast<String, dynamic>()))
                .toList()
          : const <ArtifactItem>[],
    );
  }

  static ArtifactItem? _itemOrNull(Object? value) {
    if (value is! Map) return null;
    return ArtifactItem.fromJson(value.cast<String, dynamic>());
  }
}
