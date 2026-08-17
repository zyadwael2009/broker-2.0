import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../theme.dart';
import '../../auth/data/models.dart' show AuthException;
import '../../shared/widgets/star_row.dart';
import '../../shared/widgets/verified_badge.dart';
import '../data/models.dart';
import '../data/ratings_repository.dart';

/// Public broker profile — aggregate rating + recent reviews.
/// Reachable via `/brokers/:id`.
class BrokerProfileScreen extends ConsumerStatefulWidget {
  const BrokerProfileScreen({super.key, required this.brokerId});
  final int brokerId;

  @override
  ConsumerState<BrokerProfileScreen> createState() =>
      _BrokerProfileScreenState();
}

class _BrokerProfileScreenState extends ConsumerState<BrokerProfileScreen> {
  bool _loading = true;
  String? _error;
  RatingAggregateDto _aggregate = RatingAggregateDto.empty();
  List<RatingDto> _reviews = const [];
  // Best-effort — populated from the first review's broker_id lookup. We
  // don't have a dedicated broker-name endpoint, so if reviews are empty
  // we leave the header generic.
  String? _brokerName;
  String? _verificationStatus;

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
      // Two calls — ratings + broker summary. Fire in parallel.
      final repo = ref.read(ratingsRepositoryProvider);
      final api = ref.read(apiClientProvider);
      final ratedFut = repo.list(widget.brokerId);
      final profileFut =
          api.dio.get<Map<String, dynamic>>('/brokers/${widget.brokerId}');
      final rated = await ratedFut;
      final profileRes = await profileFut;
      if (!mounted) return;
      final profile = profileRes.data;
      setState(() {
        _aggregate = rated.aggregate;
        _reviews = rated.reviews;
        _brokerName = profile?['full_name'] as String?;
        _verificationStatus = profile?['verification_status'] as String?;
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
        title: Text(_brokerName ?? t.brokerProfileTitle),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!, style: TextStyle(color: c.textMuted)),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _Header(
                        name: _brokerName ?? '—',
                        aggregate: _aggregate,
                        verificationStatus: _verificationStatus,
                      ),
                      const SizedBox(height: 24),
                      Text(t.reviewsTitle,
                          style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: 8),
                      if (_reviews.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              t.noReviewsYet,
                              style: TextStyle(color: c.textMuted),
                            ),
                          ),
                        )
                      else
                        for (final r in _reviews) ...[
                          _ReviewTile(review: r),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.aggregate,
    this.verificationStatus,
  });
  final String name;
  final RatingAggregateDto aggregate;
  final String? verificationStatus;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (verificationStatus != null)
                VerifiedBadge(status: verificationStatus!),
            ],
          ),
          const SizedBox(height: 16),
          if (aggregate.isEmpty)
            Text(t.noReviewsYet, style: TextStyle(color: c.textMuted))
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  aggregate.avg.toStringAsFixed(1),
                  style: TextStyle(
                    color: c.text,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 12),
                StarRow(value: aggregate.avg, size: 18),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              t.basedOnRatings(aggregate.count),
              style: TextStyle(color: c.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _Histogram(distribution: aggregate.distribution,
                       total: aggregate.count),
          ],
        ],
      ),
    );
  }
}

class _Histogram extends StatelessWidget {
  const _Histogram({required this.distribution, required this.total});
  final Map<String, int> distribution;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        for (final star in const ['5', '4', '3', '2', '1'])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 12,
                  child: Text(star,
                      style: TextStyle(color: c.textSubtle, fontSize: 11)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : (distribution[star] ?? 0) / total,
                      minHeight: 6,
                      backgroundColor: c.surfaceAlt,
                      valueColor: AlwaysStoppedAnimation<Color>(c.accent),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 22,
                  child: Text(
                    '${distribution[star] ?? 0}',
                    textAlign: TextAlign.end,
                    style: TextStyle(color: c.textSubtle, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});
  final RatingDto review;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = review.createdAt == null
        ? ''
        : DateFormat.yMMMd(locale).format(review.createdAt!.toLocal());
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StarRow(value: review.stars.toDouble(), size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  review.raterDisplay,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(date,
                  style: TextStyle(color: c.textSubtle, fontSize: 11)),
            ],
          ),
          if (review.note != null && review.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(review.note!, style: TextStyle(color: c.text, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

