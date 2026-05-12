import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/api_error.dart';
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

            // Banner order: top-level verification error first, then
            // per-check errors. Skip both if user_message is empty
            // (dev-only codes shouldn't reach end users).
            if (verification.error?.hasUserContent == true)
              _failureBannerFromError(verification.error!),
            if (docCheck?.error?.hasUserContent == true)
              _failureBannerFromError(docCheck!.error!)
            else if (docCheck?.failureReason != null &&
                verification.error == null)
              _failureBanner(docCheck!.failureReason!),
            if (faceMatch?.error?.hasUserContent == true)
              _failureBannerFromError(faceMatch!.error!),
            if (liveness?.error?.hasUserContent == true)
              _failureBannerFromError(liveness!.error!),

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

  /// Banner driven by the structured ApiError. Renders user_message
  /// + a small chip describing the suggested user_action (e.g.
  /// "Retake document"). Falls back to the legacy [_failureBanner]
  /// for the message-only case.
  Widget _failureBannerFromError(ApiError error) {
    final actionLabel = _userActionLabel(error.userAction);
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  error.userMessage,
                  style: const TextStyle(color: Colors.red),
                ),
                if (actionLabel != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      actionLabel,
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Default English copy for each [UserAction]. Apps that need
  /// localised CTAs should override this by reading
  /// `verification.checks.*.error.userAction` themselves and looking
  /// up the localised string. Returns null for [UserAction.none].
  String? _userActionLabel(UserAction action) {
    switch (action) {
      case UserAction.retakeDocument:
        return 'Retake document';
      case UserAction.retakeSelfie:
        return 'Retake selfie';
      case UserAction.retakeLiveness:
        return 'Retake liveness video';
      case UserAction.improveImageQuality:
        return 'Improve image quality';
      case UserAction.waitAndRetry:
        return 'Try again in a moment';
      case UserAction.contactSupport:
        return 'Contact support';
      case UserAction.none:
        return null;
    }
  }

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
