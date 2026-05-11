import 'package:flutter/material.dart';

import '../../models/field_result.dart';
import '../../models/verification.dart';
import '_result_tokens.dart';
import 'categories_table_card.dart';
import 'mrz_section.dart';
import 'postprocess_notes.dart';

/// Fields tab — table layout for OCR fields, plus a separate MRZ card
/// and any pipeline hints surfaced via `metadata.postprocess_notes`.
class FieldsTab extends StatelessWidget {
  const FieldsTab({super.key, required this.verification});

  final Verification verification;

  @override
  Widget build(BuildContext context) {
    final fields =
        verification.document?.fields ?? const <String, FieldResult>{};
    final notes = PostprocessNote.parseAll(verification.postprocessNotes);

    final mrzField = fields['mrz'];
    final categoriesField = fields['categories_table'];
    final hasCategoriesRows = _hasCategoriesRows(categoriesField);
    final orderedNonMrz = _orderedFields(fields, hasCategoriesRows);

    final csvSnapFields = notes
        .whereType<PostprocessNoteCsvSnap>()
        .map((n) => n.field)
        .toSet();

    final disagreements = _disagreements(fields, mrzField?.asMrz);

    final validityNote = notes
        .whereType<PostprocessNoteValidityWindow>()
        .firstOrNull;
    final categoriesNotes = notes
        .whereType<PostprocessNoteCategories>()
        .toList();

    return ListView(
      padding: const EdgeInsets.all(ResultTokens.sectionGap),
      children: [
        if (validityNote != null) _ValidityBanner(note: validityNote),
        if (validityNote != null)
          const SizedBox(height: ResultTokens.sectionGap),
        if (orderedNonMrz.isNotEmpty)
          _FieldsTable(
            entries: orderedNonMrz,
            csvSnapFields: csvSnapFields,
            disagreements: disagreements,
          ),
        if (mrzField != null) ...[
          const SizedBox(height: ResultTokens.sectionGap),
          MrzSection(field: mrzField),
        ],
        if (categoriesField != null && hasCategoriesRows) ...[
          const SizedBox(height: ResultTokens.sectionGap),
          CategoriesTableCard(field: categoriesField),
        ],
        for (final note in categoriesNotes) ...[
          const SizedBox(height: ResultTokens.rowGap),
          _CategoriesHint(note: note),
        ],
        if (orderedNonMrz.isEmpty && mrzField == null) const _EmptyFields(),
      ],
    );
  }

  /// True iff `field.normalized` is a non-empty list (the wire shape
  /// for a populated DL categories table). False for IDs (the field
  /// isn't present at all) and for DL responses where the back-side
  /// table parse turned up empty.
  static bool _hasCategoriesRows(FieldResult? field) {
    if (field == null) return false;
    final v = field.normalized;
    return v is List && v.isNotEmpty;
  }

  static List<MapEntry<String, FieldResult>> _orderedFields(
    Map<String, FieldResult> fields,
    bool hasCategoriesRows,
  ) {
    // Keep MRZ out — it's its own card. Same for categories_table when
    // it has rows — the dedicated CategoriesTableCard renders it. When
    // the table is empty (ID docs, or a DL with a missed parse) leave
    // it in the table so the user sees the field with an empty value
    // rather than nothing.
    final entries = fields.entries.where((e) {
      if (e.key == 'mrz') return false;
      if (e.key == 'categories_table' && hasCategoriesRows) return false;
      return true;
    }).toList();
    // Stable order: front fields first, then back, ties keep API order.
    int rank(MapEntry<String, FieldResult> e) {
      switch (e.value.side) {
        case 'front':
          return 0;
        case 'back':
          return 1;
        default:
          return 2;
      }
    }

    entries.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : 0;
    });
    return entries;
  }

  /// Returns the set of field names that disagree with the MRZ AND
  /// whose corresponding MRZ check passed (so MRZ is the trusted side).
  /// We only badge fields where the MRZ side is trustworthy — when the
  /// MRZ check failed, both sides are suspect and no badge is shown.
  static Set<String> _disagreements(
    Map<String, FieldResult> fields,
    MrzNormalized? mrz,
  ) {
    if (mrz == null) return const <String>{};
    final out = <String>{};
    void check(String fieldName, String? mrzValue, bool? mrzPassed) {
      if (mrzValue == null || mrzPassed != true) return;
      final f = fields[fieldName];
      final ocr = f?.asString;
      if (ocr == null) return;
      if (_normalize(ocr) != _normalize(mrzValue)) {
        out.add(fieldName);
      }
    }

    check('date_of_birth', mrz.dateOfBirth, mrz.checks?.dateOfBirth);
    check('expiry_date', mrz.expiryDate, mrz.checks?.expiryDate);
    check('license_number', mrz.documentNumber, mrz.checks?.documentNumber);
    check('id_number', mrz.documentNumber, mrz.checks?.documentNumber);
    check('card_number', mrz.documentNumber, mrz.checks?.documentNumber);
    check('last_name_fr', mrz.surname, mrz.checks?.composite);
    check('first_name_fr', mrz.givenNames, mrz.checks?.composite);
    check('sex', mrz.sex, mrz.checks?.composite);
    return out;
  }

  static String _normalize(String s) {
    return s.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

class _FieldsTable extends StatelessWidget {
  const _FieldsTable({
    required this.entries,
    required this.csvSnapFields,
    required this.disagreements,
  });

  final List<MapEntry<String, FieldResult>> entries;
  final Set<String> csvSnapFields;
  final Set<String> disagreements;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 32,
          ),
          child: DataTable(
            columnSpacing: 16,
            headingRowHeight: 36,
            dataRowMinHeight: 40,
            dataRowMaxHeight: 64,
            headingTextStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
            ),
            columns: const [
              DataColumn(label: Text('FIELD')),
              DataColumn(label: Text('VALUE')),
              DataColumn(label: Text('SIDE')),
              DataColumn(label: Text('VALID')),
            ],
            rows: [
              for (final entry in entries)
                DataRow(
                  cells: [
                    DataCell(
                      _FieldNameCell(
                        name: entry.key,
                        autoCorrected: csvSnapFields.contains(entry.key),
                        mrzDisagrees: disagreements.contains(entry.key),
                        lowQuality: entry.value.lowQualityIssue,
                      ),
                    ),
                    DataCell(_ValueCell(field: entry.value)),
                    DataCell(Text(_sideLabel(entry.value.side))),
                    DataCell(_ValidityCell(valid: entry.value.valid)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _sideLabel(String? side) {
    switch (side) {
      case 'front':
        return 'Front';
      case 'back':
        return 'Back';
      default:
        return '—';
    }
  }
}

class _FieldNameCell extends StatelessWidget {
  const _FieldNameCell({
    required this.name,
    required this.autoCorrected,
    required this.mrzDisagrees,
    this.lowQuality,
  });

  final String name;
  final bool autoCorrected;
  final bool mrzDisagrees;
  final FieldIssue? lowQuality;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _humanise(name),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (autoCorrected) ...[
          const SizedBox(width: 6),
          Tooltip(
            message:
                'Auto-corrected: the OCR value was snapped to a curated CSV entry.',
            child: Icon(
              Icons.auto_fix_high,
              size: 14,
              color: ResultTokens.info,
            ),
          ),
        ],
        if (lowQuality != null) ...[
          const SizedBox(width: 6),
          _LowQualityChip(issue: lowQuality!),
        ],
        if (mrzDisagrees) ...[
          const SizedBox(width: 6),
          Tooltip(
            message:
                'This field disagrees with the MRZ. The MRZ check passed, so '
                'the MRZ value is more likely correct.',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: ResultTokens.warning.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'MRZ disagrees',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: ResultTokens.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _humanise(String snake) {
    return snake
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

class _LowQualityChip extends StatelessWidget {
  const _LowQualityChip({required this.issue});

  final FieldIssue issue;

  @override
  Widget build(BuildContext context) {
    // Prefer the API's pre-formatted message — it already embeds the
    // confidence percentage and any context the server wants to surface.
    // Fall back to a generic blurb only when message is empty.
    final tooltipMessage = issue.message.isNotEmpty
        ? issue.message
        : 'OCR confidence below the warning threshold for this field — '
              'verify the value before trusting it.';
    return Tooltip(
      message: tooltipMessage,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: ResultTokens.warning.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 12,
              color: ResultTokens.warning,
            ),
            const SizedBox(width: 3),
            Text(
              'Low quality',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: ResultTokens.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _ValueCell extends StatelessWidget {
  const _ValueCell({required this.field});

  final FieldResult field;

  @override
  Widget build(BuildContext context) {
    final list = field.asStringList;
    if (list != null) {
      // Categories etc. — chip layout fits a row.
      return Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final v in list)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                v,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      );
    }
    final value = field.asString ?? field.raw?.toString() ?? '—';
    final isArabic = _looksArabic(value);
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  bool _looksArabic(String s) {
    return s.runes.any((r) => r >= 0x0600 && r <= 0x06FF);
  }
}

class _ValidityCell extends StatelessWidget {
  const _ValidityCell({required this.valid});

  final bool? valid;

  @override
  Widget build(BuildContext context) {
    if (valid == null) {
      return Icon(
        Icons.help_outline,
        size: 18,
        color: Theme.of(context).colorScheme.outline,
      );
    }
    return Icon(
      valid! ? Icons.check_circle : Icons.cancel,
      size: 18,
      color: valid! ? ResultTokens.success : ResultTokens.danger,
    );
  }
}

class _ValidityBanner extends StatelessWidget {
  const _ValidityBanner({required this.note});

  final PostprocessNoteValidityWindow note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ResultTokens.warning.withValues(alpha: 0.08),
        border: Border.all(color: ResultTokens.warning.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(ResultTokens.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: ResultTokens.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Issue → expiry window is unusual',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: ResultTokens.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  note.raw,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoriesHint extends StatelessWidget {
  const _CategoriesHint({required this.note});

  final PostprocessNoteCategories note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ResultTokens.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: ResultTokens.info, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              note.raw,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFields extends StatelessWidget {
  const _EmptyFields();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          'No fields extracted yet.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
