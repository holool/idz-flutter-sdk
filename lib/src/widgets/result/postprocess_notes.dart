/// Parsed view of a single `metadata.postprocess_notes` entry.
///
/// The pipeline emits opaque strings like:
///   - `name_csv_snap:first_name`
///   - `validity_window:3650d expected~3650d (issue=2020/01/01 expiry=2030/01/01)`
///   - `categories_table:merge_advisory(...)`
///
/// This module gives the result UI structured access without every
/// caller re-parsing.
sealed class PostprocessNote {
  const PostprocessNote(this.raw);

  /// The original string, untouched.
  final String raw;

  /// Parse one note. Falls back to [PostprocessNoteOther] for shapes
  /// the SDK doesn't have a typed view for yet.
  static PostprocessNote parse(String value) {
    if (value.startsWith('name_csv_snap:')) {
      final field = value.substring('name_csv_snap:'.length);
      return PostprocessNoteCsvSnap(raw: value, field: field);
    }
    if (value.startsWith('validity_window:')) {
      return PostprocessNoteValidityWindow(raw: value);
    }
    if (value.startsWith('categories:') ||
        value.startsWith('categories_table:')) {
      return PostprocessNoteCategories(raw: value);
    }
    return PostprocessNoteOther(raw: value);
  }

  /// Convenience: parse a list of raw strings, dropping blanks.
  static List<PostprocessNote> parseAll(Iterable<String> values) {
    return values.where((s) => s.isNotEmpty).map(parse).toList();
  }
}

/// `name_csv_snap:<field>` — the OCR output for `<field>` was snapped
/// to a curated CSV entry. The raw OCR was slightly off.
final class PostprocessNoteCsvSnap extends PostprocessNote {
  const PostprocessNoteCsvSnap({required String raw, required this.field})
    : super(raw);

  /// The field name that was auto-corrected (e.g. `first_name`).
  final String field;
}

/// `validity_window:Xd expected~Yd (...)` — the issue→expiry delta on
/// a driving licence differs from the legal 10-year window.
final class PostprocessNoteValidityWindow extends PostprocessNote {
  const PostprocessNoteValidityWindow({required String raw}) : super(raw);
}

/// `categories:*` / `categories_table:*` — DL categories merge advisory.
final class PostprocessNoteCategories extends PostprocessNote {
  const PostprocessNoteCategories({required String raw}) : super(raw);
}

/// Catch-all for note shapes the SDK doesn't typify yet.
final class PostprocessNoteOther extends PostprocessNote {
  const PostprocessNoteOther({required String raw}) : super(raw);
}
