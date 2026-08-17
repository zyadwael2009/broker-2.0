import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper over flutter_secure_storage so the rest of the app never
/// touches raw storage keys.
class TokenStorage {
  TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  /// Exposed so unrelated app-level preferences (e.g. theme choice) can
  /// piggy-back on the same encrypted store without spinning up a second
  /// instance.
  FlutterSecureStorage get rawStorage => _storage;

  static const _kAccess = 'jwt_access';
  static const _kRefresh = 'jwt_refresh';

  Future<void> save({required String access, required String refresh}) async {
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
  }

  Future<void> saveAccess(String access) =>
      _storage.write(key: _kAccess, value: access);

  Future<void> saveRefresh(String refresh) =>
      _storage.write(key: _kRefresh, value: refresh);

  Future<String?> readAccess() => _storage.read(key: _kAccess);
  Future<String?> readRefresh() => _storage.read(key: _kRefresh);

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(const FlutterSecureStorage());
});
