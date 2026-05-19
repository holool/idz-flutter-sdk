import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/api_error.dart';
import '../models/field_result.dart';
import '../models/verification.dart';
import 'result/_result_tokens.dart';

/// Display a [Verification] in a card layout.
///
/// Renders one of five visual states keyed off `(status, reviewState)`:
///
///   - `in_progress`             — neutral, no checkmark, "being processed".
///   - `completed` + no review   — green "Verified".
///   - `completed` + `pending`   — amber "Submitted — under review"
///                                 (no green checkmark — verdict pending).
///   - `rejected`                — red headline + the server's
///                                 [ApiError.userMessage] and an action
///                                 button derived from [ApiError.userAction].
///   - `failed`                  — red headline; "Try again" only when
///                                 the error envelope says
///                                 [ApiError.retryable] is true.
///
/// The host app handles navigation for the action button via [onAction].
/// Pass `null` to omit the button entirely.
class KycResultCard extends StatelessWidget {
  final Verification verification;
  final void Function(UserAction action)? onAction;

  const KycResultCard({super.key, required this.verification, this.onAction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = VerdictTone.of(verification);
    final primaryError = _primaryError();

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
                Icon(tone.icon, color: tone.color, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tone.label,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: tone.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            if (primaryError != null) ...[
              _errorBanner(context, primaryError),
              const SizedBox(height: 12),
            ] else if (tone == VerdictTone.rejected ||
                tone == VerdictTone.failed) ...[
              // Rejected/failed without a structured ApiError — fall back
              // to the legacy `failure_reason` string from the document
              // check. Never surface developer_message.
              if (verification.checks.document?.failureReason != null)
                _failureBanner(verification.checks.document!.failureReason!),
            ],

            if (tone == VerdictTone.verified || tone == VerdictTone.underReview)
              ..._buildPostVerdictBody(context, theme),

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

  /// Pick the first user-facing structured error: top-level first, then
  /// per-check (document → face match → liveness). Skips dev-only codes
  /// whose `user_message` is empty.
  ApiError? _primaryError() {
    final top = verification.error;
    if (top != null && top.hasUserContent) return top;
    final doc = verification.checks.document?.error;
    if (doc != null && doc.hasUserContent) return doc;
    final face = verification.checks.faceMatch?.error;
    if (face != null && face.hasUserContent) return face;
    final liveness = verification.checks.liveness?.error;
    if (liveness != null && liveness.hasUserContent) return liveness;
    return null;
  }

  List<Widget> _buildPostVerdictBody(BuildContext context, ThemeData theme) {
    final faceMatch = verification.checks.faceMatch;
    final liveness = verification.checks.liveness;
    final fields = verification.document?.fields;
    return <Widget>[
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
              (liveness.passed ?? false) ? Icons.verified_user : Icons.shield,
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
      if (fields != null && fields.isNotEmpty) ...[
        const Text(
          'Extracted fields',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._buildFieldRows(fields),
      ],
    ];
  }

  Widget _failureBanner(String reason) => Container(
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(
      color: ResultTokens.danger.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(ResultTokens.radius),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: ResultTokens.danger),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            reason,
            style: const TextStyle(color: ResultTokens.danger),
          ),
        ),
      ],
    ),
  );

  Widget _errorBanner(BuildContext context, ApiError error) {
    final actionLabel = _actionLabel(error.userAction);
    final showRetry = error.retryable;
    final showAction = actionLabel != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ResultTokens.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ResultTokens.radius),
        border: Border.all(color: ResultTokens.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: ResultTokens.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  error.userMessage,
                  style: const TextStyle(color: ResultTokens.danger),
                ),
              ),
            ],
          ),
          if (showAction || showRetry) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (showAction)
                  FilledButton(
                    onPressed: onAction == null
                        ? null
                        : () => onAction!(error.userAction),
                    child: Text(actionLabel),
                  ),
                if (showAction && showRetry) const SizedBox(width: 8),
                if (showRetry)
                  OutlinedButton(
                    onPressed: onAction == null
                        ? null
                        : () => onAction!(UserAction.waitAndRetry),
                    child: const Text('Try again'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Map a server-suggested action to a button label. Returning null
  /// suppresses the primary action button — used for actions that the
  /// card handles via the dedicated "Try again" button (`retry`,
  /// `waitAndRetry`) and for [UserAction.none].
  String? _actionLabel(UserAction action) {
    switch (action) {
      case UserAction.retakeDocument:
        return 'Retake ID';
      case UserAction.retakeSelfie:
        return 'Retake selfie';
      case UserAction.retakeLiveness:
        return 'Retake liveness';
      case UserAction.improveImageQuality:
        return 'Try a clearer photo';
      case UserAction.contactSupport:
        return 'Contact support';
      case UserAction.retry:
      case UserAction.waitAndRetry:
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
