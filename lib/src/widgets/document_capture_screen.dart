import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'painters/card_overlay_painter.dart';

class DocumentCaptureScreen extends StatefulWidget {
  final bool isFront;
  final void Function(File image) onCapture;
  final VoidCallback? onCancel;

  const DocumentCaptureScreen({
    super.key,
    required this.isFront,
    required this.onCapture,
    this.onCancel,
  });

  @override
  State<DocumentCaptureScreen> createState() => _DocumentCaptureScreenState();
}

class _DocumentCaptureScreenState extends State<DocumentCaptureScreen> {
  CameraController? _controller;
  bool _isCapturing = false;
  File? _capturedImage;

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
    );

    await _controller!.initialize();
    if (mounted) setState(() {});
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
      final XFile photo = await _controller!.takePicture();
      final cropped = await _cropToCardRegion(File(photo.path));
      setState(() => _capturedImage = cropped);
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  void _confirmCapture() {
    if (_capturedImage != null) {
      widget.onCapture(_capturedImage!);
    }
  }

  void _retake() {
    setState(() => _capturedImage = null);
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
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                onPressed: _isCapturing ? null : _takePicture,
                child: _isCapturing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.camera_alt),
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
    _controller?.dispose();
    super.dispose();
  }
}
