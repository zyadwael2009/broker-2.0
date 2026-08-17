import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/push_service.dart';
import '../../../core/token_storage.dart';
import '../data/auth_repository.dart';
import '../data/models.dart';

/// Immutable state for the auth flow. `submitting` toggles button spinners;
/// `error` is a one-shot message the UI can show as a SnackBar.
@immutable
class AuthState {
  const AuthState({
    this.user,
    this.brokerProfile,
    this.submitting = false,
    this.error,
  });

  final UserDto? user;
  final BrokerProfileDto? brokerProfile;
  final bool submitting;
  final String? error;

  AuthState copyWith({
    UserDto? user,
    BrokerProfileDto? brokerProfile,
    bool? submitting,
    String? error,
    bool clearUser = false,
    bool clearError = false,
    bool clearBrokerProfile = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      brokerProfile: clearUser || clearBrokerProfile
          ? null
          : (brokerProfile ?? this.brokerProfile),
      submitting: submitting ?? this.submitting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo, this._storage, this._push)
      : super(const AuthState());

  final AuthRepository _repo;
  final TokenStorage _storage;
  final PushService _push;

  /// Called at app start to restore session if a token exists.
  Future<void> hydrate() async {
    final access = await _storage.readAccess();
    if (access == null) return;
    try {
      final data = await _repo.me();
      if (data == null) {
        // Repo swallows non-2xx as null. If /me + refresh both failed
        // the token is effectively dead — wipe so login runs cleanly on
        // the next launch instead of retrying forever.
        await _storage.clear();
        return;
      }
      final user = UserDto.fromJson(data['user'] as Map<String, dynamic>);
      final profileJson = data['broker_profile'] as Map<String, dynamic>?;
      state = AuthState(
        user: user,
        brokerProfile:
            profileJson == null ? null : BrokerProfileDto.fromJson(profileJson),
      );
    } catch (_) {
      await _storage.clear();
    }
  }

  Future<bool> register(RegisterRequest req) async {
    return _run(() => _repo.register(req));
  }

  Future<bool> login(LoginRequest req) async {
    return _run(() => _repo.login(req));
  }

  Future<bool> _run(Future<AuthResult> Function() op) async {
    state = state.copyWith(submitting: true, clearError: true);
    try {
      final result = await op();
      await _storage.save(
        access: result.tokens.accessToken,
        refresh: result.tokens.refreshToken,
      );
      state = AuthState(
        user: result.user,
        brokerProfile: result.brokerProfile,
      );
      // Fire-and-forget: register FCM token with the backend. Errors are
      // swallowed inside the service — auth flow must never fail because
      // of push.
      unawaited(_push.registerAfterLogin());
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(submitting: false, error: e.message);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(
        submitting: false,
        error: 'Network error: ${e.message ?? e.type.name}',
      );
      return false;
    } catch (e) {
      state = state.copyWith(submitting: false, error: 'Unexpected error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    // Push token first — while we still have a valid access token, so the
    // /devices DELETE succeeds. After clear() we'd 401.
    await _push.deregisterOnLogout();
    // Revoke both tokens server-side before clearing local storage.
    // Best-effort — if the server is unreachable we still finish logout
    // locally so the user isn't stuck.
    final access = await _storage.readAccess();
    final refresh = await _storage.readRefresh();
    if (access != null) await _repo.logoutToken(access);
    if (refresh != null) await _repo.logoutToken(refresh);
    await _storage.clear();
    state = const AuthState();
  }

  /// Re-fetch the current user + broker profile. Call after any action
  /// that changes what the AppBar / router / gates read from auth state —
  /// e.g. after a broker submits their verification documents.
  Future<void> refreshMe() async {
    try {
      final data = await _repo.me();
      if (data == null) return;
      final user = UserDto.fromJson(data['user'] as Map<String, dynamic>);
      final profileJson = data['broker_profile'] as Map<String, dynamic>?;
      state = state.copyWith(
        user: user,
        // Explicitly clear when server returns no profile (role change, etc.);
        // otherwise a stale profile lingers because copyWith(null) is a no-op.
        brokerProfile:
            profileJson == null ? null : BrokerProfileDto.fromJson(profileJson),
        clearBrokerProfile: profileJson == null,
      );
    } catch (_) {
      // Silent — the caller already reflected the change locally.
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  // ── Phase A2: phone verification + password reset ──────────────

  /// Ask the server to (re)send a phone OTP for the current user.
  /// Returns the plaintext code IF the server is in dev debug mode,
  /// otherwise null (user reads it from their SMS).
  Future<String?> sendPhoneOtp() async {
    try {
      return await _repo.sendPhoneOtp();
    } on AuthException {
      rethrow;
    }
  }

  /// Confirm the OTP. On success, mutates local user state so the
  /// phone_verified banner disappears without a full page reload,
  /// and stores the fresh JWT that carries the new claim.
  Future<bool> confirmPhoneOtp(String code) async {
    try {
      final result = await _repo.confirmPhoneOtp(code);
      await _storage.save(
        access: result.tokens.accessToken,
        refresh: result.tokens.refreshToken,
      );
      state = state.copyWith(
        user: result.user,
        brokerProfile: result.brokerProfile ?? state.brokerProfile,
      );
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    }
  }

  /// Request a password-reset OTP. Never leaks whether the phone exists.
  Future<String?> forgotPassword(String phoneE164) =>
      _repo.forgotPassword(phoneE164);

  /// Complete the reset. The caller should route back to /login after.
  Future<bool> resetPassword({
    required String phoneE164,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _repo.resetPassword(
        phoneE164: phoneE164,
        code: code,
        newPassword: newPassword,
      );
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.watch(authRepositoryProvider),
    ref.watch(tokenStorageProvider),
    ref.watch(pushServiceProvider),
  );
});
