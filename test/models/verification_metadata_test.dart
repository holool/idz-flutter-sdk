import 'package:flutter_test/flutter_test.dart';
import 'package:idz_flutter/idz_flutter.dart';

Map<String, dynamic> _baseVerificationJson({Map<String, dynamic>? metadata}) {
  return <String, dynamic>{
    'id': 'kyc_0000000000000001',
    'mode': 'identity',
    'status': 'rejected',
    'created_at': '2026-05-19T12:00:00Z',
    'completed_at': '2026-05-19T12:00:01Z',
    'checks': <String, dynamic>{},
    if (metadata != null) 'metadata': metadata,
  };
}

void main() {
  group('Verification.metadata typed accessors', () {
    test('missingFrontFields / missingBackFields parse string lists', () {
      final v = Verification.fromJson(
        _baseVerificationJson(metadata: <String, dynamic>{
          'missing_front_fields': <String>['id_picture'],
          'missing_back_fields': <String>['mrz', 'last_name_fr'],
        }),
      );
      expect(v.missingFrontFields, ['id_picture']);
      expect(v.missingBackFields, ['mrz', 'last_name_fr']);
    });

    test('missing-field accessors default to empty when absent', () {
      final v = Verification.fromJson(_baseVerificationJson());
      expect(v.missingFrontFields, isEmpty);
      expect(v.missingBackFields, isEmpty);
    });

    test('qualityFailures parses {side, field, blur_var, glare_ratio, passed, reason}', () {
      final v = Verification.fromJson(_baseVerificationJson(metadata: <String, dynamic>{
        'quality_failures': [
          <String, dynamic>{
            'side': 'front',
            'field': 'last_name_fr',
            'blur_var': 43.0,
            'glare_ratio': 0.02,
            'passed': false,
            'reason': 'blurry',
          },
        ],
      }));
      expect(v.qualityFailures, hasLength(1));
      final q = v.qualityFailures.single;
      expect(q.side, 'front');
      expect(q.field, 'last_name_fr');
      expect(q.blurVar, 43.0);
      expect(q.glareRatio, 0.02);
      expect(q.passed, isFalse);
      expect(q.reason, 'blurry');
    });

    test('qualityScoresAll surfaces every scored region — passing AND failing', () {
      final v = Verification.fromJson(_baseVerificationJson(metadata: <String, dynamic>{
        'quality_scores_all': [
          <String, dynamic>{'side': 'front', 'field': 'first_name_fr', 'passed': true, 'blur_var': 120.0},
          <String, dynamic>{'side': 'back', 'field': 'mrz', 'passed': false, 'blur_var': 18.0, 'reason': 'blurry'},
        ],
      }));
      expect(v.qualityScoresAll.map((q) => q.passed), [true, false]);
    });

    test('mrzVizDisagreements parses mrz_value / viz_value / code / message', () {
      final v = Verification.fromJson(_baseVerificationJson(metadata: <String, dynamic>{
        'mrz_viz_disagreements': [
          <String, dynamic>{
            'field': 'given_names',
            'mrz_value': 'MOHAMED',
            'viz_value': 'MOUHAMED',
            'code': 'field_mismatch',
            'message': 'MRZ given names differ from VIZ',
          },
        ],
      }));
      final d = v.mrzVizDisagreements.single;
      expect(d.field, 'given_names');
      expect(d.mrzValue, 'MOHAMED');
      expect(d.vizValue, 'MOUHAMED');
      expect(d.code, 'field_mismatch');
      expect(d.message, 'MRZ given names differ from VIZ');
    });

    test('consistencyIssues and gazetteMisses parse the shared FieldFinding shape', () {
      final v = Verification.fromJson(_baseVerificationJson(metadata: <String, dynamic>{
        'consistency_issues': [
          <String, dynamic>{
            'field': 'date_of_expiry',
            'code': 'validity_window_off',
            'message': 'validity_window:8y expected~10y',
          },
        ],
        'gazette_misses': [
          <String, dynamic>{
            'field': 'place_of_birth',
            'code': 'place_not_in_gazette',
            'message': '"BIR EL JIR" not in gazette',
          },
        ],
      }));
      expect(v.consistencyIssues.single.code, 'validity_window_off');
      expect(v.gazetteMisses.single.field, 'place_of_birth');
    });

    test('routing parses verdict + failure-bucket lists', () {
      final v = Verification.fromJson(_baseVerificationJson(metadata: <String, dynamic>{
        'routing': <String, dynamic>{
          'verdict': 'needs_review',
          'core_valid_count': 4,
          'index_failures': <String>[],
          'core_failures': <String>['blood_type'],
          'soft_failures': <String>['date_of_expiry'],
          'review_reasons': <String>['mrz_viz_disagrees:given_names'],
        },
      }));
      final r = v.routing!;
      expect(r.verdict, 'needs_review');
      expect(r.coreValidCount, 4);
      expect(r.indexFailures, isEmpty);
      expect(r.coreFailures, ['blood_type']);
      expect(r.softFailures, ['date_of_expiry']);
      expect(r.reviewReasons, ['mrz_viz_disagrees:given_names']);
    });

    test('routing is null when metadata is missing the key', () {
      final v = Verification.fromJson(_baseVerificationJson());
      expect(v.routing, isNull);
    });

    test('object-list accessors tolerate the wrong shape gracefully', () {
      final v = Verification.fromJson(_baseVerificationJson(metadata: <String, dynamic>{
        'quality_failures': 'not a list',
        'mrz_viz_disagreements': <Object?>['scalar entry', 42, null],
      }));
      expect(v.qualityFailures, isEmpty);
      // whereType<Map>() drops the scalar entries, leaving an empty list.
      expect(v.mrzVizDisagreements, isEmpty);
    });
  });

  group('UserAction', () {
    test('parses the new "retry" wire value', () {
      expect(UserAction.fromWire('retry'), UserAction.retry);
      expect(UserAction.retry.wireValue, 'retry');
    });

    test('unknown wire values fall back to none', () {
      expect(UserAction.fromWire('open_the_pod_bay_doors'), UserAction.none);
    });
  });
}
