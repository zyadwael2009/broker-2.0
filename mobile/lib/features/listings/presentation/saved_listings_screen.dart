import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../router.dart';
import '../../../theme.dart';
import '../../auth/data/models.dart' show AuthException;
import '../../shared/widgets/app_shell.dart';
import '../data/favorites_repository.dart';
import '../data/models.dart';
import 'widgets/listing_card.dart';

/// The buyer's saved listings — everything they tapped the heart on.
///
/// Reloads whenever the global favorites set changes, so unsaving from
/// here (or from a card on another screen) updates this list without a
/// manual pull.
class SavedListingsScreen extends ConsumerStatefulWidget {
  const SavedListingsScreen({super.key});

  @override
  ConsumerState<SavedListingsScreen> createState() =>
      _SavedListingsScreenState();
}

class _SavedListingsScreenState extends ConsumerState<SavedListingsScreen> {
  bool _loading = true;
  String? _error;
  List<ListingDto> _items = const [];
  int _loadGen = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gen = ++_loadGen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ref.read(favoritesRepositoryProvider).list();
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _error = e is AuthException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;

    // Unsaving a card here removes it from the global set; drop the row
    // rather than leaving a heartless card behind.
    ref.listen<Set<int>>(favoritesProvider, (prev, next) {
      if (prev == null) return;
      final removed = prev.difference(next);
      if (removed.isEmpty) return;
      setState(() {
        _items = _items.where((l) => !removed.contains(l.id)).toList();
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(t.navSaved),
        actions: [
          IconButton(
            tooltip: t.retry,
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentTab: AppTab.mine),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _items.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.18),
                              Icon(Icons.favorite_border_rounded,
                                  size: 64, color: c.textSubtle),
                              const SizedBox(height: 16),
                              Text(t.savedEmptyTitle,
                                  style: Theme.of(context).textTheme.titleLarge,
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 8),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(t.savedEmptySub,
                                    style: TextStyle(color: c.textMuted),
                                    textAlign: TextAlign.center),
                              ),
                              const SizedBox(height: 20),
                              Center(
                                child: OutlinedButton.icon(
                                  onPressed: () => context.go(Routes.home),
                                  icon: const Icon(Icons.search_rounded, size: 18),
                                  label: Text(t.navBrowse),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final l = _items[i];
                              return ListingCard(
                                listing: l,
                                onTap: () =>
                                    context.push('${Routes.listings}/${l.id}'),
                              );
                            },
                          ),
                  ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Icon(Icons.wifi_off_rounded, color: c.textSubtle, size: 44),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(message,
              textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
        ),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(t.retry),
          ),
        ),
      ],
    );
  }
}
