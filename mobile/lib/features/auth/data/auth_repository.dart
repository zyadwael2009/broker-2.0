import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import 'models.dart';

/// Talks to the Flask auth endpoints. Never touches storage or state —
/// AuthController owns that.
class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  Future<AuthResult> register(RegisterRequest req) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: req.toJson(),
      options: Options(extra: {'skipAuth': true}),
    );
    return _handleAuthResponse(res);
  }

  Future<AuthResult> login(LoginRequest req) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: req.toJson(),
      options: Options(extra: {'skipAuth': true}),
    );
    return _handleAuthResponse(res);
  }

  Future<Map<String, dynamic>?> me() async {
    final res = await _api.dio.get<Map<String, dynamic>>('/auth/me');
    if (res.statusCode == 200) return res.data;
    return null;
  }

  /// Phase G1 — every referral the current user has driven. Returns
  /// {code, count, referred: [...]}.
  Future<Map<String, dynamic>?> fetchReferrals() async {
    try {
      final res = await _api.dio.get<Map<String, dynamic>>('/auth/me/referrals');
      if (res.statusCode == 200) return res.data;
    } catch (_) {
      // Silent — the referral card fails soft and just doesn't render.
    }
    return null;
  }

  // ── Phase A2: phone verification ─────────────────────────────────

  /// Request a fresh OTP for the currently-logged-in user's phone.
  /// Returns the plaintext code IF the server is in SMS_DEBUG_RETURN_CODE
  /// mode (dev only) — the client uses that only to prefill the code
  /// field in dev; in prod it's always null and the user reads it from
  /// their SMS.
  Future<String?> sendPhoneOtp() async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/auth/verify-phone/send',
    );
    if (res.statusCode != 200) {
      throw AuthException(
        _extractError(res.data) ?? 'Could not send verification code.',
        status: res.statusCode,
      );
    }
    return res.data?['debug_code'] as String?;
  }

  /// Confirm the OTP the user typed. On success returns the updated
  /// AuthResult (with fresh JWT carrying phone_verified=true).
  Future<AuthResult> confirmPhoneOtp(String code) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/auth/verify-phone/confirm',
      data: {'code': code},
    );
    return _handleAuthResponse(res);
  }

  /// Fire-and-forget password reset request. Server never leaks whether
  /// the phone exists (anti-enumeration) — we always succeed locally.
  Future<String?> forgotPassword(String phoneE164) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/auth/forgot-password',
      data: {'phone': phoneE164},
      options: Options(extra: {'skipAuth': true}),
    );
    // Server returns 200 unconditionally.
    return res.data?['debug_code'] as String?;
  }

  /// Complete the reset with the OTP + new password.
  Future<void> resetPassword({
    required String phoneE164,
    required String code,
    required String newPassword,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/auth/reset-password',
      data: {
        'phone': phoneE164,
        'code': code,
        'new_password': newPassword,
      },
      options: Options(extra: {'skipAuth': true}),
    );
    if (res.statusCode != 200) {
      throw AuthException(
        _extractError(res.data) ?? 'Could not reset password.',
        status: res.statusCode,
      );
    }
  }

  /// Revoke a token server-side (JTI added to the blocklist). Pass the
  /// raw token to bypass the Dio interceptor's normal Authorization
  /// injection — logout needs to specify exactly which token to kill.
  Future<void> logoutToken(String token) async {
    try {
      await _api.dio.post(
        '/auth/logout',
        options: Options(
          extra: {'skipAuth': true},
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
    } catch (_) {
      // Best-effort — always succeed locally even if the server is
      // unreachable. The local tokens still get cleared by the caller.
    }
  }

  AuthResult _handleAuthResponse(Response<Map<String, dynamic>> res) {
    final data = res.data;
    if (res.statusCode == 201 || res.statusCode == 200) {
      if (data == null) {
        throw AuthException('Empty response from server.');
      }
      return AuthResult.fromJson(data);
    }
    throw AuthException(
      _extractError(data) ?? 'Request failed (${res.statusCode}).',
      status: res.statusCode,
    );
  }

  String? _extractError(Map<String, dynamic>? data) {
    if (data == null) return null;
    // Flask returns one of three shapes:
    //   {"error": "..."}                                     — simple string
    //   {"error": "...", "fields": {"phone": ["..."]}}       — per-field map
    //   {"error": "...", "fields": ["..."]}                  — plain list
    //                                                          (e.g. normalize_phone
    //                                                           raising outside a schema)
    // Surface whichever is most specific.
    final fields = data['fields'];
    if (fields is Map && fields.isNotEmpty) {
      final first = fields.entries.first;
      final val = first.value;
      final msg = val is List && val.isNotEmpty ? val.first : val;
      return '${first.key}: $msg';
    }
    if (fields is List && fields.isNotEmpty) {
      return '${fields.first}';
    }
    final err = data['error'];
    return err is String ? err : null;
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});
