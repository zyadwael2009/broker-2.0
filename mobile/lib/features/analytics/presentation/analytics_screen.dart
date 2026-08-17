import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../router.dart';
import '../../../theme.dart';
import '../../auth/data/models.dart' show AuthException;
import '../data/analytics_repository.dart';
import '../data/models.dart';

/// Broker-facing analytics — the biggest reason a broker opens the app
/// between deals. Four big-number cards, a 30-day line chart, and a
/// per-listing breakdown table.
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  bool _loading = true;
  String? _error;
  AnalyticsPayloadDto? _payload;

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
      final data =
          await ref.read(analyticsRepositoryProvider).fetchMyAnalytics();
      if (!mounted) return;
      setState(() {
        _payload = data;
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

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.analyticsTitle),
        actions: [
          IconButton(
            tooltip: t.refresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _SummaryCards(summary: _payload!.summary),
                        const SizedBox(height: 24),
                        Text(t.analyticsChartLabel,
                            style: Theme.of(context).textTheme.labelSmall),
                        const SizedBox(height: 8),
                        _ViewsChart(daily: _payload!.viewsDaily),
                        const SizedBox(height: 24),
                        Text(t.analyticsPerListing,
                            style: Theme.of(context).textTheme.labelSmall),
                        const SizedBox(height: 8),
                        if (_payload!.byListing.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: Text(t.analyticsEmpty,
                                  style: TextStyle(color: c.textMuted)),
                            ),
                          )
                        else
                          _ListingsTable(rows: _payload!.byListing),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.summary});
  final AnalyticsSummaryDto summary;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    Widget card(IconData icon, Color tint, String value, String label) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: tint, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: c.text,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                  color: c.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.06),
            ),
          ],
        ),
      );
    }

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.6,
      ),
      children: [
        card(Icons.visibility_rounded, c.primary,
            '${summary.viewsLast7d}', t.analyticsViews7d),
        card(Icons.trending_up_rounded, c.accentNavy,
            '${summary.viewsLast30d}', t.analyticsViews30d),
        card(Icons.chat_bubble_rounded, c.verified,
            '${summary.messagesLast7d}', t.analyticsMessages7d),
        card(Icons.star_rounded, c.accent,
            summary.reviewsCount == 0 ? '—' : summary.avgRating.toStringAsFixed(1),
            t.analyticsAvgRating),
      ],
    );
  }
}

class _ViewsChart extends StatelessWidget {
  const _ViewsChart({required this.daily});
  final List<DailyViewDto> daily;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (daily.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(AppL10n.of(context)!.analyticsEmpty,
            style: TextStyle(color: c.textMuted)),
      );
    }
    final spots = <FlSpot>[];
    var maxY = 0.0;
    for (var i = 0; i < daily.length; i++) {
      final v = daily[i].count.toDouble();
      spots.add(FlSpot(i.toDouble(), v));
      if (v > maxY) maxY = v;
    }
    // Ensure a nice-looking Y axis even at zero-state.
    if (maxY < 4) maxY = 4;

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LineChart(LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY / 4).ceilToDouble(),
          getDrawingHorizontalLine: (_) => FlLine(
            color: c.border,
            strokeWidth: 1,
            dashArray: const [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: (maxY / 4).ceilToDouble(),
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: TextStyle(color: c.textSubtle, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 7,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= daily.length) return const SizedBox.shrink();
                final d = daily[i].day;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${d.day}/${d.month}',
                      style: TextStyle(color: c.textSubtle, fontSize: 10)),
                );
              },
            ),
          ),
        ),
        minX: 0,
        maxX: (daily.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.28,
            barWidth: 2.5,
            color: c.primary,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: c.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      )),
    );
  }
}

class _ListingsTable extends StatelessWidget {
  const _ListingsTable({required this.rows});
  final List<ListingAnalyticsDto> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(color: c.border, height: 1, indent: 14, endIndent: 14),
            _ListingRow(row: rows[i]),
          ],
        ],
      ),
    );
  }
}

class _ListingRow extends StatelessWidget {
  const _ListingRow({required this.row});
  final ListingAnalyticsDto row;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: () => context.push('${Routes.listings}/${row.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${row.totalViews} total',
                    style: TextStyle(color: c.textSubtle, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _MetricPill(icon: Icons.visibility_rounded,
                value: row.viewsLast7d, color: c.primary),
            const SizedBox(width: 6),
            _MetricPill(icon: Icons.chat_bubble_outline_rounded,
                value: row.messagesLast7d, color: c.verified),
          ],
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.icon, required this.value, required this.color});
  final IconData icon;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: TextStyle(
              color: c.text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: c.textMuted, size: 44),
            const SizedBox(height: 12),
            Text(
              t.analyticsError,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.text, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textMuted, fontSize: 12)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: Text(t.retry)),
          ],
        ),
      ),
    );
  }
}
