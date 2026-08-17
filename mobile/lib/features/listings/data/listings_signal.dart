import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bumped whenever a listing mutates (create, confirm, delete). Any screen
/// that renders a list of listings can `ref.listen(listingsRevProvider, …)`
/// and reload — cheaper than a global event bus and doesn't rely on
/// GoRouter pop-return, which is null on Android system back.
final listingsRevProvider = StateProvider<int>((_) => 0);

void bumpListingsRev(WidgetRef ref) {
  ref.read(listingsRevProvider.notifier).state++;
}
