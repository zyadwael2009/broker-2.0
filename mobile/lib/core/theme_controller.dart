import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_storage.dart';

/// Persisted between launches so the user's choice survives restarts.
const _kThemeKey = 'theme_mode';

class ThemeController extends StateNotifier<ThemeMode> {
  // Default to dark on first launch — brand is dark-navy on the web, and
  // the mobile app should feel like a native continuation, not a light
  // reskin. The user can still cycle to light/system via the toggle.
  ThemeController(this._storage) : super(ThemeMode.dark);
  final FlutterSecureStorage _storage;

  Future<void> load() async {
    final raw = await _storage.read(key: _kThemeKey);
    // Only overwrite the constructor default when the user has previously
    // made an explicit choice — otherwise leave the first-launch default
    // (dark) in place.
    if (raw != null) state = _fromString(raw);
  }

  /// Cycles System → Light → Dark → System.
  Future<void> cycle() async {
    final next = switch (state) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    state = next;
    await _storage.write(key: _kThemeKey, value: _toString(next));
  }

  static ThemeMode _fromString(String? v) {
    switch (v) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _toString(ThemeMode m) => switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemeMode>((ref) {
  // Reuse the same secure-storage instance as tokens so we don't spin up two.
  final storage = ref.watch(tokenStorageProvider);
  return ThemeController(storage.rawStorage);
});
