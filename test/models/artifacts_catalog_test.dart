import 'package:flutter_test/flutter_test.dart';
import 'package:idz_flutter/idz_flutter.dart';

void main() {
  group('ArtifactsCatalog.fromJson', () {
    test('parses every section', () {
      final cat = ArtifactsCatalog.fromJson({
        'uploads': [
          {
            'id': 'u1',
            'url': '/v1/verifications/kyc_x/artifacts/u1',
            'mime': 'image/jpeg',
            'size': 1024,
            'category': 'upload',
            'side': 'front',
            'field_name': null,
          },
        ],
        'detections': [],
        'crops': [
          {
            'id': 'c1',
            'url': '/v1/verifications/kyc_x/artifacts/c1',
            'category': 'crop',
            'side': 'front',
            'field_name': null,
          },
        ],
        'face_match': {
          'selfie': {
            'id': 'fs',
            'url': '/v1/verifications/kyc_x/artifacts/fs',
            'category': 'face_match',
          },
          'id_photo': {
            'id': 'fi',
            'url': '/v1/verifications/kyc_x/artifacts/fi',
            'category': 'face_match',
          },
          'similarity': 0.91,
          'other': [],
        },
        'liveness': [],
        'other': [],
      });
      expect(cat.uploads.single.id, 'u1');
      expect(cat.uploads.single.side, 'front');
      expect(cat.crops.single.id, 'c1');
      expect(cat.faceMatch?.similarity, 0.91);
      expect(cat.faceMatch?.selfie?.id, 'fs');
      expect(cat.faceMatch?.idPhoto?.id, 'fi');
    });

    test('falls back to href when url is missing on an item', () {
      final item = ArtifactItem.fromJson({
        'id': 'x',
        'href': '/v1/verifications/kyc_x/artifacts/x',
      });
      expect(item.url, '/v1/verifications/kyc_x/artifacts/x');
    });

    test('handles null face_match block', () {
      final cat = ArtifactsCatalog.fromJson({
        'uploads': [],
        'face_match': null,
      });
      expect(cat.faceMatch, isNull);
    });

    test('coerces non-string id (server may return int) to a string', () {
      final item = ArtifactItem.fromJson({
        'id': 42,
        'url': '/v1/verifications/kyc_x/artifacts/42',
      });
      expect(item.id, '42');
    });
  });
}
