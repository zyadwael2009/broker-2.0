import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_storage.dart';

/// Persisted between launches so the user's choice survives restarts.
const _kThemeKey = 'theme_mode';

class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController(this._storage) : super(ThemeMode.system);
  final FlutterSecureStorage _storage;

  Future<void> load() async {
    final raw = await _storage.read(key: _kThemeKey);
    state = _fromString(raw);
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
