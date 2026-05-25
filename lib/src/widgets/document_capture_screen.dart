import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'capture/capture_quality_probe.dart';
import 'capture/quality_indicator.dart';
import 'painters/card_overlay_painter.dart';

class DocumentCaptureScreen extends StatefulWidget {
  final bool isFront;
  final void Function(File image) onCapture;
  final VoidCallback? onCancel;

  /// Live capture-quality checks (blur / glare / steadiness). Defaults
  /// to [CaptureQualityProbe.standard]; pass [CaptureQualityProbe.disabled]
  /// to turn the live indicator off entirely. The shutter is never
  /// disabled by the probe — failing checks only soften the button
  /// label so the user can still override.
  final CaptureQualityProbe qualityProbe;

  /// Optional callback fired on every probe evaluation (~5 Hz). Useful
  /// for analytics / threshold tuning. Not called when the probe is
  /// [CaptureQualityProbe.disabled].
  final ValueChanged<QualityReport>? onQualityChanged;

  const DocumentCaptureScreen({
    super.key,
    required this.isFront,
    required this.onCapture,
    this.onCancel,
    CaptureQualityProbe? qualityProbe,
    this.onQualityChanged,
  }) : qualityProbe = qualityProbe ?? const _StandardProbeSentinel();

  @override
  State<DocumentCaptureScreen> createState() => _DocumentCaptureScreenState();
}

/// `const`-friendly stand-in for `CaptureQualityProbe.standard()` so the
/// widget constructor stays `const`-compatible while still letting us
/// pick up the standard thresholds.
class _StandardProbeSentinel extends CaptureQualityProbe {
  const _StandardProbeSentinel()
      : super(
          blurMinVariance: 80,
          glareMaxFraction: 0.03,
          steadinessMaxDelta: 5,
        );
}

class _DocumentCaptureScreenState extends State<DocumentCaptureScreen> {
  CameraController? _controller;
  bool _isCapturing = false;
  File? _capturedImage;

  // Quality-probe state. _streamRunning tracks whether we currently
  // hold a startImageStream subscription so we don't double-start /
  // double-stop. _processing prevents overlapping probe invocations
  // when a frame arrives mid-evaluation.
  final ValueNotifier<QualityReport?> _quality = ValueNotifier(null);
  Uint8List? _prevDownscaledY;
  bool _streamRunning = false;
  bool _processing = false;
  DateTime _lastEvalAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const _evalInterval = Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (status.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission required')),
        );
      }
      return;
    }

    final cameras = await availableCameras();
    final rearCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      rearCamera,
      ResolutionPreset.high,
      enableAudio: false,
      // YUV420 lets us read the Y (luma) plane directly on both
      // platforms — Android natively, iOS via the camera plugin's
      // internal conversion. Without this the iOS default (bgra8888)
      // would force a colorspace conversion every frame.
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});

    if (widget.qualityProbe.isEnabled) {
      await _startQualityStream();
    }
  }

  Future<void> _startQualityStream() async {
    final controller = _controller;
    if (controller == null || _streamRunning) return;
    try {
      await controller.startImageStream(_onCameraFrame);
      _streamRunning = true;
    } catch (e) {
      // Image streaming is unsupported on some emulators / older
      // Android pipelines. Fail silently — the user still gets the
      // manual shutter, just no live quality feedback.
      debugPrint('idz_flutter: image stream start failed: $e');
    }
  }

  Future<void> _stopQualityStream() async {
    final controller = _controller;
    if (controller == null || !_streamRunning) return;
    try {
      await controller.stopImageStream();
    } catch (_) {
      // Ignore — we only ever called this after a successful start.
    } finally {
      _streamRunning = false;
    }
  }

  void _onCameraFrame(CameraImage image) {
    if (_processing || !mounted) return;
    final now = DateTime.now();
    if (now.difference(_lastEvalAt) < _evalInterval) return;
    _lastEvalAt = now;
    _processing = true;

    try {
      final y = _extractYPlane(image);
      if (y == null) return;
      final report = widget.qualityProbe.evaluate(
        currentY: y,
        width: image.width,
        height: image.height,
        previousY: _prevDownscaledY,
      );
      _prevDownscaledY = report.downscaledY;
      _quality.value = report;
      final cb = widget.onQualityChanged;
      if (cb != null) cb(report);
    } finally {
      _processing = false;
    }
  }

  /// Pull the Y (luma) plane out of a YUV420 [CameraImage] as a tight
  /// `width × height` buffer, stripping any row padding the camera
  /// pipeline added. Returns `null` for non-YUV frames so the caller
  /// can no-op gracefully (e.g. iOS in BGRA mode if YUV420 negotiation
  /// failed).
  static Uint8List? _extractYPlane(CameraImage image) {
    if (image.planes.isEmpty) return null;
    final plane = image.planes[0];
    final w = image.width;
    final h = image.height;
    final src = plane.bytes;
    if (src.length < w * h) return null;
    final stride = plane.bytesPerRow;
    if (stride == w) return src;
    final out = Uint8List(w * h);
    for (var row = 0; row < h; row++) {
      final srcStart = row * stride;
      out.setRange(row * w, (row + 1) * w, src, srcStart);
    }
    return out;
  }

  Future<File> _cropToCardRegion(File original) async {
    final bytes = await original.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();

    const cardWidthRatio = 0.85;
    const cardAspectRatio = 1.586;
    const padding = 0.03;

    final cropW = imgW * (cardWidthRatio + padding);
    final cropH = cropW / cardAspectRatio;
    final cropX = (imgW - cropW) / 2;
    final cropY = (imgH - cropH) / 2;

    final srcRect = Rect.fromLTWH(
      cropX.clamp(0, imgW),
      cropY.clamp(0, imgH),
      cropW.clamp(0, imgW - cropX.clamp(0, imgW)),
      cropH.clamp(0, imgH - cropY.clamp(0, imgH)),
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      image,
      srcRect,
      Rect.fromLTWH(0, 0, srcRect.width, srcRect.height),
      Paint(),
    );
    final picture = recorder.endRecording();
    final cropped = await picture.toImage(
      srcRect.width.round(),
      srcRect.height.round(),
    );

    final pngBytes = await cropped.toByteData(format: ui.ImageByteFormat.png);

    image.dispose();
    cropped.dispose();

    final croppedFile = File(
      '${original.parent.path}/cropped_${original.uri.pathSegments.last}',
    );
    await croppedFile.writeAsBytes(pngBytes!.buffer.asUint8List());
    return croppedFile;
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() => _isCapturing = true);

    try {
      // package:camera requires the image stream to be stopped before
      // takePicture() on most platforms.
      await _stopQualityStream();
      final XFile photo = await _controller!.takePicture();
      final cropped = await _cropToCardRegion(File(photo.path));
      if (mounted) setState(() => _capturedImage = cropped);
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _confirmCapture() {
    if (_capturedImage != null) {
      widget.onCapture(_capturedImage!);
    }
  }

  Future<void> _retake() async {
    setState(() => _capturedImage = null);
    _prevDownscaledY = null;
    _quality.value = null;
    if (widget.qualityProbe.isEnabled) {
      await _startQualityStream();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_capturedImage != null) {
      return Scaffold(
        body: Column(
          children: [
            Expanded(child: Image.file(_capturedImage!, fit: BoxFit.contain)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _retake,
                    child: const Text('Retake'),
                  ),
                  ElevatedButton(
                    onPressed: _confirmCapture,
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          CustomPaint(painter: CardOverlayPainter(), size: Size.infinite),
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Text(
              widget.isFront
                  ? 'Place FRONT of ID card within the frame'
                  : 'Place BACK of ID card within the frame',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(blurRadius: 4, color: Colors.black)],
              ),
            ),
          ),
          Positioned(
            bottom: 130,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<QualityReport?>(
              valueListenable: _quality,
              builder: (_, report, __) => CaptureQualityIndicator(
                probe: widget.qualityProbe,
                report: report,
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: ValueListenableBuilder<QualityReport?>(
                valueListenable: _quality,
                builder: (_, report, __) {
                  final ready =
                      !widget.qualityProbe.isEnabled || (report?.allGood ?? true);
                  return FloatingActionButton(
                    onPressed: _isCapturing ? null : _takePicture,
                    backgroundColor: ready ? null : Colors.orange.shade400,
                    tooltip: ready
                        ? 'Take photo'
                        : 'Capture (quality not ideal)',
                    child: _isCapturing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Icon(Icons.camera_alt),
                  );
                },
              ),
            ),
          ),
          if (widget.onCancel != null)
            Positioned(
              top: 50,
              left: 20,
              child: IconButton(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Best-effort stop — if the stream is still running, package:camera
    // will complain on dispose. We deliberately do not `await` here
    // because dispose() is sync; the controller.dispose() below also
    // tears the stream down.
    if (_streamRunning) {
      _controller?.stopImageStream().catchError((_) {});
      _streamRunning = false;
    }
    _quality.dispose();
    _controller?.dispose();
    super.dispose();
  }
}
