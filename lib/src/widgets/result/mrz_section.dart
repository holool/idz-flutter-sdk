import 'package:flutter/material.dart';

import '../../models/field_result.dart';
import '_result_tokens.dart';

/// Collapsible MRZ card with parsed grid + per-field check chips.
///
/// Renders nothing if [field] doesn't carry an MRZ object. Use
/// [field.asMrz] to gate the call site.
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
    final headerColor = passed ? ResultTokens.success : ResultTokens.danger;

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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: headerColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    passed ? 'MRZ verified' : 'MRZ invalid',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: headerColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Parsed grid.
            _grid([
              if (mrz.documentNumber != null)
                _kv('Document #', mrz.documentNumber!),
              if (mrz.dateOfBirth != null)
                _kv('Date of birth', mrz.dateOfBirth!),
              if (mrz.expiryDate != null) _kv('Expiry', mrz.expiryDate!),
              if (mrz.sex != null) _kv('Sex', mrz.sex!),
              if (mrz.nationality != null) _kv('Nationality', mrz.nationality!),
              if (mrz.surname != null) _kv('Surname', mrz.surname!),
              if (mrz.givenNames != null) _kv('Given names', mrz.givenNames!),
              if (mrz.documentType != null) _kv('Type', mrz.documentType!),
            ]),
            if (mrz.checks != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (mrz.checks!.documentNumber != null)
                    StatusChip(
                      label: 'Doc #',
                      passed: mrz.checks!.documentNumber!,
                    ),
                  if (mrz.checks!.dateOfBirth != null)
                    StatusChip(label: 'DOB', passed: mrz.checks!.dateOfBirth!),
                  if (mrz.checks!.expiryDate != null)
                    StatusChip(
                      label: 'Expiry',
                      passed: mrz.checks!.expiryDate!,
                    ),
                  if (mrz.checks!.composite != null)
                    StatusChip(
                      label: 'Composite',
                      passed: mrz.checks!.composite!,
                    ),
                ],
              ),
            ],
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

  Widget _kv(String key, String value) {
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
        ],
      ),
    );
  }
}
