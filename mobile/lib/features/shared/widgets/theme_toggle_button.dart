import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme_controller.dart';

/// One-tap cycle: System → Light → Dark. Icon reflects current state so
/// the user can tell at a glance which mode they're on.
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeControllerProvider);
    final (icon, tooltip) = switch (mode) {
      ThemeMode.system => (Icons.brightness_auto_rounded, 'Theme: system'),
      ThemeMode.light => (Icons.light_mode_rounded, 'Theme: light'),
      ThemeMode.dark => (Icons.dark_mode_rounded, 'Theme: dark'),
    };
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: () => ref.read(themeControllerProvider.notifier).cycle(),
    );
  }
}
