import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../theme.dart';
import '../../shared/widgets/app_shell.dart';

/// Placeholder screen for buyer favorites. The Favorites feature ships
/// in Phase 3 of the Stitch redesign (needs a backend table + endpoints);
/// this screen exists now so the bottom-nav "Saved" tab has a real
/// route target and doesn't 404.
///
/// Delete when [SavedListingsRepository] and the real UI land.
class SavedListingsScreen extends ConsumerWidget {
  const SavedListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context)!;
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(title: Text(t.navSaved)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_border_rounded,
                  size: 64, color: c.textSubtle),
              const SizedBox(height: 16),
              Text(t.savedEmptyTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(t.savedEmptySub,
                  style: TextStyle(color: c.textMuted),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentTab: AppTab.mine),
    );
  }
}
