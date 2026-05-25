import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idz_flutter/idz_flutter.dart';
import 'package:idz_flutter/src/widgets/result/fields_tab.dart';

Verification _verification(Map<String, dynamic> overrides) {
  return Verification.fromJson({
    'id': 'kyc_x',
    'mode': 'document',
    'status': 'completed',
    'created_at': '2026-05-10T12:00:00Z',
    'checks': <String, dynamic>{},
    ...overrides,
  });
}

void main() {
  testWidgets('renders rows for OCR fields and a separate MRZ section', (
    tester,
  ) async {
    final v = _verification({
      'document': {
        'type': 'algerian_driving_license',
        'fields': {
          'first_name_fr': {
            'normalized': 'MOHAMED',
            'valid': true,
            'side': 'front',
          },
          'last_name_fr': {
            'normalized': 'BEN MITHAL',
            'valid': true,
            'side': 'front',
          },
          'mrz': {
            'normalized': {
              'document_number': 'X0001',
              'date_of_birth': '1990/01/01',
              'expiry_date': '2030/01/01',
              'sex': 'M',
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
          },
        },
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FieldsTab(verification: v)),
      ),
    );

    expect(find.text('First Name Fr'), findsOneWidget);
    expect(find.text('Last Name Fr'), findsOneWidget);
    // MOHAMED appears in both the table row and the MRZ given_names row.
    expect(find.text('MOHAMED'), findsAtLeast(1));
    expect(find.text('Valid'), findsOneWidget);
    expect(find.text('Document #'), findsOneWidget);
  });

  testWidgets('shows MRZ disagrees badge when DOB conflicts and check passed', (
    tester,
  ) async {
    final v = _verification({
      'document': {
        'fields': {
          'date_of_birth': {
            'normalized': '1990/01/02',
            'valid': true,
            'side': 'front',
          },
          'mrz': {
            'normalized': {
              'date_of_birth': '1990/01/01',
              'valid': false,
              'checks': {
                'document_number': false,
                'date_of_birth': true,
                'expiry_date': false,
                'composite': false,
              },
            },
            'valid': false,
            'side': 'back',
          },
        },
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FieldsTab(verification: v)),
      ),
    );

    expect(find.text('MRZ disagrees'), findsOneWidget);
    // MRZ section header should still be present.
    expect(find.text('Invalid'), findsOneWidget);
  });

  testWidgets('renders validity-window banner when note present', (
    tester,
  ) async {
    final v = _verification({
      'metadata': {
        'postprocess_notes': [
          'validity_window:1d expected~3650d (issue=2025/01/01 expiry=2025/01/02)',
        ],
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FieldsTab(verification: v)),
      ),
    );

    expect(find.text('Issue → expiry window is unusual'), findsOneWidget);
  });

  testWidgets('shows auto-corrected hint when name_csv_snap matches a field', (
    tester,
  ) async {
    final v = _verification({
      'document': {
        'fields': {
          'first_name': {'normalized': 'محمد', 'valid': true, 'side': 'front'},
        },
      },
      'metadata': {
        'postprocess_notes': ['name_csv_snap:first_name'],
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FieldsTab(verification: v)),
      ),
    );

    expect(
      find.byTooltip(
        'Auto-corrected: the OCR value was snapped to a curated CSV entry.',
      ),
      findsOneWidget,
    );
  });
}
