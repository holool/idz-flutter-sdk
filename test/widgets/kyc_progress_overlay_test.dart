import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idz_flutter/src/widgets/kyc_progress_overlay.dart';

void main() {
  group('KycProgressOverlay', () {
    testWidgets('shows initial "Uploading" stage', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: KycProgressOverlay()));

      expect(find.textContaining('Uploading'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
    });

    testWidgets('shows step counter', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: KycProgressOverlay()));

      expect(find.textContaining('Step 1 of 4'), findsOneWidget);
    });

    testWidgets('progresses to next stage after timer', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: KycProgressOverlay()));

      // Initial stage: "Uploading documents..."
      expect(find.textContaining('Uploading'), findsOneWidget);

      // Advance past the 2-second default stage duration.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 600));

      // Should now show second stage: "Analyzing document..."
      expect(find.textContaining('Analyzing'), findsOneWidget);
      expect(find.byIcon(Icons.document_scanner), findsOneWidget);
    });

    testWidgets('shows cancel button when onCancel is provided', (
      tester,
    ) async {
      var cancelCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: KycProgressOverlay(onCancel: () => cancelCalled = true),
        ),
      );

      final cancelButton = find.text('Cancel');
      expect(cancelButton, findsOneWidget);

      await tester.tap(cancelButton);
      expect(cancelCalled, isTrue);
    });

    testWidgets('does not show cancel button when onCancel is null', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: KycProgressOverlay()));

      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets('calls onComplete after all stages finish', (tester) async {
      var completeCalled = false;

      // Use short custom stages for faster test.
      final stages = [
        const ProgressStage(
          label: 'Step A...',
          icon: Icons.upload,
          minDuration: Duration(milliseconds: 100),
        ),
        const ProgressStage(
          label: 'Step B...',
          icon: Icons.check,
          minDuration: Duration(milliseconds: 100),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: KycProgressOverlay(
            stages: stages,
            onComplete: () => completeCalled = true,
          ),
        ),
      );

      expect(find.textContaining('Step A'), findsOneWidget);

      // Advance through all stages + animation time.
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 600));

      expect(completeCalled, isTrue);
    });

    testWidgets('supports custom stages', (tester) async {
      final stages = [
        const ProgressStage(label: 'Custom stage one', icon: Icons.star),
        const ProgressStage(label: 'Custom stage two', icon: Icons.done),
      ];

      await tester.pumpWidget(
        MaterialApp(home: KycProgressOverlay(stages: stages)),
      );

      expect(find.textContaining('Custom stage one'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.textContaining('Step 1 of 2'), findsOneWidget);
    });

    testWidgets('has progress indicator', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: KycProgressOverlay()));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('fast-forwards when future completes', (tester) async {
      final completer = Completer<void>();
      var completeCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: KycProgressOverlay(
            future: completer.future,
            onComplete: () => completeCalled = true,
          ),
        ),
      );

      // Initially on first stage.
      expect(find.textContaining('Uploading'), findsOneWidget);

      // Complete the future — fast-forward through all stages.
      completer.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 100));

      expect(completeCalled, isTrue);
    });
  });

  group('ProgressStage', () {
    test('defaultStages has 4 items', () {
      expect(defaultStages.length, 4);
    });

    test('defaultStages contains expected labels', () {
      final labels = defaultStages.map((s) => s.label).toList();
      expect(labels, contains('Uploading documents...'));
      expect(labels, contains('Analyzing document...'));
      expect(labels, contains('Verifying identity...'));
      expect(labels, contains('Processing results...'));
    });

    test('each stage has a minimum 2-second duration by default', () {
      for (final stage in defaultStages) {
        expect(stage.minDuration.inSeconds, greaterThanOrEqualTo(2));
      }
    });
  });
}
