import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../auth/data/models.dart' show AuthException;
import '../../auth/presentation/auth_controller.dart';
import 'models.dart';

/// Saved listings — the heart on a listing card and the "Saved" tab.
/// Mirrors `backend/app/favorites/routes.py`.
class FavoritesRepository {
  FavoritesRepository(this._api);
  final ApiClient _api;

  /// Just the ids. The browse feed calls this once per load so it knows
  /// which hearts to fill without hydrating every saved listing.
  Future<Set<int>> ids() async {
    final res = await _api.dio.get<Map<String, dynamic>>('/favorites/ids');
    if (res.statusCode == 200 && res.data != null) {
      final raw = (res.data!['listing_ids'] as List?) ?? const [];
      return raw.map((e) => (e as num).toInt()).toSet();
    }
    throw AuthException('Could not load saved listings.', status: res.statusCode);
  }

  Future<List<ListingDto>> list() async {
    final res = await _api.dio.get<dynamic>('/favorites');
    if (res.statusCode == 200 && res.data is List) {
      return (res.data as List)
          .cast<Map<String, dynamic>>()
          .map(ListingDto.fromJson)
          .toList();
    }
    throw AuthException('Could not load saved listings.', status: res.statusCode);
  }

  /// Idempotent on the server — a double tap is not an error.
  Future<void> add(int listingId) async {
    final res = await _api.dio.post('/favorites/$listingId');
    if (res.statusCode == 201 || res.statusCode == 200) return;
    throw AuthException('Could not save this listing.', status: res.statusCode);
  }

  Future<void> remove(int listingId) async {
    final res = await _api.dio.delete('/favorites/$listingId');
    if (res.statusCode == 204) return;
    throw AuthException('Could not remove this listing.', status: res.statusCode);
  }
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepository(ref.watch(apiClientProvider));
});

/// The set of listing ids the signed-in user has saved.
///
/// Held globally rather than per-screen because three surfaces render the
/// same heart (browse card, listing detail, broker profile) and they must
/// agree instantly — tapping the heart on a detail screen has to fill the
/// one on the card behind it.
///
/// Writes are optimistic: state flips first, the request follows, and a
/// failure rolls the flip back. A save is trivial to redo, and waiting on
/// the network to animate a heart feels broken.
class FavoritesController extends StateNotifier<Set<int>> {
  FavoritesController(this._ref) : super(const {}) {
    _ref.listen<AuthState>(authControllerProvider, (_, next) {
      if (next.user == null) {
        // Never leak one account's saves into the next session.
        state = const {};
      } else {
        refresh();
      }
    }, fireImmediately: true);
  }

  final Ref _ref;

  bool contains(int listingId) => state.contains(listingId);

  Future<void> refresh() async {
    try {
      final ids = await _ref.read(favoritesRepositoryProvider).ids();
      if (!mounted) return;
      state = ids;
    } catch (_) {
      // Offline or signed out — an empty heart is the honest fallback.
    }
  }

  /// Returns the state the listing ended up in (true = saved), or throws
  /// if the server refused, after rolling the optimistic flip back.
  Future<bool> toggle(int listingId) async {
    final wasSaved = state.contains(listingId);
    state = wasSaved
        ? (state.toSet()..remove(listingId))
        : (state.toSet()..add(listingId));
    try {
      final repo = _ref.read(favoritesRepositoryProvider);
      if (wasSaved) {
        await repo.remove(listingId);
      } else {
        await repo.add(listingId);
      }
      return !wasSaved;
    } catch (_) {
      if (mounted) {
        state = wasSaved
            ? (state.toSet()..add(listingId))
            : (state.toSet()..remove(listingId));
      }
      rethrow;
    }
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesController, Set<int>>((ref) {
  return FavoritesController(ref);
});
