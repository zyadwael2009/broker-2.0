import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/env.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../router.dart';
import '../../../theme.dart';
import '../../auth/data/models.dart' show AuthException;
import '../data/admin_repository.dart';

/// Admin's Phase-3 queue: listings flagged as suspected duplicates by the
/// pHash check. Tap a card to see the listing detail; unflag inline once
/// reviewed.
class FlaggedListingsScreen extends ConsumerStatefulWidget {
  const FlaggedListingsScreen({super.key});

  @override
  ConsumerState<FlaggedListingsScreen> createState() =>
      _FlaggedListingsScreenState();
}

class _FlaggedListingsScreenState extends ConsumerState<FlaggedListingsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items =
          await ref.read(adminRepositoryProvider).listFlaggedListings();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is AuthException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _unflag(int listingId) async {
    try {
      await ref.read(adminRepositoryProvider).unflagListing(listingId);
      if (!mounted) return;
      setState(() => _items.removeWhere((l) => (l['id'] as int) == listingId));
      final t = AppL10n.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.listingUnflagged)),
      );
    } catch (e) {
      if (!mounted) return;
      final t = AppL10n.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is AuthException ? e.message : t.unflagFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, style: TextStyle(color: c.textMuted)),
                ),
              )
            : _items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_rounded, size: 44, color: c.textSubtle),
                          const SizedBox(height: 10),
                          Text(AppL10n.of(context)!.noFlagged,
                              style: TextStyle(color: c.textMuted)),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final item = _items[i];
                        return _FlaggedTile(
                          item: item,
                          onOpen: () => context.push(
                            '${Routes.listings}/${item['id']}',
                          ),
                          onUnflag: () => _unflag(item['id'] as int),
                        );
                      },
                    ),
                  );
  }
}

class _FlaggedTile extends StatelessWidget {
  const _FlaggedTile({
    required this.item,
    required this.onOpen,
    required this.onUnflag,
  });
  final Map<String, dynamic> item;
  final VoidCallback onOpen;
  final VoidCallback onUnflag;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final photos = (item['photos'] as List?) ?? const [];
    final firstUrl = photos.isEmpty ? null : photos.first['url'] as String;
    final broker = item['broker'] as Map<String, dynamic>?;
    final dupOf = item['duplicate_of_listing_id'];

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onOpen,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: firstUrl == null
                          ? Container(color: c.surfaceAlt)
                          : CachedNetworkImage(
                              imageUrl: '${Env.apiBaseUrl}$firstUrl',
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: c.surfaceAlt),
                              errorWidget: (_, __, ___) =>
                                  Container(color: c.surfaceAlt),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] as String? ?? '',
                          style: TextStyle(
                              color: c.text, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          broker != null
                              ? '${broker['full_name']} · ${broker['phone']}'
                              : '',
                          style: TextStyle(color: c.textMuted, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: c.pendingBg,
                            border: Border.all(color: c.pendingLine),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            dupOf != null
                                ? AppL10n.of(context)!.duplicateOf(dupOf as int)
                                : AppL10n.of(context)!.duplicateSuspected,
                            style: TextStyle(
                              color: c.pending,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: c.textSubtle,
                      textDirection: Directionality.of(context)),
                ],
              ),
            ),
          ),
          Divider(color: c.border, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(AppL10n.of(context)!.unflag),
                  onPressed: onUnflag,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
