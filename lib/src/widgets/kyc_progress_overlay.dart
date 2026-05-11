import 'package:flutter/material.dart';
import 'dart:async';

/// A progress stage in the KYC processing overlay.
class ProgressStage {
  final String label;
  final IconData icon;
  final Duration minDuration;

  const ProgressStage({
    required this.label,
    required this.icon,
    this.minDuration = const Duration(seconds: 2),
  });
}

/// Default processing stages shown during KYC API calls.
const List<ProgressStage> defaultStages = [
  ProgressStage(label: 'Uploading documents...', icon: Icons.cloud_upload),
  ProgressStage(label: 'Analyzing document...', icon: Icons.document_scanner),
  ProgressStage(label: 'Verifying identity...', icon: Icons.face),
  ProgressStage(
    label: 'Processing results...',
    icon: Icons.check_circle_outline,
  ),
];

/// Full-screen semi-transparent overlay showing fake multi-stage progress
/// during KYC API calls.
class KycProgressOverlay extends StatefulWidget {
  /// The future to track. When it completes, the overlay will fast-forward
  /// to completion and dismiss.
  final Future<void>? future;

  /// Callback when the overlay finishes (either naturally or via future).
  final VoidCallback? onComplete;

  /// Custom stages to show. Defaults to [defaultStages].
  final List<ProgressStage>? stages;

  /// Whether to show a cancel button.
  final VoidCallback? onCancel;

  const KycProgressOverlay({
    super.key,
    this.future,
    this.onComplete,
    this.stages,
    this.onCancel,
  });

  @override
  State<KycProgressOverlay> createState() => _KycProgressOverlayState();
}

class _KycProgressOverlayState extends State<KycProgressOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStageIndex = 0;
  Timer? _stageTimer;
  late final List<ProgressStage> _stages;
  late final AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _stages = widget.stages ?? defaultStages;

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _progressAnimation = Tween<double>(begin: 0, end: 1 / _stages.length)
        .animate(
          CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
        );

    _progressController.forward();
    _advanceStage();
    _trackFuture();
  }

  void _trackFuture() {
    widget.future
        ?.then((_) {
          if (mounted) {
            _stageTimer?.cancel();
            _completeAll();
          }
        })
        .catchError((_) {
          if (mounted) {
            _stageTimer?.cancel();
            _completeAll();
          }
        });
  }

  void _advanceStage() {
    if (_currentStageIndex >= _stages.length) {
      _completeAll();
      return;
    }

    _stageTimer = Timer(_stages[_currentStageIndex].minDuration, () {
      if (mounted) {
        setState(() {
          _currentStageIndex++;
        });

        final progress = _currentStageIndex / _stages.length;
        _progressAnimation =
            Tween<double>(
              begin: _progressAnimation.value,
              end: progress.clamp(0.0, 1.0),
            ).animate(
              CurvedAnimation(
                parent: _progressController..reset(),
                curve: Curves.easeOut,
              ),
            );
        _progressController.forward();

        _advanceStage();
      }
    });
  }

  void _completeAll() {
    _progressAnimation =
        Tween<double>(begin: _progressAnimation.value, end: 1.0).animate(
          CurvedAnimation(
            parent: _progressController..reset(),
            curve: Curves.easeOut,
          ),
        );
    _progressController.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  ProgressStage get _currentStage => _currentStageIndex < _stages.length
      ? _stages[_currentStageIndex]
      : _stages.last;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_currentStage.icon, size: 64, color: Colors.white),
            const SizedBox(height: 24),
            Text(
              _currentStage.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return LinearProgressIndicator(
                    value: _progressAnimation.value,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Step ${(_currentStageIndex + 1).clamp(1, _stages.length)} of ${_stages.length}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            if (widget.onCancel != null) ...[
              const SizedBox(height: 32),
              TextButton(
                onPressed: widget.onCancel,
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }
}
