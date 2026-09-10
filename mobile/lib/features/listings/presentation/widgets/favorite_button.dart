import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../../theme.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../data/favorites_repository.dart';

/// The heart that saves a listing to the buyer's "Saved" tab.
///
/// Renders nothing when there's no signed-in user (screenshot builds,
/// signed-out deep links) — an unusable control is worse than no
/// control. Brokers see it too: saving a rival's listing as a comparable
/// is a legitimate use, and hiding it would just be a rule to explain.
///
/// [onSurface] styles it for sitting on top of a listing photo (dark
/// scrim, white glyph) instead of on a card body.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({
    super.key,
    required this.listingId,
    this.onSurface = false,
    this.size = 20,
  });

  final int listingId;
  final bool onSurface;
  final double size;

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final t = AppL10n.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await ref.read(favoritesProvider.notifier).toggle(listingId);
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(saved ? t.listingSaved : t.listingUnsaved),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(t.listingSaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authControllerProvider).user != null;
    if (!signedIn) return const SizedBox.shrink();

    final t = AppL10n.of(context)!;
    final c = context.colors;
    final saved = ref.watch(favoritesProvider).contains(listingId);

    final glyph = Icon(
      saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      size: size,
      color: saved
          ? c.rejected // the heart is the one place a warm red earns its keep
          : (onSurface ? Colors.white : c.textMuted),
    );

    return Semantics(
      button: true,
      label: saved ? t.listingUnsaveAction : t.listingSaveAction,
      child: Material(
        color: onSurface ? Colors.black.withValues(alpha: 0.45) : Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _toggle(context, ref),
          child: Padding(padding: const EdgeInsets.all(8), child: glyph),
        ),
      ),
    );
  }
}
