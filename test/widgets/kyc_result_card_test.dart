import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idz_flutter/idz_flutter.dart';

Verification _buildVerification({
  String status = 'completed',
  CheckResult? document,
  CheckResult? faceMatch,
  CheckResult? liveness,
  Map<String, FieldResult>? fields,
}) {
  return Verification(
    id: 'kyc_widget_test',
    mode: 'identity',
    status: status,
    createdAt: DateTime.utc(2026, 5, 6, 12, 0, 0),
    completedAt: DateTime.utc(2026, 5, 6, 12, 0, 4),
    document: VerificationDocument(
      type: 'algerian_driving_license',
      country: 'DZA',
      fields: fields,
    ),
    checks: VerificationChecks(
      document: document,
      faceMatch: faceMatch,
      liveness: liveness,
    ),
  );
}

void main() {
  group('KycResultCard', () {
    testWidgets('shows Verified for completed status', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: KycResultCard(
                verification: _buildVerification(
                  document: const CheckResult(passed: true),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Verified'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('shows Rejected with failure_reason', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: KycResultCard(
                verification: _buildVerification(
                  status: 'rejected',
                  document: const CheckResult(
                    passed: false,
                    failureReason: 'face_mismatch',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('face_mismatch'), findsOneWidget);
    });

    testWidgets('renders face_match score as percentage', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: KycResultCard(
                verification: _buildVerification(
                  faceMatch: const CheckResult(passed: true, score: 0.97),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Face match'), findsOneWidget);
      expect(find.text('97.0%'), findsOneWidget);
    });

    testWidgets('renders extracted fields including a List value', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: KycResultCard(
                verification: _buildVerification(
                  fields: {
                    'last_name_fr': const FieldResult(
                      raw: 'EXAMPLE',
                      normalized: 'EXAMPLE',
                      valid: true,
                      side: 'front',
                    ),
                    'categories': const FieldResult(
                      normalized: ['A', 'B', 'C1'],
                      valid: true,
                      side: 'back',
                    ),
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Extracted fields'), findsOneWidget);
      expect(find.text('EXAMPLE'), findsOneWidget);
      expect(find.text('A, B, C1'), findsOneWidget);
    });
  });
}
