import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_storage.dart';

/// Persisted user choice. `null` means "follow the system locale".
const _kLocaleKey = 'locale_code';

class LocaleController extends StateNotifier<Locale?> {
  LocaleController(this._storage) : super(null);
  final FlutterSecureStorage _storage;

  Future<void> load() async {
    final code = await _storage.read(key: _kLocaleKey);
    state = _fromString(code);
  }

  /// Cycles System → English → Arabic → System.
  Future<void> cycle() async {
    final next = switch (state?.languageCode) {
      null => const Locale('en'),
      'en' => const Locale('ar'),
      _ => null,
    };
    state = next;
    if (next == null) {
      await _storage.delete(key: _kLocaleKey);
    } else {
      await _storage.write(key: _kLocaleKey, value: next.languageCode);
    }
  }

  static Locale? _fromString(String? v) {
    switch (v) {
      case 'en':
        return const Locale('en');
      case 'ar':
        return const Locale('ar');
      default:
        return null;
    }
  }
}

final localeControllerProvider =
    StateNotifierProvider<LocaleController, Locale?>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  return LocaleController(storage.rawStorage);
});
