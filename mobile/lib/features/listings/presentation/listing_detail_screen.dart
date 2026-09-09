import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/env.dart';
import '../../../core/bidi.dart';
import '../../../core/nav.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../router.dart';
import '../../../theme.dart';
import '../../auth/data/models.dart' show AuthException;
import '../../auth/presentation/auth_controller.dart';
import '../../documents/presentation/documents_section.dart';
import '../../messaging/data/messaging_repository.dart';
import '../../reports/data/models.dart' show ReportTargetTypes;
import '../../reports/presentation/report_dialog.dart';
import '../../shared/widgets/star_row.dart';
import '../../shared/widgets/verified_badge.dart';
import '../data/listings_repository.dart';
import '../data/listings_signal.dart';
import '../data/models.dart';
import 'widgets/expiry_chip.dart';
import 'widgets/favorite_button.dart';
import 'widgets/photo_carousel.dart';

class ListingDetailScreen extends ConsumerStatefulWidget {
  const ListingDetailScreen({super.key, required this.listingId});
  final int listingId;

  @override
  ConsumerState<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  bool _loading = true;
  bool _acting = false;
  ListingDto? _listing;
  String? _error;
  bool _dirty = false;

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
      final l = await ref.read(listingsRepositoryProvider)
          .get(widget.listingId, usePublic: Env.screenshotMode);
      if (!mounted) return;
      setState(() {
        _listing = l;
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

  Future<void> _confirm() async {
    final t = AppL10n.of(context)!;
    setState(() => _acting = true);
    try {
      final updated =
          await ref.read(listingsRepositoryProvider).confirm(widget.listingId);
      if (!mounted) return;
      setState(() {
        _listing = updated;
        _acting = false;
        _dirty = true;
      });
      bumpListingsRev(ref);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.confirmedStillAvailable)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _acting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is AuthException ? e.message : t.confirmFailed)),
      );
    }
  }

  Future<void> _delete() async {
    final t = AppL10n.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.deleteListingTitle),
        content: Text(t.deleteListingBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: context.colors.rejected),
            child: Text(t.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _acting = true);
    try {
      await ref.read(listingsRepositoryProvider).delete(widget.listingId);
      if (!mounted) return;
      bumpListingsRev(ref);
      safePop<bool>(
        context,
        forRole: ref.read(authControllerProvider).user,
        result: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _acting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is AuthException ? e.message : t.deleteFailed)),
      );
    }
  }

  void _openReportListing() {
    final l = _listing;
    if (l == null) return;
    unawaited(showReportDialog(
      context, ref,
      targetType: ReportTargetTypes.listing,
      targetId: l.id,
      targetLabel: l.title,
    ));
  }

  /// Copies the public HTTPS share URL to clipboard so the user can
  /// paste it into WhatsApp / SMS / anywhere. The URL renders as a
  /// server-rendered SEO page (see backend/app/public/routes.py) so
  /// recipients without the app still see the listing.
  Future<void> _shareListing() async {
    final l = _listing;
    if (l == null) return;
    final base = Env.publicBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final url = '$base/l/${l.id}';
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    final t = AppL10n.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.linkCopied)),
    );
  }

  /// Open WhatsApp with a pre-composed message + listing URL. Egyptians
  /// live in WhatsApp — this is our highest-ROI share path.
  Future<void> _shareToWhatsApp() async {
    final l = _listing;
    if (l == null) return;
    final base = Env.publicBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final url = '$base/l/${l.id}';
    final text = '${l.title} — ${l.priceDisplay} · ${l.city}, ${l.governorate}';
    final wa = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent("$text\n$url")}',
    );
    try {
      final ok = await launchUrl(wa, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        final t = AppL10n.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.whatsappOpenFailed)),
        );
      }
    } catch (_) {
      if (mounted) {
        final t = AppL10n.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.whatsappOpenFailed)),
        );
      }
    }
  }

  Future<void> _callBroker(String phone) async {
    final t = AppL10n.of(context)!;
    final uri = Uri.parse('tel:$phone');
    try {
      final ok = await launchUrl(uri);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.noDialer)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.dialerOpenFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final auth = ref.watch(authControllerProvider);
    final myId = auth.user?.id;
    final listing = _listing;
    final isOwner = listing != null && myId != null && listing.broker?.id == myId;
    final isAdmin = auth.user?.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => safePop<bool>(
            context,
            forRole: auth.user,
            result: _dirty,
          ),
        ),
        // The screen is an audit view, not just a photo page — the title
        // says so, and the property's own name leads the body below.
        title: Text(t.listingAuditTitle),
        actions: [
          if (listing != null)
            PopupMenuButton<String>(
              tooltip: t.more,
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) {
                if (v == 'share') _shareListing();
                if (v == 'whatsapp') _shareToWhatsApp();
                if (v == 'report') _openReportListing();
              },
              itemBuilder: (ctx) => [
                PopupMenuItem<String>(
                  value: 'whatsapp',
                  child: Row(
                    children: [
                      // WhatsApp green so the item is unmissable in the menu.
                      const Icon(Icons.chat_bubble_outline_rounded,
                          size: 18, color: Color(0xFF25D366)),
                      const SizedBox(width: 8),
                      Text(t.shareWhatsApp),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'share',
                  child: Row(
                    children: [
                      const Icon(Icons.share_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(t.shareLink),
                    ],
                  ),
                ),
                // Report is meaningless on your own listing — hide it there.
                if (!isOwner)
                  PopupMenuItem<String>(
                    value: 'report',
                    child: Row(
                      children: [
                        const Icon(Icons.flag_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text(t.reportListing),
                      ],
                    ),
                  ),
              ],
            ),
          if ((isOwner || (isAdmin && !isOwner)) && listing != null)
            IconButton(
              tooltip: t.delete,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _acting ? null : _delete,
            ),
        ],
      ),
      bottomNavigationBar: listing == null
          ? null
          : _ActionBar(
              listing: listing,
              isOwner: isOwner,
              acting: _acting,
              onConfirm: _acting ? null : _confirm,
              onCall: () {
                final phone = listing.broker?.phone;
                if (phone != null) _callBroker(phone);
              },
            ),
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!,
                          style: TextStyle(color: context.colors.textMuted)),
                    ),
                  )
                : _Body(listing: listing!, isOwner: isOwner),
      ),
    );
  }
}

Future<void> _openConversation(BuildContext context, int listingId) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final t = AppL10n.of(context)!;
  try {
    final thread = await container
        .read(messagingRepositoryProvider)
        .startOrGetThread(listingId);
    if (!context.mounted) return;
    // Fire-and-forget navigation — awaiting would keep the caller
    // suspended until the user returns from the thread screen.
    unawaited(context.push('${Routes.messages}/${thread.id}', extra: thread));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e is AuthException ? e.message : t.cannotStartConversation)),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.listing, required this.isOwner});
  final ListingDto listing;
  final bool isOwner;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

/// The three panes under the fold. Documents come first for a buyer:
/// this screen exists to answer "is the paperwork real?", and a
/// description they can already skim on the card shouldn't outrank it.
enum _Pane { documents, description, broker }

class _BodyState extends ConsumerState<_Body> {
  _Pane _pane = _Pane.documents;

  Future<void> _openInMaps(double lat, double lng) async {
    final t = AppL10n.of(context)!;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.mapOpenFailed)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.mapOpenFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final df = DateFormat.yMMMd(localeTag);
    final isRent = listing.listingKind == 'rent';
    final broker = listing.broker;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── Hero ────────────────────────────────────────────────────
        Stack(
          children: [
            PhotoCarousel(photos: listing.photos, showCounter: true),
            if (broker != null)
              PositionedDirectional(
                top: 12,
                end: 12,
                child: VerifiedBadge(status: broker.verificationStatus),
              ),
            PositionedDirectional(
              bottom: 10,
              end: 10,
              child: FavoriteButton(listingId: listing.id, onSurface: true),
            ),
          ],
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Reference + kind + rating ─────────────────────────
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Tag(
                    label: isRent ? t.listingKindRent : t.listingKindSale,
                    fg: isRent ? c.verified : c.primary,
                    bg: isRent ? c.verifiedBg : c.primary.withValues(alpha: 0.14),
                    line: isRent ? c.verifiedLine : c.primary.withValues(alpha: 0.4),
                  ),
                  _Tag(
                    label: t.listingRef(listing.id),
                    fg: c.textMuted,
                    bg: c.surfaceAlt,
                    line: c.border,
                    icon: Icons.receipt_long_rounded,
                  ),
                  if (broker != null && broker.rating.count > 0)
                    _Tag(
                      label: t.brokerRatingTag(
                          broker.rating.avg.toStringAsFixed(1), broker.rating.count),
                      fg: c.accent,
                      bg: c.surfaceAlt,
                      line: c.border,
                      icon: Icons.star_rounded,
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Price ─────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      listing.priceGrouped,
                      style: TextStyle(
                        color: c.primary,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isRent ? t.currencyEgpPerMonth : t.currencyEgp,
                    style: TextStyle(
                      color: c.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (listing.deliveryStatus != null)
                    _Tag(
                      label: listing.deliveryStatus == 'ready'
                          ? t.listingDeliveryReady
                          : t.listingDeliveryUnderConstruction,
                      fg: listing.deliveryStatus == 'ready' ? c.verified : c.pending,
                      bg: listing.deliveryStatus == 'ready'
                          ? c.verifiedBg
                          : c.pendingBg,
                      line: listing.deliveryStatus == 'ready'
                          ? c.verifiedLine
                          : c.pendingLine,
                    ),
                ],
              ),
              const SizedBox(height: 8),

              Text(
                listing.title,
                textDirection: directionOf(listing.title),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.place_rounded, size: 16, color: c.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      [listing.district, listing.city, listing.governorate]
                          .whereType<String>()
                          .where((s) => s.isNotEmpty)
                          .join('، '),
                      style: TextStyle(color: c.textMuted, fontSize: 13),
                    ),
                  ),
                  if (listing.lat != null && listing.lng != null)
                    TextButton.icon(
                      onPressed: () => _openInMaps(listing.lat!, listing.lng!),
                      icon: const Icon(Icons.map_outlined, size: 16),
                      label: Text(t.viewOnMap),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
              if (listing.compoundName != null &&
                  listing.compoundName!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _Tag(
                  label: '${t.listingCompound}: ${listing.compoundName!}',
                  fg: c.accentNavy,
                  bg: c.surfaceAlt,
                  line: c.border,
                  icon: Icons.apartment_rounded,
                ),
              ],
              const SizedBox(height: 16),

              // ── Spec grid ─────────────────────────────────────────
              _SpecGrid(listing: listing),

              if (widget.isOwner) ...[
                const SizedBox(height: 12),
                ExpiryChip(listing: listing),
              ],
              const SizedBox(height: 20),

              // ── Panes ─────────────────────────────────────────────
              _PaneTabs(
                current: _pane,
                onChanged: (p) => setState(() => _pane = p),
              ),
              const SizedBox(height: 14),
              switch (_pane) {
                _Pane.documents =>
                  DocumentsSection(listingId: listing.id, isOwner: widget.isOwner),
                _Pane.description => _DescriptionPane(listing: listing),
                _Pane.broker => _BrokerPane(listing: listing),
              },

              // ── Location ──────────────────────────────────────────
              if (listing.lat != null && listing.lng != null) ...[
                const SizedBox(height: 22),
                _LocationCard(
                  listing: listing,
                  onOpen: () => _openInMaps(listing.lat!, listing.lng!),
                ),
              ],

              const SizedBox(height: 20),
              Text(
                listing.createdAt != null
                    ? t.postedOn(df.format(listing.createdAt!.toLocal()))
                    : t.postedRecently,
                style: TextStyle(color: c.textSubtle, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 2-column grid of the facts a buyer scans before reading anything:
/// area, bedrooms, bathrooms, floor, furnishing, property type. Only
/// renders the ones the broker actually filled in.
class _SpecGrid extends StatelessWidget {
  const _SpecGrid({required this.listing});
  final ListingDto listing;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final specs = <(IconData, String, String)>[
      (Icons.straighten_rounded, t.areaLabelShort,
          '${listing.areaNumber} ${t.unitM2}'),
      (Icons.home_work_outlined, t.typeLabelShort,
          _typeLabel(listing.propertyType, t)),
      if (listing.bedrooms != null)
        (Icons.bed_rounded, t.listingBedrooms, '${listing.bedrooms}'),
      if (listing.bathrooms != null)
        (Icons.bathtub_outlined, t.listingBathrooms, '${listing.bathrooms}'),
      if (listing.floorNumber != null)
        (Icons.stairs_outlined, t.listingFloor, '${listing.floorNumber}'),
      if (listing.isFurnished != null)
        (Icons.chair_outlined, t.listingFurnishedLabel,
            listing.isFurnished! ? t.listingFurnishedYes : t.listingFurnishedNo),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (icon, label, value) in specs)
          _SpecTile(icon: icon, label: label, value: value),
      ],
    );
  }

  static String _typeLabel(String kind, AppL10n t) => switch (kind) {
        'apartment' => t.propertyApartment,
        'house' => t.propertyHouse,
        'villa' => t.propertyVilla,
        'land' => t.propertyLand,
        'commercial' => t.propertyCommercial,
        _ => kind,
      };
}

class _SpecTile extends StatelessWidget {
  const _SpecTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Two per row at typical phone widths, one per row on very narrow
    // screens — computed from the parent width minus the 16px screen
    // insets and the 10px inter-tile gap.
    final width = (MediaQuery.of(context).size.width - 32 - 10) / 2;

    return Container(
      width: width < 150 ? double.infinity : width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: c.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(color: c.textSubtle, fontSize: 11, height: 1.3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  value,
                  style: TextStyle(
                      color: c.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.4),
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

class _PaneTabs extends StatelessWidget {
  const _PaneTabs({required this.current, required this.onChanged});
  final _Pane current;
  final ValueChanged<_Pane> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;

    String label(_Pane p) => switch (p) {
          _Pane.documents => t.paneDocuments,
          _Pane.description => t.paneDescription,
          _Pane.broker => t.paneBroker,
        };

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          for (final p in _Pane.values)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(p),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: p == current ? c.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: p == current ? c.border : Colors.transparent,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label(p),
                    style: TextStyle(
                      color: p == current ? c.text : c.textMuted,
                      fontSize: 13,
                      fontWeight: p == current ? FontWeight.w700 : FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DescriptionPane extends StatelessWidget {
  const _DescriptionPane({required this.listing});
  final ListingDto listing;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final body = listing.description;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: body == null || body.isEmpty
          ? Text(t.noDescription, style: TextStyle(color: c.textMuted))
          : Text(
              body,
              textDirection: directionOf(body),
              style: TextStyle(color: c.text, height: 1.6),
            ),
    );
  }
}

/// The broker card — who is selling this, and the one tap to their full
/// trust file.
class _BrokerPane extends ConsumerWidget {
  const _BrokerPane({required this.listing});
  final ListingDto listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final broker = listing.broker;

    if (broker == null) {
      return Text(t.brokerUnavailable, style: TextStyle(color: c.textMuted));
    }

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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      broker.fullName,
                      style: TextStyle(
                          color: c.text, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    if (broker.phone != null)
                      Text(broker.phone!,
                          style: TextStyle(color: c.textMuted, fontSize: 13)),
                    if (broker.rating.count > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          StarRow(value: broker.rating.avg, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            '${broker.rating.avg.toStringAsFixed(1)} · '
                            '(${broker.rating.count})',
                            style: TextStyle(color: c.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              VerifiedBadge(status: broker.verificationStatus),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(
                    '${Routes.brokerProfile}/${broker.id}',
                  ),
                  icon: const Icon(Icons.badge_outlined, size: 18),
                  label: Text(t.viewTrustFile),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: t.reportBroker,
                onPressed: () => unawaited(showReportDialog(
                  context, ref,
                  targetType: ReportTargetTypes.broker,
                  targetId: broker.id,
                  targetLabel: broker.fullName,
                )),
                icon: Icon(Icons.flag_outlined, color: c.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            t.buyerCallDisclaimer,
            style: TextStyle(color: c.textSubtle, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Coordinates the broker pinned, with a hand-off to the phone's map app.
/// No embedded map tile: that needs a billed Maps key, and a fake-looking
/// grey rectangle would undercut the "verified location" claim.
class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.listing, required this.onOpen});
  final ListingDto listing;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;

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
          Row(
            children: [
              Icon(Icons.my_location_rounded, size: 18, color: c.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.locationSectionTitle,
                  style: TextStyle(
                      color: c.text, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Icon(Icons.place_rounded, size: 16, color: c.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${listing.lat!.toStringAsFixed(5)}, '
                    '${listing.lng!.toStringAsFixed(5)}',
                    style: TextStyle(
                      color: c.textMuted,
                      fontSize: 12,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(t.openInMaps),
          ),
        ],
      ),
    );
  }
}

/// Sticky CTA bar. Buyers get "message" + "call"; the owning broker gets
/// the reconfirm action that keeps the listing from auto-expiring.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.listing,
    required this.isOwner,
    required this.acting,
    required this.onConfirm,
    required this.onCall,
  });

  final ListingDto listing;
  final bool isOwner;
  final bool acting;
  final VoidCallback? onConfirm;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;

    final Widget content;
    if (isOwner) {
      content = FilledButton.icon(
        onPressed: onConfirm,
        icon: const Icon(Icons.check_rounded),
        label: Text(t.stillAvailable),
      );
    } else if (listing.broker != null) {
      content = Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onCall,
              icon: const Icon(Icons.phone_rounded, size: 18),
              label: Text(t.callBroker),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: () => _openConversation(context, listing.id),
              icon: const Icon(Icons.forum_rounded, size: 18),
              label: Text(t.messageBroker),
            ),
          ),
        ],
      );
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: content,
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.fg,
    required this.bg,
    required this.line,
    this.icon,
  });
  final String label;
  final Color fg;
  final Color bg;
  final Color line;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
                color: fg, fontSize: 12, fontWeight: FontWeight.w700, height: 1.3),
          ),
        ],
      ),
    );
  }
}
