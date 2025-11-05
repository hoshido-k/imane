import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets('App starts with login screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const imaneApp());

    // Verify that the login screen is shown
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Access to your account'), findsOneWidget);
  });
}
