// Smoke test: verify the app boots to the login screen without exceptions.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:broker_app/app.dart';
import 'package:broker_app/core/locale_controller.dart';

void main() {
  testWidgets('App boots and shows the login screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // The app defaults to Arabic for real users (see LocaleController);
        // pin English here so the test asserts on a stable string instead
        // of tracking translation edits.
        overrides: [
          localeControllerProvider.overrideWith(
            (ref) => _FixedLocale(const Locale('en')),
          ),
        ],
        child: const BrokerApp(),
      ),
    );
    await tester.pump();

    // The sign-in form's submit button.
    expect(find.text('Sign in'), findsOneWidget);
  });
}

class _FixedLocale extends StateNotifier<Locale?> implements LocaleController {
  _FixedLocale(Locale super.locale);

  @override
  Future<void> load() async {}

  @override
  Future<void> cycle() async {}
}
