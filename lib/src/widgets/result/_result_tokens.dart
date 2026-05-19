import 'package:flutter/material.dart';

import '../../models/verification.dart';

/// Internal styling helpers used across the result widgets so the
/// SDK widget tree stays visually coherent without dragging in a
/// dependency on any host app's theme system.
///
/// Color choices intentionally live here (not in `IdzConfig`) — the
/// host app's `Theme` still wins, these are just sane defaults.
class ResultTokens {
  ResultTokens._();

  static const Color success = Color(0xFF1F8E5A);
  static const Color danger = Color(0xFFCE3535);
  static const Color warning = Color(0xFFD08F1B);
  static const Color info = Color(0xFF1F4FE0);
  static const Color neutral = Color(0xFF5A5A66);

  static const double sectionGap = 16;
  static const double rowGap = 8;
  static const double radius = 14;
}

/// Concrete render-time state derived from `(status, reviewState)`.
///
/// Five buckets — the four real terminal states plus the in-progress
/// case. Compute with [VerdictTone.of] so every result surface (card,
/// detail page, history row chip) lights up the same way.
enum VerdictTone {
  inProgress,
  verified,
  underReview,
  rejected,
  failed;

  static VerdictTone of(Verification v) {
    if (v.isRejected) return VerdictTone.rejected;
    if (v.isFailed) return VerdictTone.failed;
    if (v.isUnderReview) return VerdictTone.underReview;
    if (v.isPassed) return VerdictTone.verified;
    return VerdictTone.inProgress;
  }

  /// Headline color for the verdict.
  Color get color {
    switch (this) {
      case VerdictTone.inProgress:
        return ResultTokens.neutral;
      case VerdictTone.verified:
        return ResultTokens.success;
      case VerdictTone.underReview:
        return ResultTokens.warning;
      case VerdictTone.rejected:
      case VerdictTone.failed:
        return ResultTokens.danger;
    }
  }

  /// Leading icon for the verdict.
  IconData get icon {
    switch (this) {
      case VerdictTone.inProgress:
        return Icons.hourglass_top;
      case VerdictTone.verified:
        return Icons.check_circle;
      case VerdictTone.underReview:
        return Icons.hourglass_bottom;
      case VerdictTone.rejected:
        return Icons.cancel;
      case VerdictTone.failed:
        return Icons.error_outline;
    }
  }

  /// User-facing label. Deliberately neutral wording on `underReview` —
  /// the row is approved by the pipeline but a human is double-checking,
  /// so we do not show a green checkmark or the word "verified".
  String get label {
    switch (this) {
      case VerdictTone.inProgress:
        return 'Submitted — being processed';
      case VerdictTone.verified:
        return 'Verified';
      case VerdictTone.underReview:
        return 'Submitted — under review';
      case VerdictTone.rejected:
        return 'Rejected';
      case VerdictTone.failed:
        return 'Something went wrong';
    }
  }
}

/// Small status pill used by the MRZ header and check-digit chips.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.passed,
    this.icon,
  });

  final String label;
  final bool passed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = passed ? ResultTokens.success : ResultTokens.danger;
    return _Pill(
      label: label,
      color: color,
      icon: icon ?? (passed ? Icons.check : Icons.close),
    );
  }
}

/// Pill that summarises the five-quadrant verdict — drop into list rows
/// or above the result card. Color and copy come from [VerdictTone].
class VerdictChip extends StatelessWidget {
  const VerdictChip({super.key, required this.verification});

  final Verification verification;

  @override
  Widget build(BuildContext context) {
    final tone = VerdictTone.of(verification);
    return _Pill(label: tone.label, color: tone.color, icon: tone.icon);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, required this.icon});

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
