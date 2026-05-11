import 'dart:ui' as ui;

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idz_flutter/src/widgets/document_capture_screen.dart';
import 'package:idz_flutter/src/widgets/painters/card_overlay_painter.dart';

import '../helpers/fake_camera_platform.dart';

void main() {
  late FakeCameraPlatform fakeCameraPlatform;

  setUp(() {
    fakeCameraPlatform = FakeCameraPlatform();
    CameraPlatform.instance = fakeCameraPlatform;

    // Mock permission handler to grant camera permission.
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

  group('DocumentCaptureScreen', () {
    testWidgets('shows loading indicator before camera init', (tester) async {
      // Pump the widget but don't settle — camera init is async.
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentCaptureScreen(isFront: true, onCapture: (_) {}),
        ),
      );

      // Before camera initializes, a CircularProgressIndicator is shown.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows front instruction text after camera init', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentCaptureScreen(isFront: true, onCapture: (_) {}),
        ),
      );
      // Pump through the full camera init chain:
      // permission request → availableCameras → controller create → init → setState
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // After camera initializes, instruction text is visible.
      expect(find.textContaining('FRONT'), findsOneWidget);
    });

    testWidgets('shows back instruction text when isFront is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentCaptureScreen(isFront: false, onCapture: (_) {}),
        ),
      );
      // Pump through the full camera init chain:
      // permission request → availableCameras → controller create → init → setState
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.textContaining('BACK'), findsOneWidget);
    });

    testWidgets('shows capture button after camera init', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentCaptureScreen(isFront: true, onCapture: (_) {}),
        ),
      );
      // Pump through the full camera init chain:
      // permission request → availableCameras → controller create → init → setState
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });

    testWidgets('shows cancel button when onCancel provided', (tester) async {
      var cancelCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: DocumentCaptureScreen(
            isFront: true,
            onCapture: (_) {},
            onCancel: () => cancelCalled = true,
          ),
        ),
      );
      // Pump through the full camera init chain:
      // permission request → availableCameras → controller create → init → setState
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final closeButton = find.byIcon(Icons.close);
      expect(closeButton, findsOneWidget);

      await tester.tap(closeButton);
      expect(cancelCalled, isTrue);
    });

    testWidgets('has card overlay painter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentCaptureScreen(isFront: true, onCapture: (_) {}),
        ),
      );
      // Pump through the full camera init chain:
      // permission request → availableCameras → controller create → init → setState
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // The CustomPaint with CardOverlayPainter should be present.
      final customPaint = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is CardOverlayPainter,
      );
      expect(customPaint, findsOneWidget);
    });
  });

  group('CardOverlayPainter', () {
    test('paints without errors', () {
      final painter = CardOverlayPainter();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Should not throw.
      painter.paint(canvas, const Size(400, 800));
      recorder.endRecording();
    });

    test('shouldRepaint returns false', () {
      final painter = CardOverlayPainter();
      expect(painter.shouldRepaint(painter), isFalse);
    });
  });
}
