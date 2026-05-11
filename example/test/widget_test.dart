import 'package:flutter_test/flutter_test.dart';

import 'package:idz_flutter_example/main.dart';

void main() {
  testWidgets('App renders with bottom navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const IdzExampleApp());

    // Verify the app title and navigation destinations are present.
    expect(find.text('Complete KYC'), findsOneWidget);
    expect(find.text('KYC + Video'), findsOneWidget);
    expect(find.text('OCR Only'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
