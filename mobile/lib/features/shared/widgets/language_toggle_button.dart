import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale_controller.dart';

/// Cycle system → English → Arabic. Icon reflects current state.
class LanguageToggleButton extends ConsumerWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);
    final (icon, tooltip) = switch (locale?.languageCode) {
      'en' => (Icons.language_rounded, 'English'),
      'ar' => (Icons.abc_rounded, 'العربية'),
      _ => (Icons.translate_rounded, 'System language'),
    };
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: () => ref.read(localeControllerProvider.notifier).cycle(),
    );
  }
}
