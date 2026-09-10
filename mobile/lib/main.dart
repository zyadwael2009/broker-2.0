import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/env.dart';
import 'core/locale_controller.dart';
import 'core/push_service.dart';
import 'core/theme_controller.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fail loudly on release builds that shipped without --dart-define=API_BASE_URL.
  Env.assertConfigured();
  final container = ProviderContainer();
  // Restore state from secure storage before painting the first frame,
  // so we don't flash a wrong theme or bounce a returning user to /login.
  // Failures (platform channel not ready, storage corrupted) must NOT
  // block runApp — the app can still boot to the login screen.
  //
  // The timeout matters as much as the catchError: a storage plugin that
  // never answers (rather than throwing) would hold the first frame
  // forever, and a user staring at a blank canvas cannot even reach the
  // login screen to work around it. Nothing is lost by giving up early —
  // these are StateNotifiers, so a late answer still repaints the app.
  await Future.wait<void>([
    container
        .read(themeControllerProvider.notifier)
        .load()
        .catchError((_) {}),
    container
        .read(localeControllerProvider.notifier)
        .load()
        .catchError((_) {}),
    container
        .read(authControllerProvider.notifier)
        .hydrate()
        .catchError((_) {}),
  ]).timeout(
    const Duration(seconds: 3),
    onTimeout: () => const <void>[],
  );

  runApp(
    UncontrolledProviderScope(container: container, child: const BrokerApp()),
  );

  // Push notifications are best-effort — kick off after runApp so a
  // missing google-services.json (or any Firebase init hiccup) never
  // blocks the first frame. The service swallows all init errors.
  unawaited(
    container.read(pushServiceProvider).init(
          router: () => container.read(routerProvider),
        ),
  );
  // If a session was already restored via hydrate() above, register the
  // token now — otherwise the AuthController fires this after login.
  if (container.read(authControllerProvider).user != null) {
    unawaited(container.read(pushServiceProvider).registerAfterLogin());
  }
}
