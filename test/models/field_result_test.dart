import 'package:flutter_test/flutter_test.dart';
import 'package:idz_flutter/idz_flutter.dart';

void main() {
  group('FieldResult', () {
    test('asString returns the string when normalized is a String', () {
      final fr = FieldResult.fromJson({
        'raw': 'mohamed',
        'normalized': 'MOHAMED',
        'valid': true,
        'side': 'front',
      });
      expect(fr.asString, 'MOHAMED');
      expect(fr.asMrz, isNull);
      expect(fr.asStringList, isNull);
    });

    test('asStringList returns the list when normalized is a List', () {
      final fr = FieldResult.fromJson({
        'raw': 'A,B,C',
        'normalized': ['A', 'B', 'C1'],
        'valid': true,
        'side': 'back',
      });
      expect(fr.asStringList, ['A', 'B', 'C1']);
      expect(fr.asString, isNull);
    });

    test('asMrz parses the TD1 object with all four checks', () {
      final fr = FieldResult.fromJson({
        'raw':
            'I<DZAX00000001<<<<<<<<<<<<<<<\n9001017M3001012DZA<<<<<<<<<<<6\nBEN<MITHAL<<MOHAMED<<<<<<<<<<<',
        'normalized': {
          'document_type': 'DL',
          'document_number': 'X00000001',
          'date_of_birth': '1990/01/01',
          'expiry_date': '2030/01/01',
          'sex': 'M',
          'nationality': 'DZA',
          'surname': 'BEN MITHAL',
          'given_names': 'MOHAMED',
          'valid': true,
          'checks': {
            'document_number': true,
            'date_of_birth': true,
            'expiry_date': true,
            'composite': true,
          },
        },
        'valid': true,
        'side': 'back',
      });
      final mrz = fr.asMrz;
      expect(mrz, isNotNull);
      expect(mrz!.documentType, 'DL');
      expect(mrz.documentNumber, 'X00000001');
      expect(mrz.dateOfBirth, '1990/01/01');
      expect(mrz.expiryDate, '2030/01/01');
      expect(mrz.sex, 'M');
      expect(mrz.nationality, 'DZA');
      expect(mrz.surname, 'BEN MITHAL');
      expect(mrz.givenNames, 'MOHAMED');
      expect(mrz.valid, true);
      expect(mrz.checks?.documentNumber, true);
      expect(mrz.checks?.dateOfBirth, true);
      expect(mrz.checks?.expiryDate, true);
      expect(mrz.checks?.composite, true);
    });

    test('asMrz tolerates partial check shape', () {
      final fr = FieldResult.fromJson({
        'normalized': {
          'document_number': 'X00000001',
          'valid': false,
          'checks': {
            'document_number': true,
            'composite': false,
            // dob/expiry missing
          },
        },
      });
      final mrz = fr.asMrz!;
      expect(mrz.valid, false);
      expect(mrz.checks?.documentNumber, true);
      expect(mrz.checks?.composite, false);
      expect(mrz.checks?.dateOfBirth, isNull);
      expect(mrz.checks?.expiryDate, isNull);
    });

    test('helpers are independent — string field returns null for asMrz', () {
      final fr = FieldResult.fromJson({'normalized': 'MOHAMED'});
      expect(fr.asMrz, isNull);
      expect(fr.asString, 'MOHAMED');
    });
  });

  group('Verification.postprocessNotes', () {
    test('reads notes from metadata.postprocess_notes', () {
      final v = Verification.fromJson({
        'id': 'kyc_x',
        'mode': 'document',
        'status': 'completed',
        'created_at': '2026-05-10T12:00:00Z',
        'checks': <String, dynamic>{},
        'metadata': {
          'postprocess_notes': [
            'name_csv_snap:first_name',
            'validity_window:3650d expected~3650d (issue=2020/01/01 expiry=2030/01/01)',
          ],
        },
      });
      expect(v.postprocessNotes, hasLength(2));
      expect(v.postprocessNotes.first, startsWith('name_csv_snap:'));
    });

    test('returns empty list when metadata is missing', () {
      final v = Verification.fromJson({
        'id': 'kyc_x',
        'mode': 'document',
        'status': 'completed',
        'created_at': '2026-05-10T12:00:00Z',
        'checks': <String, dynamic>{},
      });
      expect(v.postprocessNotes, isEmpty);
    });
  });
}
