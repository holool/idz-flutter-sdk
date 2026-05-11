import 'dart:ui' as ui;

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idz_flutter/src/widgets/selfie_capture_screen.dart';
import 'package:idz_flutter/src/widgets/painters/face_overlay_painter.dart';

import '../helpers/fake_camera_platform.dart';

void main() {
  late FakeCameraPlatform fakeCameraPlatform;

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

  group('SelfieCaptureScreen', () {
    testWidgets('shows loading indicator before camera init', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SelfieCaptureScreen(onCapture: (_) {})),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows face positioning instruction after camera init', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: SelfieCaptureScreen(onCapture: (_) {})),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.textContaining('face'), findsOneWidget);
    });

    testWidgets('shows capture button after camera init', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SelfieCaptureScreen(onCapture: (_) {})),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });

    testWidgets('has face oval overlay painter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SelfieCaptureScreen(onCapture: (_) {})),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final customPaint = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is FaceOverlayPainter,
      );
      expect(customPaint, findsOneWidget);
    });

    testWidgets('shows cancel button when onCancel provided', (tester) async {
      var cancelCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SelfieCaptureScreen(
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
  });

  group('FaceOverlayPainter', () {
    test('paints without errors', () {
      final painter = FaceOverlayPainter();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      painter.paint(canvas, const Size(400, 800));
      recorder.endRecording();
    });

    test('shouldRepaint returns false', () {
      final painter = FaceOverlayPainter();
      expect(painter.shouldRepaint(painter), isFalse);
    });
  });
}
