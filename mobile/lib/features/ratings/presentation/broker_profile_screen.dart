import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../router.dart';
import '../../../theme.dart';
import '../../auth/data/models.dart' show AuthException;
import '../../broker/data/broker_repository.dart';
import '../../broker/data/models.dart';
import '../../listings/data/listings_repository.dart';
import '../../listings/data/models.dart' show ListingDto;
import '../../listings/presentation/widgets/listing_card.dart';
import '../../shared/widgets/star_row.dart';
import '../../shared/widgets/verified_badge.dart';
import '../data/models.dart';
import '../data/ratings_repository.dart';

/// The broker's public trust file — the screen a buyer opens to decide
/// whether to call a stranger about several million pounds.
///
/// Everything here is a checkable credential (registry number, admin
/// verification, real ratings from real threads, live listing count).
/// Nothing is a self-declared marketing claim, because a self-declared
/// claim is exactly what this product exists to replace.
class BrokerProfileScreen extends ConsumerStatefulWidget {
  const BrokerProfileScreen({super.key, required this.brokerId});
  final int brokerId;

  @override
  ConsumerState<BrokerProfileScreen> createState() =>
      _BrokerProfileScreenState();
}

enum _Tab { listings, reviews }

class _BrokerProfileScreenState extends ConsumerState<BrokerProfileScreen> {
  bool _loading = true;
  String? _error;
  BrokerPublicProfileDto? _profile;
  RatingAggregateDto _aggregate = RatingAggregateDto.empty();
  List<RatingDto> _reviews = const [];
  List<ListingDto> _listings = const [];
  _Tab _tab = _Tab.listings;

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
      // Profile, ratings and listings are independent reads — fire them
      // together so the screen isn't three round-trips deep.
      final profileFut =
          ref.read(brokerRepositoryProvider).fetchPublicProfile(widget.brokerId);
      final ratedFut = ref.read(ratingsRepositoryProvider).list(widget.brokerId);
      final listingsFut = ref
          .read(listingsRepositoryProvider)
          .browse(brokerId: widget.brokerId);

      final profile = await profileFut;
      final rated = await ratedFut;
      final listings = await listingsFut;
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _aggregate = rated.aggregate;
        _reviews = rated.reviews;
        _listings = listings;
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

  Future<void> _call(String phone) async {
    final t = AppL10n.of(context)!;
    try {
      final ok = await launchUrl(Uri.parse('tel:$phone'));
      if (!ok && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.noDialer)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.dialerOpenFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final profile = _profile;

    return Scaffold(
      appBar: AppBar(title: Text(profile?.fullName ?? t.brokerProfileTitle)),
      bottomNavigationBar: profile?.phone == null
          ? null
          : Container(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: FilledButton.icon(
                onPressed: () => _call(profile!.phone!),
                icon: const Icon(Icons.phone_rounded, size: 18),
                label: Text(t.callBroker),
              ),
            ),
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!, style: TextStyle(color: c.textMuted)),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        _IdentityCard(
                          profile: profile!,
                          listingCount: _listings.length,
                        ),
                        const SizedBox(height: 16),
                        _TrustMetricsCard(
                          aggregate: _aggregate,
                          profile: profile,
                        ),
                        const SizedBox(height: 16),
                        _TabBarRow(
                          current: _tab,
                          listingCount: _listings.length,
                          reviewCount: _aggregate.count,
                          onChanged: (v) => setState(() => _tab = v),
                        ),
                        const SizedBox(height: 14),
                        if (_tab == _Tab.listings)
                          ..._listingsPane(t, c)
                        else
                          ..._reviewsPane(t, c),
                      ],
                    ),
                  ),
      ),
    );
  }

  List<Widget> _listingsPane(AppL10n t, AppColors c) {
    if (_listings.isEmpty) {
      return [_EmptyPane(icon: Icons.apartment_rounded, message: t.brokerNoListings)];
    }
    return [
      for (final l in _listings) ...[
        ListingCard(
          listing: l,
          onTap: () => context.push('${Routes.listings}/${l.id}'),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  List<Widget> _reviewsPane(AppL10n t, AppColors c) {
    if (_reviews.isEmpty) {
      return [_EmptyPane(icon: Icons.reviews_outlined, message: t.noReviewsYet)];
    }
    return [
      for (final r in _reviews) ...[
        _ReviewTile(review: r),
        const SizedBox(height: 10),
      ],
    ];
  }
}

/// Who this is, and the credentials that back it.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.profile, required this.listingCount});
  final BrokerPublicProfileDto profile;
  final int listingCount;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final trimmed = profile.fullName.trim();
    final initial =
        trimmed.isEmpty ? '؟' : String.fromCharCode(trimmed.runes.first);

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
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: c.surfaceHigh,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.border),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: c.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (profile.isVerified)
                    PositionedDirectional(
                      bottom: -2,
                      end: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration:
                            BoxDecoration(color: c.surface, shape: BoxShape.circle),
                        child: Icon(Icons.verified_rounded,
                            size: 20, color: c.verified),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.brokerLicensedLabel,
                      style: TextStyle(color: c.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    VerifiedBadge(status: profile.verificationStatus),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (profile.goeicRegistrationNumber != null)
                _CredentialChip(
                  icon: Icons.badge_outlined,
                  label: t.brokerGoeicChip(profile.goeicRegistrationNumber!),
                  // The number is the one credential a buyer can go and
                  // check for themselves — make it copyable.
                  onTap: () async {
                    await Clipboard.setData(
                      ClipboardData(text: profile.goeicRegistrationNumber!),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t.copiedToClipboard)),
                    );
                  },
                ),
              if (profile.memberSince != null)
                _CredentialChip(
                  icon: Icons.calendar_month_outlined,
                  label: t.brokerMemberSince(
                    DateFormat.yMMM(localeTag)
                        .format(profile.memberSince!.toLocal()),
                  ),
                ),
              _CredentialChip(
                icon: Icons.apartment_rounded,
                label: t.brokerLiveListings(listingCount),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Rating average, distribution, and the counts that give them weight.
class _TrustMetricsCard extends StatelessWidget {
  const _TrustMetricsCard({required this.aggregate, required this.profile});
  final RatingAggregateDto aggregate;
  final BrokerPublicProfileDto profile;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
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
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 18, color: c.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.brokerTrustMetrics,
                  style: TextStyle(
                      color: c.text, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (aggregate.isEmpty)
            Text(t.noReviewsYet, style: TextStyle(color: c.textMuted))
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      aggregate.avg.toStringAsFixed(1),
                      style: TextStyle(
                        color: c.accent,
                        fontSize: 38,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    StarRow(value: aggregate.avg, size: 15),
                    const SizedBox(height: 6),
                    Text(
                      t.basedOnRatings(aggregate.count),
                      style: TextStyle(color: c.textMuted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _Histogram(
                    distribution: aggregate.distribution,
                    total: aggregate.count,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 14),
          Divider(color: c.border, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.verified_user_outlined,
                  value: profile.isVerified ? t.statusVerified : t.statusPending,
                  label: t.brokerAdminChecked,
                  tint: profile.isVerified ? c.verified : c.pending,
                ),
              ),
              Expanded(
                child: _MiniStat(
                  icon: Icons.apartment_rounded,
                  value: '${profile.activeListingCount}',
                  label: t.brokerLiveListingsLabel,
                  tint: c.primary,
                ),
              ),
              Expanded(
                child: _MiniStat(
                  icon: Icons.forum_outlined,
                  value: '${aggregate.count}',
                  label: t.brokerRatedThreads,
                  tint: c.accentNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            t.brokerMetricsHonestNote,
            style: TextStyle(color: c.textSubtle, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.tint,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Icon(icon, size: 18, color: tint),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
              color: c.text, fontSize: 13, fontWeight: FontWeight.w700, height: 1.3),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textSubtle, fontSize: 10, height: 1.4),
          maxLines: 2,
        ),
      ],
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
                  width: 34,
                  child: Text(
                    total == 0
                        ? '0%'
                        : '${(((distribution[star] ?? 0) / total) * 100).round()}%',
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

class _TabBarRow extends StatelessWidget {
  const _TabBarRow({
    required this.current,
    required this.listingCount,
    required this.reviewCount,
    required this.onChanged,
  });
  final _Tab current;
  final int listingCount;
  final int reviewCount;
  final ValueChanged<_Tab> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;

    Widget tab(_Tab value, IconData icon, String label) {
      final active = value == current;
      return Expanded(
        child: InkWell(
          onTap: () => onChanged(value),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? c.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 16,
                    color: active ? (dark ? c.background : Colors.white) : c.textMuted),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: active
                          ? (dark ? c.background : Colors.white)
                          : c.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          tab(_Tab.listings, Icons.apartment_rounded,
              t.brokerTabListings(listingCount)),
          tab(_Tab.reviews, Icons.reviews_outlined,
              t.brokerTabReviews(reviewCount)),
        ],
      ),
    );
  }
}

class _CredentialChip extends StatelessWidget {
  const _CredentialChip({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                color: c.text, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            Icon(Icons.copy_rounded, size: 13, color: c.textSubtle),
          ],
        ],
      ),
    );

    if (onTap == null) return chip;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: chip,
    );
  }
}

class _EmptyPane extends StatelessWidget {
  const _EmptyPane({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 40, color: c.textSubtle),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(color: c.textMuted)),
        ],
      ),
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
