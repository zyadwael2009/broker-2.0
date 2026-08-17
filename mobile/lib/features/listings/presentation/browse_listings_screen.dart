import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/geo/egypt.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../router.dart';
import '../../../theme.dart';
import '../../auth/data/models.dart' show AuthException;
import '../../auth/presentation/auth_controller.dart';
import '../../shared/widgets/inbox_icon_button.dart';
import '../../shared/widgets/language_toggle_button.dart';
import '../../shared/widgets/theme_toggle_button.dart';
import '../../shared/widgets/verify_phone_banner.dart';
import '../data/listings_repository.dart';
import '../data/listings_signal.dart';
import '../data/models.dart';
import 'widgets/listing_card.dart';

class BrowseListingsScreen extends ConsumerStatefulWidget {
  const BrowseListingsScreen({super.key});

  @override
  ConsumerState<BrowseListingsScreen> createState() =>
      _BrowseListingsScreenState();
}

class _BrowseListingsScreenState extends ConsumerState<BrowseListingsScreen> {
  bool _loading = true;
  String? _error;
  List<ListingDto> _items = const [];
  String? _typeFilter;
  int _loadGen = 0;

  // ── Phase A3-tail: richer filter state ─────────────────────────
  String? _kindFilter;         // null | 'sale' | 'rent'
  String? _governorateFilter;
  String? _cityFilter;
  int? _bedroomsMin;
  final _minPriceCtrl = TextEditingController();
  final _maxPriceCtrl = TextEditingController();
  bool _filtersOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final gen = ++_loadGen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ref.read(listingsRepositoryProvider).browse(
            propertyType: _typeFilter,
            kind: _kindFilter,
            governorate: _governorateFilter,
            city: _cityFilter,
            bedroomsMin: _bedroomsMin,
            minPrice: _minPriceCtrl.text.trim().isEmpty ? null : _minPriceCtrl.text.trim(),
            maxPrice: _maxPriceCtrl.text.trim().isEmpty ? null : _maxPriceCtrl.text.trim(),
          );
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

  int _activeFilterCount() {
    var n = 0;
    if (_kindFilter != null) n++;
    if (_governorateFilter != null) n++;
    if (_cityFilter != null) n++;
    if (_bedroomsMin != null) n++;
    if (_minPriceCtrl.text.trim().isNotEmpty) n++;
    if (_maxPriceCtrl.text.trim().isNotEmpty) n++;
    return n;
  }

  void _resetFilters() {
    setState(() {
      _kindFilter = null;
      _governorateFilter = null;
      _cityFilter = null;
      _bedroomsMin = null;
      _minPriceCtrl.clear();
      _maxPriceCtrl.clear();
      _filtersOpen = false;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    // Admins mutating listings elsewhere (unflag, delete) should see
    // this feed refresh without a manual pull.
    ref.listen<int>(listingsRevProvider, (_, __) => unawaited(_load()));
    final types = [
      ('apartment', t.propertyApartment),
      ('house', t.propertyHouse),
      ('villa', t.propertyVilla),
      ('land', t.propertyLand),
      ('commercial', t.propertyCommercial),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(t.browseListings),
        actions: [
          const InboxIconButton(),
          IconButton(
            tooltip: t.priceTransparency,
            icon: const Icon(Icons.query_stats_rounded),
            onPressed: () => context.push(Routes.marketPrices),
          ),
          const LanguageToggleButton(),
          const ThemeToggleButton(),
          IconButton(
            tooltip: t.signOut,
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const VerifyPhoneBanner(),
            _FiltersPanel(
              open: _filtersOpen,
              activeCount: _activeFilterCount(),
              kind: _kindFilter,
              governorate: _governorateFilter,
              city: _cityFilter,
              bedroomsMin: _bedroomsMin,
              minPriceCtrl: _minPriceCtrl,
              maxPriceCtrl: _maxPriceCtrl,
              onToggle: () => setState(() => _filtersOpen = !_filtersOpen),
              onKindChanged: (v) {
                setState(() => _kindFilter = v);
                _load();
              },
              onGovernorateChanged: (v) {
                setState(() {
                  _governorateFilter = v;
                  _cityFilter = null; // reset city when governorate flips
                });
                _load();
              },
              onCityChanged: (v) {
                setState(() => _cityFilter = v);
                _load();
              },
              onBedroomsChanged: (v) {
                setState(() => _bedroomsMin = v);
                _load();
              },
              onApply: _load,
              onReset: _resetFilters,
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: [
                  _TypeChip(
                    label: t.filterAll,
                    active: _typeFilter == null,
                    onTap: () {
                      setState(() => _typeFilter = null);
                      _load();
                    },
                  ),
                  const SizedBox(width: 8),
                  for (final (key, label) in types) ...[
                    _TypeChip(
                      label: label,
                      active: _typeFilter == key,
                      onTap: () {
                        setState(() => _typeFilter = key);
                        _load();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _ErrorState(message: _error!, onRetry: _load)
                      : _items.isEmpty
                          ? RefreshIndicator(
                              onRefresh: _load,
                              child: ListView(
                                children: const [_Empty()],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                itemCount: _items.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, i) {
                                  final l = _items[i];
                                  return ListingCard(
                                    listing: l,
                                    onTap: () => context.push(
                                      '${Routes.listings}/${l.id}',
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? c.primary : c.surface,
          border: Border.all(color: active ? c.primary : c.border),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : c.textMuted,
            fontWeight: FontWeight.w600,
            fontSize: 13,
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
    return RefreshIndicator(
      onRefresh: () async => onRetry(),
      child: ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Icon(Icons.wifi_off_rounded, color: c.textSubtle, size: 44),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textMuted)),
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
      ),
    );
  }
}


class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    return LayoutBuilder(
      builder: (_, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded, size: 48, color: c.textSubtle),
                  const SizedBox(height: 12),
                  Text(t.emptyBrowseTitle,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(t.emptyBrowseSub, style: TextStyle(color: c.textMuted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Collapsible richer filter panel. Sits above the property-type chip
/// row on the buyer landing. Default state is collapsed so the screen
/// stays uncluttered; users tap the header to reveal the controls.
class _FiltersPanel extends StatelessWidget {
  const _FiltersPanel({
    required this.open,
    required this.activeCount,
    required this.kind,
    required this.governorate,
    required this.city,
    required this.bedroomsMin,
    required this.minPriceCtrl,
    required this.maxPriceCtrl,
    required this.onToggle,
    required this.onKindChanged,
    required this.onGovernorateChanged,
    required this.onCityChanged,
    required this.onBedroomsChanged,
    required this.onApply,
    required this.onReset,
  });

  final bool open;
  final int activeCount;
  final String? kind;
  final String? governorate;
  final String? city;
  final int? bedroomsMin;
  final TextEditingController minPriceCtrl;
  final TextEditingController maxPriceCtrl;
  final VoidCallback onToggle;
  final ValueChanged<String?> onKindChanged;
  final ValueChanged<String?> onGovernorateChanged;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<int?> onBedroomsChanged;
  final VoidCallback onApply;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final cities = citiesFor(governorate);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded, size: 20, color: c.accentNavy),
                  const SizedBox(width: 8),
                  Text(t.filtersLabel,
                      style: TextStyle(color: c.text, fontWeight: FontWeight.w700)),
                  if (activeCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.accentNavy,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('$activeCount',
                          style: TextStyle(
                              color: c.surface, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                  const Spacer(),
                  Icon(open ? Icons.expand_less : Icons.expand_more, color: c.textSubtle),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sale/Rent — three-state segmented (All / Sale / Rent)
                  SegmentedButton<String?>(
                    segments: [
                      ButtonSegment(value: null, label: Text(t.filterAll)),
                      ButtonSegment(value: 'sale', label: Text(t.listingKindSale)),
                      ButtonSegment(value: 'rent', label: Text(t.listingKindRent)),
                    ],
                    selected: {kind},
                    onSelectionChanged: (s) => onKindChanged(s.first),
                    emptySelectionAllowed: false,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: governorate,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: t.listingGovernorate),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null, child: Text(t.filterAnyGov),
                            ),
                            for (final g in allGovernorates())
                              DropdownMenuItem<String?>(value: g, child: Text(g)),
                          ],
                          onChanged: onGovernorateChanged,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: city,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: t.listingCity),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null, child: Text(t.filterAnyCity),
                            ),
                            for (final ct in cities)
                              DropdownMenuItem<String?>(value: ct, child: Text(ct)),
                          ],
                          // Disabled visually when no governorate picked yet
                          onChanged: governorate == null ? null : onCityChanged,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(t.listingBedrooms,
                      style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: [
                      _BedChip(label: t.filterBedroomsAny,
                          selected: bedroomsMin == null,
                          onTap: () => onBedroomsChanged(null)),
                      for (final n in [1, 2, 3, 4, 5])
                        _BedChip(
                          label: n == 5 ? '5+' : '$n+',
                          selected: bedroomsMin == n,
                          onTap: () => onBedroomsChanged(n),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minPriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: t.filterPriceMin),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: maxPriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: t.filterPriceMax),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onReset,
                          child: Text(t.filterReset),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: onApply,
                          child: Text(t.filterApply),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BedChip extends StatelessWidget {
  const _BedChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
