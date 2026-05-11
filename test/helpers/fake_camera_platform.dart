import 'dart:async';
import 'dart:math';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A fake [CameraPlatform] implementation for widget tests.
///
/// Provides minimal camera lifecycle support so that widgets using
/// [CameraController] can initialize without hitting real platform channels.
class FakeCameraPlatform extends CameraPlatform
    with MockPlatformInterfaceMixin {
  final List<CameraDescription> cameras;
  bool createCalled = false;
  bool initializeCalled = false;
  bool disposeCalled = false;
  bool takePictureCalled = false;

  final _cameraEvents = StreamController<CameraEvent>.broadcast();

  FakeCameraPlatform({
    this.cameras = const [
      CameraDescription(
        name: 'fake_back_0',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      ),
      CameraDescription(
        name: 'fake_front_1',
        lensDirection: CameraLensDirection.front,
        sensorOrientation: 270,
      ),
    ],
  });

  @override
  Future<List<CameraDescription>> availableCameras() async => cameras;

  @override
  Future<int> createCamera(
    CameraDescription cameraDescription,
    ResolutionPreset? resolutionPreset, {
    bool enableAudio = false,
  }) async {
    createCalled = true;
    return 0;
  }

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings? mediaSettings,
  ) async {
    createCalled = true;
    return 0;
  }

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    initializeCalled = true;
    if (!_cameraEvents.isClosed) {
      _cameraEvents.add(
        CameraInitializedEvent(
          cameraId,
          1920,
          1080,
          ExposureMode.auto,
          true,
          FocusMode.auto,
          true,
        ),
      );
    }
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) {
    return _cameraEvents.stream
        .where((e) => e is CameraInitializedEvent)
        .cast<CameraInitializedEvent>();
  }

  @override
  Stream<CameraClosingEvent> onCameraClosing(int cameraId) {
    return _cameraEvents.stream
        .where((e) => e is CameraClosingEvent)
        .cast<CameraClosingEvent>();
  }

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) {
    return _cameraEvents.stream
        .where((e) => e is CameraErrorEvent)
        .cast<CameraErrorEvent>();
  }

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() {
    return const Stream.empty();
  }

  @override
  Future<void> dispose(int cameraId) async {
    disposeCalled = true;
  }

  @override
  Future<XFile> takePicture(int cameraId) async {
    takePictureCalled = true;
    return XFile('/tmp/fake_photo.jpg');
  }

  @override
  Future<void> prepareForVideoRecording() async {}

  @override
  Future<void> startVideoRecording(
    int cameraId, {
    Duration? maxVideoDuration,
  }) async {}

  @override
  Future<XFile> stopVideoRecording(int cameraId) async {
    return XFile('/tmp/fake_video.mp4');
  }

  @override
  Future<void> pauseVideoRecording(int cameraId) async {}

  @override
  Future<void> resumeVideoRecording(int cameraId) async {}

  @override
  Future<void> setFlashMode(int cameraId, FlashMode mode) async {}

  @override
  Future<void> setExposureMode(int cameraId, ExposureMode mode) async {}

  @override
  Future<double> setExposurePoint(int cameraId, Point<double>? point) async =>
      0.0;

  @override
  Future<double> getMinExposureOffset(int cameraId) async => -2.0;

  @override
  Future<double> getMaxExposureOffset(int cameraId) async => 2.0;

  @override
  Future<double> setExposureOffset(int cameraId, double offset) async => offset;

  @override
  Future<void> setFocusMode(int cameraId, FocusMode mode) async {}

  @override
  Future<void> setFocusPoint(int cameraId, Point<double>? point) async {}

  @override
  Future<double> getMaxZoomLevel(int cameraId) async => 4.0;

  @override
  Future<double> getMinZoomLevel(int cameraId) async => 1.0;

  @override
  Future<void> setZoomLevel(int cameraId, double zoom) async {}

  @override
  Future<void> lockCaptureOrientation(
    int cameraId,
    DeviceOrientation orientation,
  ) async {}

  @override
  Future<void> unlockCaptureOrientation(int cameraId) async {}

  @override
  Future<void> pausePreview(int cameraId) async {}

  @override
  Future<void> resumePreview(int cameraId) async {}

  @override
  Future<void> setDescriptionWhileRecording(
    CameraDescription description,
  ) async {}

  @override
  Widget buildPreview(int cameraId) {
    return const SizedBox(
      width: 1920,
      height: 1080,
      child: ColoredBox(color: Color(0xFF000000)),
    );
  }

  void dispose2() {
    // Keep the stream open so CameraController's background `.first` listeners
    // for error/closing events do not complete with `Bad state: No element`.
  }
}
