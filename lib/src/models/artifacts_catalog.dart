/// Typed wrapper for the `GET /v1/verifications/{id}/artifacts` catalog.
///
/// Each entry is server-side categorised so the client can render
/// section-by-section (Uploads / Detections / Crops / Face match /
/// Liveness / Other) instead of doing the bucketing itself.
///
/// `face_match` is its own object — not a list — so a UI can render
/// selfie + id_photo side by side with the similarity score below.
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
/// `url` is server-relative (`/v1/verifications/{vid}/artifacts/{aid}`)
/// and streams the bytes back. Fetch with the same `Authorization:
/// Bearer …` header used for the rest of the API. `field_name` is null
/// for crops today (per-crop labels aren't persisted yet) and for
/// uploads where the field name doesn't apply.
class ArtifactItem {
  final String id;
  final String url;
  final String? mime;
  final int? size;
  final String? category;
  final String? side;
  final String? fieldName;

  const ArtifactItem({
    required this.id,
    required this.url,
    this.mime,
    this.size,
    this.category,
    this.side,
    this.fieldName,
  });

  factory ArtifactItem.fromJson(Map<String, dynamic> json) {
    return ArtifactItem(
      id: (json['id'] as Object?)?.toString() ?? '',
      url: (json['url'] as String?) ?? (json['href'] as String?) ?? '',
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
/// `selfie` is the captured selfie crop, `idPhoto` is the cropped photo
/// from the document. `similarity` is in [0, 1]; it should match the
/// `checks.face_match.score` from the verification detail.
/// `other` collects any face-related artifacts that don't fit the
/// selfie/id_photo split.
class FaceMatchArtifacts {
  final ArtifactItem? selfie;
  final ArtifactItem? idPhoto;
  final double? similarity;
  final List<ArtifactItem> other;

  const FaceMatchArtifacts({
    this.selfie,
    this.idPhoto,
    this.similarity,
    this.other = const <ArtifactItem>[],
  });

  factory FaceMatchArtifacts.fromJson(Map<String, dynamic> json) {
    return FaceMatchArtifacts(
      selfie: json['selfie'] is Map
          ? ArtifactItem.fromJson(
              (json['selfie'] as Map).cast<String, dynamic>(),
            )
          : null,
      idPhoto: json['id_photo'] is Map
          ? ArtifactItem.fromJson(
              (json['id_photo'] as Map).cast<String, dynamic>(),
            )
          : null,
      similarity: (json['similarity'] as num?)?.toDouble(),
      other: json['other'] is List
          ? (json['other'] as List)
                .whereType<Map>()
                .map((m) => ArtifactItem.fromJson(m.cast<String, dynamic>()))
                .toList()
          : const <ArtifactItem>[],
    );
  }
}
