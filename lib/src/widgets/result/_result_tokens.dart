import 'package:flutter/material.dart';

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

  static const double sectionGap = 16;
  static const double rowGap = 8;
  static const double radius = 14;
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
          Icon(
            icon ?? (passed ? Icons.check : Icons.close),
            size: 14,
            color: color,
          ),
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
