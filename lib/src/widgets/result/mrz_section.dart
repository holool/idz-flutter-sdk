import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/field_result.dart';
import '_result_tokens.dart';

/// Collapsible MRZ card with parsed grid + per-row pass/fail icons.
///
/// Renders nothing if [field] doesn't carry an MRZ object. Gate with
/// `field.asMrz` at the call site.
///
/// Design choices:
///   - The Composite check chip is intentionally dropped from the
///     summary. It fails on a sizeable fraction of Algerian cards
///     because OCR drops filler characters in line 2 — useful as a
///     diagnostic, noisy as a top-level signal.
///   - Per-row check icons (Document #, Date of birth, Expiry) live
///     inline on the kv rows so a glance at a field tells you whether
///     to trust it. Names, sex, nationality, and type don't have ICAO
///     check digits, so they render without icons.
class MrzSection extends StatefulWidget {
  const MrzSection({super.key, required this.field});

  final FieldResult field;

  @override
  State<MrzSection> createState() => _MrzSectionState();
}

class _MrzSectionState extends State<MrzSection> {
  bool _showRaw = false;

  @override
  Widget build(BuildContext context) {
    final mrz = widget.field.asMrz;
    if (mrz == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final passed = mrz.valid ?? false;
    final hasViz = (mrz.fieldsFromViz ?? const []).isNotEmpty;
    // Three header states:
    //   - valid==true            → green "Valid"
    //   - failed + any VIZ fill  → yellow "Recovered" (data trustworthy
    //     even though ICAO failed)
    //   - failed + no VIZ fill   → red "Invalid"
    final headerColor = passed
        ? ResultTokens.success
        : hasViz
            ? ResultTokens.warning
            : ResultTokens.danger;
    final headerLabel = passed
        ? 'Valid'
        : hasViz
            ? 'Recovered'
            : 'Invalid';
    final checks = mrz.checks;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.qr_code_2, color: scheme.primary),
                const SizedBox(width: 8),
                Text('MRZ', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                _StatusBadge(label: headerLabel, color: headerColor),
              ],
            ),
            const SizedBox(height: 12),
            _grid([
              if (mrz.documentNumber != null)
                _kv(
                  'Document #',
                  mrz.documentNumber!,
                  check: checks?.documentNumber,
                  fromViz: mrz.isFromViz('document_number'),
                ),
              if (mrz.dateOfBirth != null)
                _kv(
                  'Date of birth',
                  _formatDate(mrz.dateOfBirth!),
                  check: checks?.dateOfBirth,
                  fromViz: mrz.isFromViz('date_of_birth'),
                ),
              if (mrz.expiryDate != null)
                _kv(
                  'Expiry',
                  _formatDate(mrz.expiryDate!),
                  check: checks?.expiryDate,
                  fromViz: mrz.isFromViz('expiry_date'),
                ),
              if (mrz.sex != null)
                _kv('Sex', mrz.sex!, fromViz: mrz.isFromViz('sex')),
              if (mrz.nationality != null) _kv('Nationality', mrz.nationality!),
              if (mrz.surname != null)
                _kv('Surname', mrz.surname!, fromViz: mrz.isFromViz('surname')),
              if (mrz.givenNames != null)
                _kv(
                  'Given names',
                  mrz.givenNames!,
                  fromViz: mrz.isFromViz('given_names'),
                ),
              if (mrz.documentType != null) _kv('Type', mrz.documentType!),
            ]),
            const SizedBox(height: 8),
            if (widget.field.raw != null)
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  alignment: Alignment.centerLeft,
                ),
                icon: Icon(_showRaw ? Icons.expand_less : Icons.expand_more),
                label: Text(_showRaw ? 'Hide raw MRZ' : 'Show raw MRZ'),
                onPressed: () => setState(() => _showRaw = !_showRaw),
              ),
            if (_showRaw)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  widget.field.raw?.toString() ?? '',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _grid(List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          rows[i],
          if (i < rows.length - 1) const Divider(height: 1),
        ],
      ],
    );
  }

  Widget _kv(
    String key,
    String value, {
    bool? check,
    bool fromViz = false,
  }) {
    // `fromViz` wins over `check` — when the server replaced the MRZ
    // value from the front-side VIZ, the displayed value is correct
    // even though the MRZ check digit failed. Show a blue info icon
    // ("filled from face") instead of a red ✗ so the user doesn't
    // think the data is wrong.
    final Widget? trailing = fromViz
        ? const _FromVizIcon()
        : check == null
            ? null
            : _CheckIcon(passed: check);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              key,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing,
          ],
        ],
      ),
    );
  }

  static final _formatter = DateFormat('dd MMM yyyy');
  static final _parser = DateFormat('yyyy/MM/dd');

  static String _formatDate(String raw) {
    if (raw.isEmpty) return raw;
    try {
      return _formatter.format(_parser.parseStrict(raw));
    } catch (_) {
      return raw;
    }
  }
}


class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}


/// "Filled from front-side OCR" indicator. Used in place of the red ✗
/// check icon when the server replaced the MRZ value via VIZ fallback
/// — the displayed value is trustworthy even though the ICAO check
/// failed.
class _FromVizIcon extends StatelessWidget {
  const _FromVizIcon();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Recovered from the front-side OCR. The MRZ data for this '
          'field was damaged, but the value comes from a separate, '
          'independently-verified read of the same field.',
      child: Icon(
        Icons.swap_horiz_rounded,
        size: 16,
        color: ResultTokens.info,
      ),
    );
  }
}


class _CheckIcon extends StatelessWidget {
  const _CheckIcon({required this.passed});
  final bool passed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: passed
          ? 'ICAO 9303 check digit matches'
          : 'ICAO 9303 check digit failed — value may be unreliable',
      child: Icon(
        passed ? Icons.check_circle : Icons.cancel,
        size: 16,
        color: passed ? ResultTokens.success : ResultTokens.danger,
      ),
    );
  }
}
