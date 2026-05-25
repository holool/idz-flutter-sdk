import 'package:flutter_test/flutter_test.dart';

import 'package:idz_flutter_example/main.dart';

void main() {
  testWidgets('App renders with bottom navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const IdzExampleApp());

    // The example was rewritten for /v1 in 0.1.0 — two destinations.
    expect(find.text('Verify'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
