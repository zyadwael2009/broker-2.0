import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/env.dart';
import '../../../../theme.dart';
import '../../../shared/widgets/star_row.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../../data/models.dart';
import 'expiry_chip.dart';

/// Compact card used in browse lists and my-listings.
///
/// When [showBroker] is true the verified badge is rendered under the title;
/// when false (broker looking at their own list) we show an [ExpiryChip]
/// instead so they can spot listings about to auto-expire.
class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.listing,
    required this.onTap,
    this.showBroker = true,
  });

  final ListingDto listing;
  final VoidCallback onTap;
  final bool showBroker;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cover = listing.photos.isNotEmpty ? listing.photos.first : null;

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                  child: cover == null
                      ? _PhotoPlaceholder(c: c)
                      : CachedNetworkImage(
                          imageUrl: '${Env.apiBaseUrl}${cover.url}',
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: c.surfaceAlt),
                          errorWidget: (_, __, ___) => _PhotoPlaceholder(c: c),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      style: TextStyle(
                        color: c.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      listing.priceDisplay,
                      style: TextStyle(
                        color: c.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.place_rounded, size: 14, color: c.textSubtle),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${listing.city}, ${listing.governorate}',
                            style: TextStyle(color: c.textMuted, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          listing.areaDisplay,
                          style: TextStyle(color: c.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (showBroker && listing.broker != null)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              listing.broker!.fullName,
                              style: TextStyle(
                                color: c.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (listing.broker!.rating.count > 0) ...[
                            const SizedBox(width: 6),
                            StarRow(value: listing.broker!.rating.avg, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              '(${listing.broker!.rating.count})',
                              style: TextStyle(color: c.textSubtle, fontSize: 11),
                            ),
                          ],
                          const SizedBox(width: 6),
                          VerifiedBadge(
                            status: listing.broker!.verificationStatus,
                            compact: true,
                          ),
                        ],
                      )
                    else
                      ExpiryChip(listing: listing),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.c});
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: c.surfaceAlt,
      alignment: Alignment.center,
      child: Icon(Icons.image_rounded, color: c.textSubtle, size: 32),
    );
  }
}
