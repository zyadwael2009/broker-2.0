import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/locale_controller.dart';
import 'core/theme_controller.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'l10n/gen/app_localizations.dart';
import 'router.dart';
import 'theme.dart';

class BrokerApp extends ConsumerWidget {
  const BrokerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Auth state drives the router redirect; theme mode drives the palette;
    // locale drives the language + directionality (Arabic → RTL).
    ref.watch(authControllerProvider);
    final themeMode = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppL10n.of(context)!.appTitle,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppL10n.supportedLocales,
      localizationsDelegates: AppL10n.localizationsDelegates,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
