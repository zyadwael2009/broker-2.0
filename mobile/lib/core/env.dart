/// Compile-time environment. Override with:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
///   flutter build apk --dart-define=API_BASE_URL=https://api.example.com
///
/// 10.0.2.2 is the Android emulator's alias for host localhost.
///
/// The default is intentionally emulator-only. A release build that forgot
/// `--dart-define=API_BASE_URL=…` would silently ship pointing at the
/// emulator loopback and hit nothing on real devices — [assertConfigured]
/// makes that a loud crash at startup instead of a silent broken app.
class Env {
  static const String _defaultDevUrl = 'http://10.0.2.2:5000';

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultDevUrl,
  );

  /// Public web view base URL (Phase 12) — used by the Share menu on the
  /// listing detail screen so a broker can copy an HTTPS shareable URL
  /// to WhatsApp instead of the app-only `broker://` scheme. Defaults to
  /// [apiBaseUrl] in dev; override in release with
  /// `--dart-define=PUBLIC_BASE_URL=https://your-domain.com`.
  static const String _publicBaseUrlDefine = String.fromEnvironment(
    'PUBLIC_BASE_URL',
    defaultValue: '',
  );
  static String get publicBaseUrl =>
      _publicBaseUrlDefine.isNotEmpty ? _publicBaseUrlDefine : apiBaseUrl;

  /// True when the running binary is using the emulator-only default.
  /// In debug/profile that's fine; in release it means the build forgot
  /// its `--dart-define` and would be broken on any real device.
  static bool get isUsingDevDefault => apiBaseUrl == _defaultDevUrl;

  /// Call once from `main()` before `runApp`.
  static void assertConfigured() {
    const isRelease = bool.fromEnvironment('dart.vm.product');
    if (isRelease && isUsingDevDefault) {
      throw StateError(
        'Release build missing --dart-define=API_BASE_URL. '
        'The emulator-only default $_defaultDevUrl would not resolve on real devices.',
      );
    }
  }
}
