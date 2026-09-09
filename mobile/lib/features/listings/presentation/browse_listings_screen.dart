import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/env.dart';
import '../../../core/geo/egypt.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../router.dart';
import '../../../theme.dart';
import '../../auth/data/models.dart' show AuthException;
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/brand_app_bar.dart';
import '../../shared/widgets/verify_phone_banner.dart';
import '../data/listings_repository.dart';
import '../data/listings_signal.dart';
import '../data/models.dart';
import 'widgets/listing_card.dart';

/// Sort keys the backend accepts (`apply_listing_sort`). Order here is
/// the order they appear in the sort menu.
enum _Sort { newest, priceAsc, priceDesc, areaDesc }

extension on _Sort {
  String get apiValue => switch (this) {
        _Sort.newest => 'newest',
        _Sort.priceAsc => 'price_asc',
        _Sort.priceDesc => 'price_desc',
        _Sort.areaDesc => 'area_desc',
      };

  String label(AppL10n t) => switch (this) {
        _Sort.newest => t.sortNewest,
        _Sort.priceAsc => t.sortPriceAsc,
        _Sort.priceDesc => t.sortPriceDesc,
        _Sort.areaDesc => t.sortAreaDesc,
      };
}

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

  // ── Filter state ───────────────────────────────────────────────
  String? _kindFilter;         // null | 'sale' | 'rent'
  String? _governorateFilter;
  String? _cityFilter;
  int? _bedroomsMin;
  String? _minPrice;
  String? _maxPrice;
  _Sort _sort = _Sort.newest;

  final _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
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
            minPrice: _minPrice,
            maxPrice: _maxPrice,
            query: _query,
            sort: _sort.apiValue,
            usePublic: Env.screenshotMode,
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

  /// Typing shouldn't fire a request per keystroke — Egyptian mobile data
  /// is metered and the feed is a full page of photos.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || value.trim() == _query) return;
      setState(() => _query = value.trim());
      _load();
    });
  }

  int _activeFilterCount() {
    var n = 0;
    if (_kindFilter != null) n++;
    if (_governorateFilter != null) n++;
    if (_cityFilter != null) n++;
    if (_bedroomsMin != null) n++;
    if (_minPrice != null) n++;
    if (_maxPrice != null) n++;
    return n;
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_FilterValues>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FiltersSheet(
        initial: _FilterValues(
          kind: _kindFilter,
          governorate: _governorateFilter,
          city: _cityFilter,
          bedroomsMin: _bedroomsMin,
          minPrice: _minPrice,
          maxPrice: _maxPrice,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _kindFilter = result.kind;
      _governorateFilter = result.governorate;
      _cityFilter = result.city;
      _bedroomsMin = result.bedroomsMin;
      _minPrice = result.minPrice;
      _maxPrice = result.maxPrice;
    });
    await _load();
  }

  /// The removable summary chips under the search box. Each one clears
  /// exactly the filter it names — the mockup's × affordance.
  List<Widget> _activeFilterChips(AppL10n t) {
    final chips = <Widget>[];

    void add(String label, VoidCallback onClear) {
      chips.add(_ActiveFilterChip(label: label, onClear: onClear));
    }

    if (_kindFilter != null) {
      add(_kindFilter == 'rent' ? t.listingKindRent : t.listingKindSale, () {
        setState(() => _kindFilter = null);
        _load();
      });
    }
    if (_governorateFilter != null) {
      final place = _cityFilter == null
          ? _governorateFilter!
          : '$_governorateFilter (${_cityFilter!})';
      add('${t.listingGovernorate}: $place', () {
        setState(() {
          _governorateFilter = null;
          _cityFilter = null;
        });
        _load();
      });
    } else if (_cityFilter != null) {
      add('${t.listingCity}: $_cityFilter', () {
        setState(() => _cityFilter = null);
        _load();
      });
    }
    if (_minPrice != null || _maxPrice != null) {
      add('${t.priceLabel}: ${_minPrice ?? '—'} – ${_maxPrice ?? '—'}', () {
        setState(() {
          _minPrice = null;
          _maxPrice = null;
        });
        _load();
      });
    }
    if (_bedroomsMin != null) {
      add('${t.listingBedrooms}: $_bedroomsMin+', () {
        setState(() => _bedroomsMin = null);
        _load();
      });
    }
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
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
    final activeCount = _activeFilterCount();
    final activeChips = _activeFilterChips(t);

    return Scaffold(
      appBar: const BrandAppBar(),
      bottomNavigationBar: const AppBottomNav(currentTab: AppTab.browse),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const VerifyPhoneBanner(),

                // ── Search + filter trigger ─────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: _onSearchChanged,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (v) {
                            _searchDebounce?.cancel();
                            setState(() => _query = v.trim());
                            _load();
                          },
                          decoration: InputDecoration(
                            hintText: t.browseSearchHint,
                            prefixIcon:
                                Icon(Icons.search_rounded, color: c.textMuted, size: 20),
                            suffixIcon: _searchCtrl.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: t.clear,
                                    icon: Icon(Icons.close_rounded,
                                        size: 18, color: c.textMuted),
                                    onPressed: () {
                                      _searchDebounce?.cancel();
                                      _searchCtrl.clear();
                                      setState(() => _query = '');
                                      _load();
                                    },
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _FilterIconButton(
                        count: activeCount,
                        onTap: _openFilters,
                      ),
                    ],
                  ),
                ),

                if (activeChips.isNotEmpty)
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      itemCount: activeChips.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => activeChips[i],
                    ),
                  ),

                // ── Property-type chips ─────────────────────────────
                SizedBox(
                  height: 46,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

                // ── Result count + sort ─────────────────────────────
                if (!_loading && _error == null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 8, 4),
                    child: Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: c.verified,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            t.browseVerifiedCount(_items.length),
                            style: TextStyle(
                              color: c.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _SortButton(
                          value: _sort,
                          onChanged: (s) {
                            setState(() => _sort = s);
                            _load();
                          },
                        ),
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
                                    children: [
                                      _Empty(searching: _query.isNotEmpty),
                                    ],
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: _load,
                                  child: ListView.separated(
                                    // Bottom padding clears the floating
                                    // advanced-filters pill.
                                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 84),
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

            // ── Floating "advanced filters" pill ──────────────────
            if (!_loading && _error == null && _items.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: Center(
                  child: _AdvancedFiltersPill(
                    count: activeCount,
                    onTap: _openFilters,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Small controls ─────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
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
            // Primary-ink on teal in dark mode, per the design system's
            // button rule — white on this teal fails contrast.
            color: active ? (dark ? c.background : Colors.white) : c.textMuted,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({required this.label, required this.onClear});
  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 12, end: 6),
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: 0.14),
        border: Border.all(color: c.primary.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
                color: c.primary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 2),
          IconButton(
            onPressed: onClear,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            icon: Icon(Icons.close_rounded, size: 15, color: c.primary),
          ),
        ],
      ),
    );
  }
}

class _FilterIconButton extends StatelessWidget {
  const _FilterIconButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    return Semantics(
      button: true,
      label: t.filtersLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: count > 0 ? c.primary.withValues(alpha: 0.14) : c.surface,
            border: Border.all(color: count > 0 ? c.primary : c.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Badge(
            isLabelVisible: count > 0,
            label: Text('$count'),
            backgroundColor: c.primary,
            textColor: c.background,
            child: Icon(Icons.tune_rounded,
                size: 20, color: count > 0 ? c.primary : c.textMuted),
          ),
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.value, required this.onChanged});
  final _Sort value;
  final ValueChanged<_Sort> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    return PopupMenuButton<_Sort>(
      tooltip: t.sortLabel,
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final s in _Sort.values)
          PopupMenuItem<_Sort>(value: s, child: Text(s.label(t))),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort_rounded, size: 16, color: c.textMuted),
            const SizedBox(width: 5),
            Text(
              value.label(t),
              style: TextStyle(
                  color: c.text, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvancedFiltersPill extends StatelessWidget {
  const _AdvancedFiltersPill({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? c.background : Colors.white;

    return Material(
      color: c.primary,
      borderRadius: BorderRadius.circular(999),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded, size: 18, color: ink),
              const SizedBox(width: 8),
              Text(
                count > 0
                    ? '${t.filtersAdvanced} ($count)'
                    : t.filtersAdvanced,
                style: TextStyle(
                    color: ink, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── States ─────────────────────────────────────────────────────────

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
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
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
  const _Empty({this.searching = false});

  /// A search that found nothing needs different advice than an empty
  /// feed — "try another type" is useless when the user typed a query.
  final bool searching;

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
                  Text(
                    searching ? t.emptySearchTitle : t.emptyBrowseTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    searching ? t.emptySearchSub : t.emptyBrowseSub,
                    style: TextStyle(color: c.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Advanced filters sheet ─────────────────────────────────────────

/// Plain value bag so the sheet can hand its result back in one object
/// instead of six positional returns.
class _FilterValues {
  const _FilterValues({
    this.kind,
    this.governorate,
    this.city,
    this.bedroomsMin,
    this.minPrice,
    this.maxPrice,
  });

  final String? kind;
  final String? governorate;
  final String? city;
  final int? bedroomsMin;
  final String? minPrice;
  final String? maxPrice;
}

/// The advanced filters, as a modal sheet rather than the old inline
/// accordion: the mockup puts a persistent pill at the bottom of the
/// feed, and a sheet keeps the feed itself uncluttered while giving the
/// controls room to breathe.
class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.initial});
  final _FilterValues initial;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late String? _kind = widget.initial.kind;
  late String? _governorate = widget.initial.governorate;
  late String? _city = widget.initial.city;
  late int? _bedroomsMin = widget.initial.bedroomsMin;
  late final _minCtrl = TextEditingController(text: widget.initial.minPrice ?? '');
  late final _maxCtrl = TextEditingController(text: widget.initial.maxPrice ?? '');

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  String? _trimmed(TextEditingController ctrl) {
    final v = ctrl.text.trim();
    return v.isEmpty ? null : v;
  }

  void _apply() {
    Navigator.pop(
      context,
      _FilterValues(
        kind: _kind,
        governorate: _governorate,
        city: _city,
        bedroomsMin: _bedroomsMin,
        minPrice: _trimmed(_minCtrl),
        maxPrice: _trimmed(_maxCtrl),
      ),
    );
  }

  void _reset() => Navigator.pop(context, const _FilterValues());

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final cities = citiesFor(_governorate);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.borderStrong,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded, size: 20, color: c.primary),
                  const SizedBox(width: 8),
                  Text(t.filtersAdvanced,
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    tooltip: t.cancel,
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: c.textMuted),
                  ),
                ],
              ),
            ),
            Divider(color: c.border, height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  Text(t.listingKindLabel,
                      style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 8),
                  SegmentedButton<String?>(
                    segments: [
                      ButtonSegment(value: null, label: Text(t.filterAll)),
                      ButtonSegment(value: 'sale', label: Text(t.listingKindSale)),
                      ButtonSegment(value: 'rent', label: Text(t.listingKindRent)),
                    ],
                    selected: {_kind},
                    onSelectionChanged: (s) => setState(() => _kind = s.first),
                    emptySelectionAllowed: false,
                    showSelectedIcon: false,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _governorate,
                          isExpanded: true,
                          decoration:
                              InputDecoration(labelText: t.listingGovernorate),
                          items: [
                            DropdownMenuItem<String?>(
                                value: null, child: Text(t.filterAnyGov)),
                            for (final g in allGovernorates())
                              DropdownMenuItem<String?>(value: g, child: Text(g)),
                          ],
                          onChanged: (v) => setState(() {
                            _governorate = v;
                            _city = null; // cities are scoped to a governorate
                          }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _city,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: t.listingCity),
                          items: [
                            DropdownMenuItem<String?>(
                                value: null, child: Text(t.filterAnyCity)),
                            for (final ct in cities)
                              DropdownMenuItem<String?>(value: ct, child: Text(ct)),
                          ],
                          onChanged: _governorate == null
                              ? null
                              : (v) => setState(() => _city = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(t.listingBedrooms,
                      style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: Text(t.filterBedroomsAny),
                        selected: _bedroomsMin == null,
                        onSelected: (_) => setState(() => _bedroomsMin = null),
                      ),
                      for (final n in [1, 2, 3, 4, 5])
                        ChoiceChip(
                          label: Text(n == 5 ? '5+' : '$n+'),
                          selected: _bedroomsMin == n,
                          onSelected: (_) => setState(() => _bedroomsMin = n),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(t.priceLabel,
                      style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: t.filterPriceMin),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _maxCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: t.filterPriceMax),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                20, 12, 20, 12 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _reset,
                      child: Text(t.filterReset),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _apply,
                      child: Text(t.filterApply),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
