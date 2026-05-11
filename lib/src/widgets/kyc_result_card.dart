import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/field_result.dart';
import '../models/verification.dart';

/// Display a [Verification] in a card layout.
class KycResultCard extends StatelessWidget {
  final Verification verification;

  const KycResultCard({super.key, required this.verification});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final passed = verification.isPassed;
    final docCheck = verification.checks.document;
    final faceMatch = verification.checks.faceMatch;
    final liveness = verification.checks.liveness;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  passed ? Icons.check_circle : Icons.cancel,
                  color: passed ? Colors.green : Colors.red,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    passed ? 'Verified' : _statusLabel(verification.status),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: passed ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            if (docCheck?.failureReason != null)
              _failureBanner(docCheck!.failureReason!),

            if (faceMatch != null) ...[
              _buildScoreRow(
                'Face match',
                faceMatch.score,
                faceMatch.passed ?? false,
              ),
              const SizedBox(height: 12),
            ],

            if (liveness != null) ...[
              Row(
                children: [
                  Icon(
                    (liveness.passed ?? false)
                        ? Icons.verified_user
                        : Icons.shield,
                    color: (liveness.passed ?? false)
                        ? Colors.green
                        : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Liveness: '
                    '${(liveness.passed ?? false) ? "Passed" : "Failed"}',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            if (verification.document?.fields != null &&
                verification.document!.fields!.isNotEmpty) ...[
              const Text(
                'Extracted fields',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._buildFieldRows(verification.document!.fields!),
            ],

            if (verification.completedAt != null) ...[
              const SizedBox(height: 16),
              Text(
                'Completed: ${verification.completedAt!.toIso8601String()}',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'rejected':
        return 'Rejected';
      case 'failed':
        return 'Failed';
      case 'in_progress':
        return 'In progress';
      default:
        return 'Verification ${status.replaceAll('_', ' ')}';
    }
  }

  Widget _failureBanner(String reason) => Container(
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: Colors.red),
        const SizedBox(width: 8),
        Expanded(
          child: Text(reason, style: const TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );

  Widget _buildScoreRow(String label, double? score, bool passed) {
    final percent = score != null
        ? '${(score * 100).toStringAsFixed(1)}%'
        : '—';
    return Row(
      children: [
        Icon(
          passed ? Icons.check_circle_outline : Icons.highlight_off,
          color: passed ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Text(
          percent,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: passed ? Colors.green : Colors.red,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildFieldRows(Map<String, FieldResult> fields) {
    final rows = <Widget>[];
    for (final entry in fields.entries) {
      final value = entry.value.normalized;
      if (value == null) continue;
      final shown = _stringify(value);
      if (shown.isEmpty) continue;
      rows.add(_buildDataRow(_formatFieldName(entry.key), shown));
    }
    return rows;
  }

  String _stringify(Object value) {
    if (value is String) return value;
    if (value is List) return value.join(', ');
    if (value is Map) {
      return value.entries.map((e) => '${e.key}=${e.value}').join(', ');
    }
    return value.toString();
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              textDirection: _isArabic(value)
                  ? TextDirection.rtl
                  : TextDirection.ltr,
            ),
          ),
        ],
      ),
    );
  }

  String _formatFieldName(String key) => key
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  bool _isArabic(String text) => RegExp(r'[؀-ۿ]').hasMatch(text);
}
