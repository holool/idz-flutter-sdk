import 'package:flutter_test/flutter_test.dart';
import 'package:idz_flutter/idz_flutter.dart';

void main() {
  group('PostprocessNote.parse', () {
    test('typed views for the documented patterns', () {
      final csv = PostprocessNote.parse('name_csv_snap:first_name');
      expect(csv, isA<PostprocessNoteCsvSnap>());
      expect((csv as PostprocessNoteCsvSnap).field, 'first_name');

      final win = PostprocessNote.parse(
        'validity_window:3650d expected~3650d (issue=2020/01/01 expiry=2030/01/01)',
      );
      expect(win, isA<PostprocessNoteValidityWindow>());

      final cat = PostprocessNote.parse('categories:merge_advisory(...)');
      expect(cat, isA<PostprocessNoteCategories>());

      final cat2 = PostprocessNote.parse(
        'categories_table:merge_advisory(...)',
      );
      expect(cat2, isA<PostprocessNoteCategories>());

      final fallback = PostprocessNote.parse('something_unknown:hello');
      expect(fallback, isA<PostprocessNoteOther>());
      expect(fallback.raw, 'something_unknown:hello');
    });

    test('parseAll drops blank entries', () {
      final notes = PostprocessNote.parseAll([
        '',
        'name_csv_snap:last_name',
        '',
        'validity_window:1d',
      ]);
      expect(notes.length, 2);
      expect(notes.first, isA<PostprocessNoteCsvSnap>());
      expect(notes.last, isA<PostprocessNoteValidityWindow>());
    });
  });
}
