import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'painters/face_overlay_painter.dart';

/// Screen for capturing a selfie using the front camera.
class SelfieCaptureScreen extends StatefulWidget {
  final void Function(File image) onCapture;
  final VoidCallback? onCancel;

  const SelfieCaptureScreen({
    super.key,
    required this.onCapture,
    this.onCancel,
  });

  @override
  State<SelfieCaptureScreen> createState() => _SelfieCaptureScreenState();
}

class _SelfieCaptureScreenState extends State<SelfieCaptureScreen> {
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
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() => _isCapturing = true);

    try {
      final XFile photo = await _controller!.takePicture();
      setState(() => _capturedImage = File(photo.path));
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
          CustomPaint(painter: FaceOverlayPainter(), size: Size.infinite),
          const Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Text(
              'Position your face within the oval',
              textAlign: TextAlign.center,
              style: TextStyle(
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
