import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/env.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../../theme.dart';
import '../../../analytics/data/models.dart' show ListingAnalyticsDto;
import '../../data/models.dart';

/// A row in the broker's own portfolio (Stitch screen 8).
///
/// Deliberately not the buyer's [ListingCard]: a broker looking at their
/// own listing needs different facts — how it is performing, whether the
/// clock is running out, and what they can do about it — so the photo
/// shrinks to a thumbnail and the space goes to numbers and actions.
class BrokerListingRow extends StatelessWidget {
  const BrokerListingRow({
    super.key,
    required this.listing,
    required this.onOpen,
    this.stats,
    this.onAnalytics,
    this.onDelete,
  });

  final ListingDto listing;
  final VoidCallback onOpen;

  /// Per-listing views/inquiries from `/brokers/me/analytics`. Null while
  /// analytics are still loading or unavailable — the row then simply
  /// omits the numbers instead of showing zeros it can't stand behind.
  final ListingAnalyticsDto? stats;
  final VoidCallback? onAnalytics;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final cover = listing.photos.isNotEmpty ? listing.photos.first : null;
    final days = listing.daysUntilExpiry();
    final expired = listing.isExpired || (days != null && days <= 0);
    final expiringSoon = !expired && days != null && days <= 5;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Thumb(cover: cover, photoCount: listing.photos.length),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _StatusPill(
                                  listing: listing,
                                  expired: expired,
                                  expiringSoon: expiringSoon,
                                ),
                                const Spacer(),
                                Text(
                                  t.listingRef(listing.id),
                                  style: TextStyle(
                                    color: c.textSubtle,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              listing.title,
                              style: TextStyle(
                                color: c.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Flexible(
                                  child: Text(
                                    listing.priceGrouped,
                                    style: TextStyle(
                                      color: c.primary,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  listing.listingKind == 'rent'
                                      ? t.currencyEgpPerMonth
                                      : t.currencyEgp,
                                  style: TextStyle(
                                    color: c.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (stats != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _Metric(
                          icon: Icons.visibility_outlined,
                          label: t.metricViews(stats!.totalViews),
                        ),
                        const SizedBox(width: 14),
                        _Metric(
                          icon: Icons.forum_outlined,
                          label: t.metricInquiries(stats!.messagesLast7d),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Expiry is the one thing a broker must act on, so it gets its
          // own strip rather than competing with the metrics row.
          if (expired || expiringSoon)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: expired ? c.rejectedBg : c.pendingBg,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  Icon(
                    expired
                        ? Icons.error_outline_rounded
                        : Icons.schedule_rounded,
                    size: 15,
                    color: expired ? c.rejected : c.pending,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      expired ? t.expiryExpired : t.expiryDaysLeft(days!),
                      style: TextStyle(
                        color: expired ? c.rejected : c.pending,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              border: Border(top: BorderSide(color: c.border)),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(13),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: Text(t.manageListing),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(38),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                if (onAnalytics != null)
                  IconButton(
                    tooltip: t.analyticsTitle,
                    onPressed: onAnalytics,
                    icon: Icon(Icons.insights_rounded, color: c.textMuted),
                  ),
                if (onDelete != null)
                  IconButton(
                    tooltip: t.delete,
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline_rounded, color: c.textMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.cover, required this.photoCount});
  final ListingPhotoDto? cover;
  final int photoCount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: 96,
      height: 76,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 96,
              height: 76,
              child: cover == null
                  ? Container(
                      color: c.surfaceAlt,
                      alignment: Alignment.center,
                      child: Icon(Icons.image_rounded,
                          color: c.textSubtle, size: 22),
                    )
                  : CachedNetworkImage(
                      imageUrl: '${Env.apiBaseUrl}${cover!.url}',
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: c.surfaceAlt),
                      errorWidget: (_, __, ___) => Container(
                        color: c.surfaceAlt,
                        alignment: Alignment.center,
                        child: Icon(Icons.image_rounded,
                            color: c.textSubtle, size: 22),
                      ),
                    ),
            ),
          ),
          if (photoCount > 0)
            PositionedDirectional(
              bottom: 4,
              start: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_library_rounded,
                        size: 10, color: Colors.white),
                    const SizedBox(width: 3),
                    Text(
                      '$photoCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.listing,
    required this.expired,
    required this.expiringSoon,
  });
  final ListingDto listing;
  final bool expired;
  final bool expiringSoon;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;

    final (String label, Color fg, Color bg, Color line, IconData icon) =
        switch (listing.status) {
      'sold' => (t.listingStatusSold, c.textMuted, c.surfaceAlt, c.border,
          Icons.handshake_outlined),
      'hidden' => (t.listingStatusHidden, c.textMuted, c.surfaceAlt, c.border,
          Icons.visibility_off_outlined),
      _ when expired => (t.listingStatusExpired, c.rejected, c.rejectedBg,
          c.rejectedLine, Icons.error_outline_rounded),
      _ when expiringSoon => (t.listingStatusExpiring, c.pending, c.pendingBg,
          c.pendingLine, Icons.schedule_rounded),
      _ => (t.listingStatusLive, c.verified, c.verifiedBg, c.verifiedLine,
          Icons.check_circle_outline_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c.textSubtle),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
              color: c.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
