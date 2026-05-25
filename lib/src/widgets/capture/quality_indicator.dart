import 'package:flutter/material.dart';

import 'capture_quality_probe.dart';

/// Bottom-of-screen pill strip — one chip per active probe, green
/// when its check passes and red when it fails.
///
/// Used by [DocumentCaptureScreen] to give the user a live "ready to
/// shoot" affordance. The strip renders nothing when [report] is
/// `null` or [probe] is the disabled factory, so it's safe to drop
/// in unconditionally.
class CaptureQualityIndicator extends StatelessWidget {
  final CaptureQualityProbe probe;
  final QualityReport? report;

  const CaptureQualityIndicator({
    super.key,
    required this.probe,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    if (!probe.isEnabled || report == null) {
      return const SizedBox.shrink();
    }
    final chips = <Widget>[
      if (probe.blurMinVariance != null)
        _QualityChip(label: 'Sharp', passed: report!.sharp),
      if (probe.glareMaxFraction != null)
        _QualityChip(label: 'No glare', passed: report!.noGlare),
      if (probe.steadinessMaxDelta != null)
        _QualityChip(label: 'Hold steady', passed: report!.steady),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: chips,
      ),
    );
  }
}

class _QualityChip extends StatelessWidget {
  final String label;
  final bool passed;

  const _QualityChip({required this.label, required this.passed});

  @override
  Widget build(BuildContext context) {
    final color = passed
        ? Colors.green.shade400
        : Colors.orange.shade400;
    final icon = passed ? Icons.check_circle : Icons.error_outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
