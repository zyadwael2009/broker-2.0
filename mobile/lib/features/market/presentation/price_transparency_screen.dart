import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../theme.dart';
import '../../auth/data/models.dart' show AuthException;
import '../data/market_repository.dart';
import '../data/models.dart';

List<(String, String)> _propertyTypeOptions(AppL10n t) => [
      ('apartment', t.propertyApartment),
      ('house', t.propertyHouse),
      ('villa', t.propertyVilla),
      ('land', t.propertyLand),
      ('commercial', t.propertyCommercial),
    ];

class PriceTransparencyScreen extends ConsumerStatefulWidget {
  const PriceTransparencyScreen({super.key});

  @override
  ConsumerState<PriceTransparencyScreen> createState() =>
      _PriceTransparencyScreenState();
}

class _PriceTransparencyScreenState
    extends ConsumerState<PriceTransparencyScreen> {
  MarketFiltersDto? _filters;
  PriceStatsDto? _stats;
  List<PriceTrendPoint> _trend = const [];
  bool _loading = true;
  String? _error;

  String? _governorate;
  String? _city;
  String? _propertyType;

  // Monotonic generation counter — tapping filters rapidly launches
  // overlapping requests; only the most recent one is allowed to write
  // to state, so a slow-returning older request can't clobber the view.
  int _loadGen = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final gen = ++_loadGen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(marketRepositoryProvider);
      // Filters load once; stats+trend refetch on every filter change.
      _filters ??= await repo.filters();
      final res = await Future.wait([
        repo.stats(
          governorate: _governorate,
          city: _city,
          propertyType: _propertyType,
        ),
        repo.trend(
          governorate: _governorate,
          city: _city,
          propertyType: _propertyType,
        ),
      ]);
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _stats = res[0] as PriceStatsDto;
        _trend = res[1] as List<PriceTrendPoint>;
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

  void _setGovernorate(String? gov) {
    setState(() {
      _governorate = gov;
      _city = null; // city depends on governorate; clear it
    });
    _loadAll();
  }

  void _setCity(String? city) {
    setState(() => _city = city);
    _loadAll();
  }

  void _setPropertyType(String? pt) {
    setState(() => _propertyType = pt);
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cities = _governorate == null
        ? const <String>[]
        : (_filters?.citiesByGovernorate[_governorate!] ?? const <String>[]);

    final t = AppL10n.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.priceTransparency),
        actions: [
          IconButton(
            tooltip: t.refresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _loadAll,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading && _stats == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _stats == null
                ? RefreshIndicator(
                    onRefresh: _loadAll,
                    child: ListView(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                        Icon(Icons.wifi_off_rounded,
                            color: c.textSubtle, size: 44),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: c.textMuted)),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: _loadAll,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(t.retry),
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadAll,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _FiltersCard(
                          governorates: _filters?.governorates ?? const [],
                          cities: cities,
                          selectedGovernorate: _governorate,
                          selectedCity: _city,
                          selectedPropertyType: _propertyType,
                          onGovernorate: _setGovernorate,
                          onCity: _setCity,
                          onPropertyType: _setPropertyType,
                        ),
                        const SizedBox(height: 16),
                        _HeadlineCard(stats: _stats!),
                        const SizedBox(height: 16),
                        _TrendCard(points: _trend),
                        const SizedBox(height: 12),
                        Text(
                          t.marketHonest,
                          style: TextStyle(
                            color: c.textSubtle,
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

// ── Filters ────────────────────────────────────────────────────────────

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({
    required this.governorates,
    required this.cities,
    required this.selectedGovernorate,
    required this.selectedCity,
    required this.selectedPropertyType,
    required this.onGovernorate,
    required this.onCity,
    required this.onPropertyType,
  });

  final List<String> governorates;
  final List<String> cities;
  final String? selectedGovernorate;
  final String? selectedCity;
  final String? selectedPropertyType;
  final ValueChanged<String?> onGovernorate;
  final ValueChanged<String?> onCity;
  final ValueChanged<String?> onPropertyType;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final types = _propertyTypeOptions(t);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.filtersLabel, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 10),
          _FilterDropdown<String>(
            label: t.listingGovernorate,
            value: selectedGovernorate,
            options: governorates,
            onChanged: onGovernorate,
          ),
          const SizedBox(height: 8),
          _FilterDropdown<String>(
            // Key on the parent governorate — forces a fresh internal
            // state when governorate flips, otherwise DropdownButton's
            // internal state points at a city no longer in `items`.
            key: ValueKey('city-$selectedGovernorate'),
            label: t.listingCity,
            value: selectedCity,
            options: cities,
            onChanged: onCity,
            disabled: selectedGovernorate == null,
          ),
          const SizedBox(height: 8),
          _FilterDropdown<String>(
            label: t.listingPropertyType,
            value: selectedPropertyType,
            options: types.map((e) => e.$1).toList(),
            optionLabel: (v) => types.firstWhere((e) => e.$1 == v).$2,
            onChanged: onPropertyType,
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.optionLabel,
    this.disabled = false,
  });

  final String label;
  final T? value;
  final List<T> options;
  final String Function(T)? optionLabel;
  final ValueChanged<T?> onChanged;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem<Never>(value: null, child: Text(AppL10n.of(context)!.all)),
        for (final opt in options)
          DropdownMenuItem<T>(
            value: opt,
            child: Text(optionLabel != null ? optionLabel!(opt) : opt.toString()),
          ),
      ],
      onChanged: disabled ? null : onChanged,
    );
  }
}

// ── Headline ───────────────────────────────────────────────────────────

class _HeadlineCard extends StatelessWidget {
  const _HeadlineCard({required this.stats});
  final PriceStatsDto stats;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final f = NumberFormat.decimalPattern(
        Localizations.localeOf(context).toLanguageTag());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: stats.isEmpty
          ? Column(
              children: [
                Icon(Icons.trending_flat_rounded, color: c.textSubtle, size: 36),
                const SizedBox(height: 8),
                Text(t.notEnoughListings,
                    style: TextStyle(color: c.textMuted)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.medianPricePerM2,
                    style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      f.format(stats.median),
                      style: TextStyle(
                        color: c.primary,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('EGP',
                        style: TextStyle(
                          color: c.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        label: t.rangeLabel,
                        value: '${f.format(stats.min)}–${f.format(stats.max)}',
                      ),
                    ),
                    Container(width: 1, height: 32, color: c.border),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniStat(
                        label: t.middle50Label,
                        value: '${f.format(stats.p25)}–${f.format(stats.p75)}',
                      ),
                    ),
                    Container(width: 1, height: 32, color: c.border),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniStat(
                        label: t.listingsLabel,
                        value: '${stats.count}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(color: c.text, fontSize: 12, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ── Trend chart ────────────────────────────────────────────────────────

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.points});
  final List<PriceTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppL10n.of(context)!.medianTrendTitle,
              style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 12),
          if (points.length < 2)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Icon(Icons.show_chart_rounded, color: c.textSubtle, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    AppL10n.of(context)!.notEnoughMonthly,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.textMuted, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 180,
              child: _TrendChart(points: points),
            ),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});
  final List<PriceTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].median),
    ];
    final minY = points.map((p) => p.median).reduce((a, b) => a < b ? a : b);
    final maxY = points.map((p) => p.median).reduce((a, b) => a > b ? a : b);
    // Proportional padding — a flat trend on a scale of tens of thousands
    // EGP/m² needs enough headroom to read as flat, not as pinned to the
    // top gridline (fixed 0.15 pad was invisible at those magnitudes).
    final span = maxY - minY;
    final pad = span > 0 ? span * 0.15 : (maxY * 0.05).clamp(1.0, double.infinity);

    return LineChart(
      LineChartData(
        minY: (minY - pad).clamp(0, double.infinity),
        maxY: maxY + pad,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: c.border, strokeWidth: 1, dashArray: [4, 4]),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                // Show ~4 labels max so they don't collide.
                final step = (points.length / 4).ceil().clamp(1, points.length);
                if (i % step != 0 && i != points.length - 1) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    points[i].month.substring(2), // yy-mm
                    style: TextStyle(color: c.textSubtle, fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: c.primary,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 3,
                color: c.primary,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: c.primary.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}
