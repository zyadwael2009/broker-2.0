import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'api_client.dart';

/// Push-notification lifecycle.
///
/// Everything here is **best-effort**: Firebase may not be configured
/// (no google-services.json, missing web config, etc.), permission may
/// be denied, or the network may be down. None of that is allowed to
/// crash the app or block login. The public `PushService` methods all
/// return quickly and swallow errors — inspect [ready] to know whether
/// notifications will actually work.
class PushService {
  PushService(this._api);

  final ApiClient _api;
  bool _initialized = false;
  bool _firebaseReady = false;
  String? _lastRegisteredToken;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  StreamSubscription<String>? _refreshSub;

  bool get ready => _firebaseReady;

  /// Initialise Firebase once, wire foreground/tap handlers. Safe to call
  /// multiple times.
  Future<void> init({required GoRouter Function() router}) async {
    if (_initialized) return;
    _initialized = true;
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (_) {
      // No google-services.json / no web config → notifications simply
      // don't work. Never a fatal error.
      return;
    }

    final fm = FirebaseMessaging.instance;

    // Foreground message — display an in-app snackbar via router messenger.
    _foregroundSub = FirebaseMessaging.onMessage.listen((RemoteMessage m) {
      // Foreground display is intentionally minimal — the mobile OS
      // won't show a notification banner while the app is open. We
      // could show one via `flutter_local_notifications` later; for now
      // we let the message controller's in-app UI catch messages by
      // polling. This handler just deep-links if the user got a data
      // message they should navigate to (rare in foreground).
    });

    // Cold-start tap: what launched the app.
    final initial = await fm.getInitialMessage();
    if (initial != null) _handleNavigate(initial, router());

    // Background/quit tap while app is running.
    _openedSub = FirebaseMessaging.onMessageOpenedApp
        .listen((m) => _handleNavigate(m, router()));

    // Token refresh — re-register with backend when Firebase rotates it.
    _refreshSub = fm.onTokenRefresh.listen((t) async {
      if (_lastRegisteredToken == t) return;
      await _registerToken(t);
    });
  }

  /// Called on successful login. Requests permission, gets the current
  /// token, and posts it to /devices. Silent no-op when Firebase absent.
  Future<void> registerAfterLogin() async {
    if (!_firebaseReady) return;
    try {
      final fm = FirebaseMessaging.instance;
      // iOS + web need explicit permission. Android grants automatically.
      final settings = await fm.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await fm.getToken();
      if (token == null || token.isEmpty) return;
      await _registerToken(token);
    } catch (_) {
      // Network offline, permission race, whatever — try again next login.
    }
  }

  /// Called on logout — best effort. Failure just means the token
  /// stays in the DB until FCM tells us it's invalid.
  Future<void> deregisterOnLogout() async {
    final token = _lastRegisteredToken;
    _lastRegisteredToken = null;
    if (token == null) return;
    try {
      await _api.dio.delete('/devices', data: {'token': token});
    } catch (_) {}
  }

  Future<void> _registerToken(String token) async {
    _lastRegisteredToken = token;
    try {
      await _api.dio.post('/devices', data: {
        'token': token,
        'platform': _platformName(),
      });
    } catch (_) {
      // Server unreachable — token will re-register on the next login
      // (registerAfterLogin runs from AuthController).
    }
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'android';
    }
  }

  /// Read the `route` field from `data` and push into the router. The
  /// backend triggers set values like `/messages/42`, `/broker/verify`.
  void _handleNavigate(RemoteMessage m, GoRouter router) {
    final route = (m.data['route'] ?? '').toString().trim();
    if (route.isEmpty) return;
    try {
      router.go(route);
    } catch (_) {
      // Malformed route from a future backend version — ignore.
    }
  }

  /// Tear down subscriptions. Not currently called (service lives for
  /// the app's lifetime) but included so tests / hot restart can clean up.
  Future<void> dispose() async {
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    await _refreshSub?.cancel();
  }
}

final pushServiceProvider = Provider<PushService>((ref) {
  return PushService(ref.watch(apiClientProvider));
});
