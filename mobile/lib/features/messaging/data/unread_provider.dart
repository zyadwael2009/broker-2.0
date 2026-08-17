import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import 'messaging_repository.dart';

/// Global unread-messages count. Any AppBar that shows an inbox icon
/// watches this to know whether to render the red dot.
///
/// Polls `/threads` every 60s while there's a logged-in user; auto-stops
/// on logout. Never a WebSocket — deliberately minimal for MVP.
class UnreadController extends StateNotifier<int> {
  UnreadController(this._ref) : super(0) {
    _ref.listen<AuthState>(authControllerProvider, (_, next) {
      if (next.user == null) {
        _stop();
        state = 0;
      } else {
        _start();
      }
    }, fireImmediately: true);
  }

  final Ref _ref;
  Timer? _timer;
  bool _refreshing = false;

  void _start() {
    _timer?.cancel();
    // Kick off an immediate refresh so the badge reflects reality on login.
    unawaited(refresh());
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => refresh());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final threads = await _ref.read(messagingRepositoryProvider).listThreads();
      if (!mounted) return;
      state = threads.fold<int>(0, (sum, t) => sum + t.unreadCount);
    } catch (_) {
      // Silent — no unread badge is fine when offline.
    } finally {
      _refreshing = false;
    }
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }
}

final unreadCountProvider =
    StateNotifierProvider<UnreadController, int>((ref) {
  return UnreadController(ref);
});
