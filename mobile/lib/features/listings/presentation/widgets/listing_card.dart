import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/env.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../../theme.dart';
import '../../../shared/widgets/star_row.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../../data/models.dart';
import 'expiry_chip.dart';
import 'favorite_button.dart';

/// The listing card from Stitch screen 3 — the unit of the browse feed,
/// the Saved tab, and a broker's public listings.
///
/// Reading order top to bottom is deliberately credential-first: what
/// this is (for sale / for rent) and whether the broker is verified sit
/// on the photo, the reference number rides the photo's bottom edge, and
/// only then comes price, title, place, specs, and who is selling it.
///
/// [showBroker] false is the owner's view (my-listings): the broker row
/// would be the user themselves, so it gives way to an [ExpiryChip] that
/// tells them when the listing needs reconfirming.
class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.listing,
    required this.onTap,
    this.showBroker = true,
    this.showFavorite = true,
  });

  final ListingDto listing;
  final VoidCallback onTap;
  final bool showBroker;
  final bool showFavorite;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final cover = listing.photos.isNotEmpty ? listing.photos.first : null;
    final isRent = listing.listingKind == 'rent';

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
              // ── Photo + overlays ──────────────────────────────────
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(13)),
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
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(13)),
                          // Keeps the white overlay text legible over a
                          // bright daylight photo without dimming the
                          // middle of the image.
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.35),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.55),
                            ],
                            stops: const [0, 0.45, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    top: 10,
                    start: 10,
                    child: _ScrimPill(
                      label: isRent ? t.listingKindRent : t.listingKindSale,
                    ),
                  ),
                  if (showBroker && listing.broker != null)
                    PositionedDirectional(
                      top: 10,
                      end: 10,
                      child: VerifiedBadge(
                        status: listing.broker!.verificationStatus,
                        compact: true,
                      ),
                    ),
                  if (showFavorite)
                    PositionedDirectional(
                      bottom: 6,
                      start: 6,
                      child: FavoriteButton(
                          listingId: listing.id, onSurface: true, size: 18),
                    ),
                  PositionedDirectional(
                    bottom: 12,
                    end: 12,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t.listingRef(listing.id),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(Icons.receipt_long_rounded,
                            size: 13, color: Colors.white),
                      ],
                    ),
                  ),
                ],
              ),

              // ── Body ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Flexible(
                                child: Text(
                                  listing.priceGrouped,
                                  style: TextStyle(
                                    color: c.primary,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                    letterSpacing: -0.3,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isRent ? t.currencyEgpPerMonth : t.currencyEgp,
                                style: TextStyle(
                                  color: c.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (listing.deliveryStatus != null)
                          _StatusPill(
                            label: listing.deliveryStatus == 'ready'
                                ? t.listingDeliveryReady
                                : t.listingDeliveryUnderConstruction,
                            ready: listing.deliveryStatus == 'ready',
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      listing.title,
                      style: TextStyle(
                        color: c.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.place_rounded, size: 14, color: c.textSubtle),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            [listing.district, listing.city, listing.governorate]
                                .whereType<String>()
                                .where((s) => s.isNotEmpty)
                                .join('، '),
                            style: TextStyle(color: c.textMuted, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _SpecStrip(listing: listing),
                    const SizedBox(height: 10),
                    if (showBroker && listing.broker != null)
                      _BrokerRow(broker: listing.broker!, onTap: onTap)
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

/// The 2-4 column facts strip: area always, then whichever of bedrooms /
/// bathrooms / floor the broker filled in. Columns are equal-width so
/// cards in a scrolling feed line up with each other.
class _SpecStrip extends StatelessWidget {
  const _SpecStrip({required this.listing});
  final ListingDto listing;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;

    final specs = <(String, String)>[
      ('${listing.areaNumber} ${t.unitM2}', t.areaLabelShort),
      if (listing.bedrooms != null)
        ('${listing.bedrooms}', t.listingBedrooms),
      if (listing.bathrooms != null)
        ('${listing.bathrooms}', t.listingBathrooms),
      if (listing.floorNumber != null)
        ('${listing.floorNumber}', t.listingFloor),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          for (final (value, label) in specs)
            Expanded(
              child: Column(
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: TextStyle(
                        color: c.textSubtle, fontSize: 10, height: 1.4),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BrokerRow extends StatelessWidget {
  const _BrokerRow({required this.broker, required this.onTap});
  final ListingBrokerDto broker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;

    return Row(
      children: [
        _BrokerAvatar(name: broker.fullName, verified: broker.verificationStatus == 'verified'),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                broker.fullName,
                style: TextStyle(
                  color: c.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (broker.rating.count > 0)
                Row(
                  children: [
                    StarRow(value: broker.rating.avg, size: 11),
                    const SizedBox(width: 4),
                    Text(
                      '${broker.rating.avg.toStringAsFixed(1)} (${broker.rating.count})',
                      style: TextStyle(color: c.textSubtle, fontSize: 11),
                    ),
                  ],
                )
              else
                Text(
                  t.brokerLicensedLabel,
                  style: TextStyle(color: c.textSubtle, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // A non-interactive affordance: the whole card is the tap target,
        // so a second button here would just be a smaller version of it.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.detailsCta,
                style: TextStyle(
                  color: c.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, size: 13, color: c.primary),
            ],
          ),
        ),
      ],
    );
  }
}

/// Initial-in-a-circle stand-in: brokers have no avatar upload in the
/// product yet, and a generic person glyph on every card would read as
/// "no one in particular".
class _BrokerAvatar extends StatelessWidget {
  const _BrokerAvatar({required this.name, required this.verified});
  final String name;
  final bool verified;

  static const double size = 32;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final trimmed = name.trim();
    // runes, not [0], so a name starting with an emoji or a surrogate
    // pair doesn't render as half a character.
    final initial =
        trimmed.isEmpty ? '؟' : String.fromCharCode(trimmed.runes.first);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: c.surfaceHigh,
              shape: BoxShape.circle,
              border: Border.all(color: c.border),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: TextStyle(
                color: c.textMuted,
                fontSize: size * 0.42,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (verified)
            PositionedDirectional(
              bottom: -2,
              end: -2,
              child: Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  color: c.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.verified_rounded,
                    size: size * 0.34, color: c.verified),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dark translucent pill for text sitting on a photo.
class _ScrimPill extends StatelessWidget {
  const _ScrimPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    );
  }
}

/// Delivery-status pill — emerald for "ready now", amber for "under
/// construction", matching the semantic statuses in the design system.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.ready});
  final String label;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = ready ? c.verified : c.pending;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: ready ? c.verifiedBg : c.pendingBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ready ? c.verifiedLine : c.pendingLine),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700, height: 1.3),
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
