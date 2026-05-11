import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/field_result.dart';

/// Expandable card rendering the driving-licence categories table.
///
/// The wire shape is `List<Map<String, dynamic>>` under
/// `field.normalized` — one entry per licensed class. Collapsed state
/// shows a count badge; expanded state shows a tabular layout with
/// Class / Issued / Expires / Restrictions columns and a coloured chip
/// per category. Hidden entirely when the field is missing or empty —
/// the caller decides whether to render the card based on whether the
/// document type carries a categories_table at all.
class CategoriesTableCard extends StatefulWidget {
  const CategoriesTableCard({super.key, required this.field});

  final FieldResult field;

  @override
  State<CategoriesTableCard> createState() => _CategoriesTableCardState();
}

class _CategoriesTableCardState extends State<CategoriesTableCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final rows = _parse(widget.field.normalized);
    if (rows.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.local_taxi, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Categories Table',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 8),
                    _CountBadge(count: rows.length),
                    const Spacer(),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[
              const Divider(height: 1),
              const SizedBox(height: 8),
              _CategoriesGrid(rows: rows),
            ],
          ],
        ),
      ),
    );
  }

  static List<_CategoryRow> _parse(Object? normalized) {
    if (normalized is! List) return const [];
    final out = <_CategoryRow>[];
    for (final entry in normalized) {
      if (entry is Map) {
        final m = entry.cast<dynamic, dynamic>();
        final cat = m['category']?.toString();
        if (cat == null || cat.isEmpty) continue;
        out.add(_CategoryRow(
          category: cat,
          issueDate: m['issue_date']?.toString(),
          expiryDate: m['expiry_date']?.toString(),
          restrictions: m['restrictions']?.toString(),
        ));
      }
    }
    return out;
  }
}

class _CategoryRow {
  const _CategoryRow({
    required this.category,
    this.issueDate,
    this.expiryDate,
    this.restrictions,
  });
  final String category;
  final String? issueDate;
  final String? expiryDate;
  final String? restrictions;
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = count == 1 ? '1 category' : '$count categories';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _CategoriesGrid extends StatelessWidget {
  const _CategoriesGrid({required this.rows});
  final List<_CategoryRow> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width - 64,
        ),
        child: DataTable(
          columnSpacing: 18,
          headingRowHeight: 32,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 52,
          headingTextStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
          ),
          columns: const [
            DataColumn(label: Text('CLASS')),
            DataColumn(label: Text('ISSUED')),
            DataColumn(label: Text('EXPIRES')),
            DataColumn(label: Text('RESTRICTIONS')),
          ],
          rows: [
            for (final r in rows)
              DataRow(cells: [
                DataCell(_CategoryChip(category: r.category)),
                DataCell(Text(_formatDate(r.issueDate))),
                DataCell(Text(_formatDate(r.expiryDate))),
                DataCell(Text(
                  (r.restrictions == null || r.restrictions!.isEmpty)
                      ? '—'
                      : r.restrictions!,
                  style: const TextStyle(fontFamily: 'monospace'),
                )),
              ]),
          ],
        ),
      ),
    );
  }

  static final _formatter = DateFormat('dd MMM yyyy');
  static final _parser = DateFormat('yyyy/MM/dd');

  static String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      return _formatter.format(_parser.parseStrict(raw));
    } catch (_) {
      return raw;
    }
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});
  final String category;

  // Vehicle-class colour map. Picked for legibility on a dark surface;
  // matches the visual rhythm of European DL category pictograms
  // (motorcycle / car / lorry / bus / tractor / trailer endorsement).
  static const _palette = <String, Color>{
    'A': Color(0xFFE89B3C),     // motorcycle — amber
    'A1': Color(0xFFE89B3C),
    'A2': Color(0xFFE89B3C),
    'B': Color(0xFF4D9DE0),     // car — blue
    'B(E)': Color(0xFF2EB1A6),  // car + trailer — teal
    'C1': Color(0xFFE05B5B),    // light truck — red
    'C1(E)': Color(0xFFE05B5B),
    'C': Color(0xFFE05B5B),     // heavy truck — red
    'C(E)': Color(0xFFE05B5B),
    'D': Color(0xFF9B6CE0),     // bus — purple
    'D(E)': Color(0xFF9B6CE0),
    'F': Color(0xFF5BBF5B),     // tractor / ag — green
  };

  @override
  Widget build(BuildContext context) {
    final colour = _palette[category] ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: 44,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.16),
        border: Border.all(color: colour.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category,
        style: TextStyle(
          color: colour,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
