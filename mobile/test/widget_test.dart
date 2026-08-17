// Smoke test: verify the app boots to the login screen without exceptions.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:broker_app/app.dart';

void main() {
  testWidgets('App boots and shows the login screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BrokerApp()));
    await tester.pump();

    // The login screen's app bar title.
    expect(find.text('Sign in'), findsOneWidget);
  });
}
