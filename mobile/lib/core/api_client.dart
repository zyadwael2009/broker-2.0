import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'env.dart';
import 'token_storage.dart';

/// A Dio instance pre-wired with:
///   - base URL from --dart-define API_BASE_URL
///   - Authorization: Bearer <access> on every request that has a token
///   - Single-flight refresh on 401 (concurrent 401s await the same
///     in-flight refresh via a shared Completer, then replay)
///
/// Auth endpoints skip the Authorization header via `Options(extra:{'skipAuth': true})`.
class ApiClient {
  ApiClient(this._storage) {
    dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
        // Let us inspect non-2xx statuses without dio throwing.
        validateStatus: (s) => s != null && s < 500,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final skipAuth = options.extra['skipAuth'] == true;
          if (!skipAuth) {
            final token = await _storage.readAccess();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onResponse: (response, handler) async {
          final isAuthFailure = response.statusCode == 401 &&
              response.requestOptions.extra['skipAuth'] != true &&
              response.requestOptions.extra['retried'] != true;

          if (isAuthFailure) {
            // All concurrent 401s await the SAME refresh via `_refreshing`,
            // so we don't fire N parallel /auth/refresh calls or surface
            // spurious errors to siblings.
            final refreshed = await _tryRefresh();
            if (refreshed) {
              final replay = await _replay(response.requestOptions);
              return handler.resolve(replay);
            }
          }

          // Turn 429 into a friendly, actionable message. The backend
          // preserves the `Retry-After` header (seconds) so we can tell
          // the user roughly how long to wait.
          if (response.statusCode == 429) {
            final retryAfter = response.headers.value('retry-after');
            final data = response.data;
            final baseMsg = (data is Map && data['error'] is String)
                ? data['error'] as String
                : 'Too many requests.';
            final suffix = retryAfter != null
                ? ' Please wait about ${_humanizeSeconds(retryAfter)}.'
                : ' Please slow down.';
            response.data = {'error': '$baseMsg$suffix'};
          }
          handler.next(response);
        },
      ),
    );
  }

  late final Dio dio;
  final TokenStorage _storage;

  Completer<bool>? _refreshing;

  Future<bool> _tryRefresh() {
    // Reuse the in-flight future if one already exists.
    final existing = _refreshing;
    if (existing != null) return existing.future;

    final completer = Completer<bool>();
    _refreshing = completer;

    Future(() async {
      try {
        final refresh = await _storage.readRefresh();
        if (refresh == null) {
          completer.complete(false);
          return;
        }
        final res = await dio.post<Map<String, dynamic>>(
          '/auth/refresh',
          options: Options(
            extra: {'skipAuth': true},
            headers: {'Authorization': 'Bearer $refresh'},
          ),
        );
        if (res.statusCode == 200 && res.data?['access_token'] is String) {
          await _storage.saveAccess(res.data!['access_token'] as String);
          // Refresh-token rotation: server returns a new refresh alongside
          // the access. Persist it so the next refresh works.
          final newRefresh = res.data?['refresh_token'];
          if (newRefresh is String) {
            await _storage.saveRefresh(newRefresh);
          }
          completer.complete(true);
        } else {
          completer.complete(false);
        }
      } catch (_) {
        completer.complete(false);
      } finally {
        // Clear so the next 401 that arrives after a refresh completes
        // can start a fresh cycle if needed.
        _refreshing = null;
      }
    });

    return completer.future;
  }

  static String _humanizeSeconds(String raw) {
    final n = int.tryParse(raw);
    if (n == null || n <= 1) return 'a moment';
    if (n < 60) return '$n seconds';
    final mins = (n / 60).ceil();
    return mins == 1 ? '1 minute' : '$mins minutes';
  }

  /// Replay a failed request after a successful refresh.
  ///
  /// Multipart bodies must be rebuilt: the original FormData stream was
  /// consumed by the first attempt, so `dio.fetch(oldRequest)` would send
  /// empty bytes. We clone the FormData with a fresh iterator.
  Future<Response<dynamic>> _replay(RequestOptions req) async {
    req.extra['retried'] = true;
    final newToken = await _storage.readAccess();
    if (newToken != null) req.headers['Authorization'] = 'Bearer $newToken';

    final data = req.data;
    if (data is FormData) {
      final fresh = FormData();
      fresh.fields.addAll(data.fields);
      for (final entry in data.files) {
        fresh.files.add(MapEntry(entry.key, entry.value.clone()));
      }
      req.data = fresh;
    }
    return dio.fetch<dynamic>(req);
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(tokenStorageProvider));
});
