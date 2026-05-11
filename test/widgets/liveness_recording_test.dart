import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idz_flutter/src/widgets/liveness_recording_screen.dart';

import '../helpers/fake_camera_platform.dart';

void main() {
  late FakeCameraPlatform fakeCameraPlatform;

  Future<void> pumpThroughWarmup(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
  }

  setUp(() {
    fakeCameraPlatform = FakeCameraPlatform();
    CameraPlatform.instance = fakeCameraPlatform;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          (MethodCall call) async {
            if (call.method == 'checkPermissionStatus') return 1;
            if (call.method == 'requestPermissions') {
              return <int, int>{1: 1};
            }
            return null;
          },
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          null,
        );
    fakeCameraPlatform.dispose2();
  });

  group('LivenessRecordingScreen', () {
    testWidgets('shows loading indicator before camera init', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: LivenessRecordingScreen(onCapture: (_) {})),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows first challenge instruction after camera init', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LivenessRecordingScreen(
            onCapture: (_) {},
            challenges: const [
              LivenessChallenge(
                instruction: 'Custom action',
                icon: Icons.star,
                duration: Duration(seconds: 5),
              ),
            ],
          ),
        ),
      );
      await pumpThroughWarmup(tester);

      expect(find.textContaining('Custom action'), findsOneWidget);
    });

    testWidgets('shows challenge counter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LivenessRecordingScreen(
            onCapture: (_) {},
            challenges: const [
              LivenessChallenge(
                instruction: 'Custom action',
                icon: Icons.star,
                duration: Duration(seconds: 5),
              ),
            ],
          ),
        ),
      );
      await pumpThroughWarmup(tester);

      expect(find.textContaining('1 of 1'), findsOneWidget);
    });

    testWidgets('advances challenge after timer duration', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LivenessRecordingScreen(
            onCapture: (_) {},
            challenges: const [
              LivenessChallenge(
                instruction: 'First action',
                icon: Icons.star,
                duration: Duration(seconds: 1),
              ),
              LivenessChallenge(
                instruction: 'Second action',
                icon: Icons.face,
                duration: Duration(seconds: 5),
              ),
            ],
          ),
        ),
      );
      await pumpThroughWarmup(tester);

      expect(find.textContaining('First action'), findsOneWidget);

      // Advance past the first challenge duration.
      await tester.pump(const Duration(seconds: 2));

      // Second challenge should now show.
      expect(find.textContaining('Second action'), findsOneWidget);
      expect(find.textContaining('2 of 2'), findsOneWidget);
    });

    testWidgets('shows cancel button when onCancel provided', (tester) async {
      var cancelCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: LivenessRecordingScreen(
            onCapture: (_) {},
            onCancel: () => cancelCalled = true,
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final closeButton = find.byIcon(Icons.close);
      expect(closeButton, findsOneWidget);

      await tester.tap(closeButton);
      expect(cancelCalled, isTrue);
    });

    testWidgets('accepts custom challenges', (tester) async {
      final customChallenges = [
        const LivenessChallenge(
          instruction: 'Custom action',
          icon: Icons.star,
          duration: Duration(seconds: 1),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: LivenessRecordingScreen(
            onCapture: (_) {},
            challenges: customChallenges,
          ),
        ),
      );
      await pumpThroughWarmup(tester);

      expect(find.textContaining('Custom action'), findsOneWidget);
      expect(find.textContaining('1 of 1'), findsOneWidget);
    });
  });

  group('LivenessChallenge', () {
    test('defaultChallenges has expected number of items', () {
      expect(defaultChallenges.length, 5);
    });

    test('defaultChallenges contains expected instructions', () {
      final instructions = defaultChallenges.map((c) => c.instruction).toList();
      expect(instructions, contains('Look at the camera'));
      expect(instructions, contains('Blink your eyes'));
      expect(instructions, contains('Smile'));
      expect(instructions, contains('Turn your head left'));
      expect(instructions, contains('Turn your head right'));
    });

    test('each challenge has a positive duration', () {
      for (final challenge in defaultChallenges) {
        expect(challenge.duration.inSeconds, greaterThan(0));
      }
    });
  });
}
