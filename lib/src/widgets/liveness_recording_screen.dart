import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';
import 'painters/face_overlay_painter.dart';

/// A challenge step in the liveness recording flow.
class LivenessChallenge {
  final String instruction;
  final IconData icon;
  final Duration duration;

  /// Backend challenge key (e.g. 'BLINK', 'SMILE', 'TURN_LEFT').
  /// When provided, this key is sent to the backend so it verifies
  /// against the exact challenges the user was prompted with.
  final String? backendKey;

  const LivenessChallenge({
    required this.instruction,
    required this.icon,
    required this.duration,
    this.backendKey,
  });
}

/// Default challenge sequence for liveness verification.
const List<LivenessChallenge> defaultChallenges = [
  LivenessChallenge(
    instruction: 'Look at the camera',
    icon: Icons.visibility,
    duration: Duration(seconds: 2),
    backendKey: null, // warmup, not verified
  ),
  LivenessChallenge(
    instruction: 'Blink your eyes',
    icon: Icons.remove_red_eye,
    duration: Duration(seconds: 3),
    backendKey: 'BLINK',
  ),
  LivenessChallenge(
    instruction: 'Smile',
    icon: Icons.sentiment_satisfied_alt,
    duration: Duration(seconds: 3),
    backendKey: 'SMILE',
  ),
  LivenessChallenge(
    instruction: 'Turn your head left',
    icon: Icons.arrow_back,
    duration: Duration(seconds: 3),
    backendKey: 'TURN_LEFT',
  ),
  LivenessChallenge(
    instruction: 'Turn your head right',
    icon: Icons.arrow_forward,
    duration: Duration(seconds: 3),
    backendKey: 'TURN_RIGHT',
  ),
];

/// Screen for guided liveness video recording.
///
/// Challenges are shuffled automatically before display.
class LivenessRecordingScreen extends StatefulWidget {
  final void Function(File video) onCapture;
  final VoidCallback? onCancel;
  final List<LivenessChallenge>? challenges;

  const LivenessRecordingScreen({
    super.key,
    required this.onCapture,
    this.onCancel,
    this.challenges,
  });

  @override
  State<LivenessRecordingScreen> createState() =>
      _LivenessRecordingScreenState();
}

class _LivenessRecordingScreenState extends State<LivenessRecordingScreen> {
  CameraController? _controller;
  int _currentChallengeIndex = 0;
  bool _isRecording = false;
  bool _isComplete = false;
  bool _isWarmup = false;
  int _warmupCountdown = 2;
  File? _recordedVideo;
  Timer? _challengeTimer;
  int _elapsedSeconds = 0;
  Timer? _elapsedTimer;
  Timer? _warmupTimer;
  late final List<LivenessChallenge> _challenges;

  LivenessChallenge get _currentChallenge =>
      _challenges[_currentChallengeIndex];

  @override
  void initState() {
    super.initState();
    final customChallenges = widget.challenges;
    if (customChallenges != null) {
      _challenges = List<LivenessChallenge>.from(customChallenges);
    } else {
      final source = List<LivenessChallenge>.from(defaultChallenges)..shuffle();
      _challenges = source.take(3).toList();
    }
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
    if (mounted) {
      setState(() {});
      _startRecording();
    }
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    await _controller!.startVideoRecording();
    setState(() {
      _isRecording = true;
      _isWarmup = true;
      _warmupCountdown = 2;
    });

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });

    // 2-second warmup: record clean frontal face frames before challenges
    _warmupTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _warmupCountdown--);
      if (_warmupCountdown <= 0) {
        timer.cancel();
        setState(() => _isWarmup = false);
        _advanceChallenge();
      }
    });
  }

  void _advanceChallenge() {
    _challengeTimer?.cancel();
    if (_currentChallengeIndex >= _challenges.length) {
      _stopRecording();
      return;
    }

    _challengeTimer = Timer(_currentChallenge.duration, () {
      if (mounted) {
        setState(() => _currentChallengeIndex++);
        _advanceChallenge();
      }
    });
  }

  Future<void> _stopRecording() async {
    _challengeTimer?.cancel();
    _elapsedTimer?.cancel();

    if (_controller != null && _controller!.value.isRecordingVideo) {
      final XFile video = await _controller!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _isComplete = true;
        _recordedVideo = File(video.path);
      });
    }
  }

  void _confirmRecording() {
    if (_recordedVideo != null) {
      widget.onCapture(_recordedVideo!);
    }
  }

  Future<void> _retakeRecording() async {
    setState(() {
      _currentChallengeIndex = 0;
      _isComplete = false;
      _recordedVideo = null;
      _elapsedSeconds = 0;
    });
    _startRecording();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isComplete && _recordedVideo != null) {
      return Scaffold(
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text('Recording complete (${_elapsedSeconds}s)'),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _retakeRecording,
                  child: const Text('Re-record'),
                ),
                ElevatedButton(
                  onPressed: _confirmRecording,
                  child: const Text('Confirm'),
                ),
              ],
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
          // Challenge instruction or warmup prompt
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: _isWarmup
                ? Column(
                    children: [
                      const Icon(Icons.face, color: Colors.white, size: 48),
                      const SizedBox(height: 8),
                      const Text(
                        'Look straight at the camera',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Starting in $_warmupCountdown...',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Text(
                        'Challenge ${_currentChallengeIndex + 1} of ${_challenges.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Icon(
                        _currentChallengeIndex < _challenges.length
                            ? _currentChallenge.icon
                            : Icons.check,
                        color: Colors.white,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentChallengeIndex < _challenges.length
                            ? _currentChallenge.instruction
                            : 'Done!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                        ),
                      ),
                    ],
                  ),
          ),
          // Timer
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isRecording)
                      const Icon(
                        Icons.fiber_manual_record,
                        color: Colors.white,
                        size: 12,
                      ),
                    if (_isRecording) const SizedBox(width: 8),
                    Text(
                      '${_elapsedSeconds}s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
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
    _warmupTimer?.cancel();
    _challengeTimer?.cancel();
    _elapsedTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }
}
