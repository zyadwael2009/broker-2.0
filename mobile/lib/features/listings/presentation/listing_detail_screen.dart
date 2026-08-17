import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/env.dart';
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
      final l = await ref.read(listingsRepositoryProvider).get(widget.listingId);
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
    final auth = ref.watch(authControllerProvider);
    final myId = auth.user?.id;
    final isOwner =
        _listing != null && myId != null && _listing!.broker?.id == myId;
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
        title: Text(_listing?.title ?? AppL10n.of(context)!.brokerLabel),
        actions: [
          if (_listing != null)
            PopupMenuButton<String>(
              tooltip: AppL10n.of(context)!.more,
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
                      Text(AppL10n.of(context)!.shareWhatsApp),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'share',
                  child: Row(
                    children: [
                      const Icon(Icons.share_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(AppL10n.of(context)!.shareLink),
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
                        Text(AppL10n.of(context)!.reportListing),
                      ],
                    ),
                  ),
              ],
            ),
          if ((isOwner || (isAdmin && !isOwner)) && _listing != null)
            IconButton(
              tooltip: AppL10n.of(context)!.delete,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _acting ? null : _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!, style: TextStyle(color: context.colors.textMuted)),
                    ),
                  )
                : _Body(
                    listing: _listing!,
                    isOwner: isOwner,
                    onConfirm: _acting ? null : _confirm,
                    onCallBroker: () => _callBroker(_listing!.broker!.phone),
                    acting: _acting,
                  ),
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


class _Body extends ConsumerWidget {
  const _Body({
    required this.listing,
    required this.isOwner,
    required this.onConfirm,
    required this.onCallBroker,
    required this.acting,
  });
  final ListingDto listing;
  final bool isOwner;
  final VoidCallback? onConfirm;
  final VoidCallback onCallBroker;
  final bool acting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final df = DateFormat.yMMMd(localeTag);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        PhotoCarousel(photos: listing.photos),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                listing.title,
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
                          .join(', '),
                      style: TextStyle(color: c.textMuted, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.priceLabel,
                              style: Theme.of(context).textTheme.labelSmall),
                          const SizedBox(height: 4),
                          Text(
                            listing.priceDisplay,
                            style: TextStyle(
                              color: c.primary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1, height: 36, color: c.border,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.areaLabel,
                              style: Theme.of(context).textTheme.labelSmall),
                          const SizedBox(height: 4),
                          Text(
                            listing.areaDisplay,
                            style: TextStyle(
                              color: c.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1, height: 36, color: c.border,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.typeLabel,
                              style: Theme.of(context).textTheme.labelSmall),
                          const SizedBox(height: 4),
                          Text(
                            _typeLabel(listing.propertyType, t),
                            style: TextStyle(
                              color: c.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _ListingFactsRow(listing: listing),
              if (isOwner) ExpiryChip(listing: listing),
              if (listing.description != null &&
                  listing.description!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(t.aboutLabel,
                    style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 8),
                Text(
                  listing.description!,
                  style: TextStyle(color: c.text, height: 1.5),
                ),
              ],
              const SizedBox(height: 24),
              DocumentsSection(listingId: listing.id, isOwner: isOwner),
              if (listing.broker != null) ...[
                const SizedBox(height: 24),
                Text(t.brokerLabel,
                    style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => context.push(
                    '${Routes.brokerProfile}/${listing.broker!.id}',
                  ),
                  onLongPress: () => unawaited(showReportDialog(
                    context, ref,
                    targetType: ReportTargetTypes.broker,
                    targetId: listing.broker!.id,
                    targetLabel: listing.broker!.fullName,
                  )),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                listing.broker!.fullName,
                                style: TextStyle(
                                  color: c.text,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                listing.broker!.phone,
                                style: TextStyle(color: c.textMuted, fontSize: 13),
                              ),
                              if (listing.broker!.rating.count > 0) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    StarRow(
                                        value: listing.broker!.rating.avg,
                                        size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${listing.broker!.rating.avg.toStringAsFixed(1)} · '
                                      '(${listing.broker!.rating.count})',
                                      style: TextStyle(
                                          color: c.textMuted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        VerifiedBadge(
                            status: listing.broker!.verificationStatus),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (isOwner) ...[
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check_rounded),
                        label: Text(t.stillAvailable),
                        onPressed: onConfirm,
                      ),
                    ),
                  ],
                ),
              ] else if (listing.broker != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.forum_rounded),
                        label: Text(t.messageBroker),
                        onPressed: () => _openConversation(context, listing.id),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.phone_rounded),
                        label: Text(t.callBroker),
                        onPressed: onCallBroker,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  t.buyerCallDisclaimer,
                  style: TextStyle(color: c.textSubtle, fontSize: 11, height: 1.5),
                ),
              ],
              const SizedBox(height: 24),
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

  String _typeLabel(String kind, AppL10n t) => switch (kind) {
        'apartment' => t.propertyApartment,
        'house' => t.propertyHouse,
        'villa' => t.propertyVilla,
        'land' => t.propertyLand,
        'commercial' => t.propertyCommercial,
        _ => kind,
      };
}

/// Compact facts strip — sale/rent + bedrooms/bathrooms/floor/furnished/
/// delivery/compound. Only renders items that are set; hides entirely
/// if nothing meaningful to show.
class _ListingFactsRow extends StatelessWidget {
  const _ListingFactsRow({required this.listing});
  final ListingDto listing;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final chips = <Widget>[];

    // Sale/Rent kind chip — semantic (verified emerald for rent).
    final isRent = listing.listingKind == 'rent';
    chips.add(_Chip(
      text: isRent ? t.listingKindRent : t.listingKindSale,
      color: isRent ? c.verified : c.primary,
      bg: isRent ? c.verifiedBg : c.surfaceAlt,
      strong: true,
    ));

    if (listing.bedrooms != null) {
      chips.add(_Chip(text: '${listing.bedrooms} ${t.listingBedrooms.toLowerCase()}', color: c.text, bg: c.surfaceAlt));
    }
    if (listing.bathrooms != null) {
      chips.add(_Chip(text: '${listing.bathrooms} ${t.listingBathrooms.toLowerCase()}', color: c.text, bg: c.surfaceAlt));
    }
    if (listing.floorNumber != null) {
      chips.add(_Chip(text: '${t.listingFloor} ${listing.floorNumber}', color: c.text, bg: c.surfaceAlt));
    }
    if (listing.isFurnished != null) {
      chips.add(_Chip(
        text: listing.isFurnished! ? t.listingFurnishedLabel : '${t.listingFurnishedLabel}: ${t.listingFurnishedNo}',
        color: c.text, bg: c.surfaceAlt,
      ));
    }
    if (listing.deliveryStatus != null) {
      chips.add(_Chip(
        text: listing.deliveryStatus == 'ready'
            ? t.listingDeliveryReady
            : t.listingDeliveryUnderConstruction,
        color: c.text, bg: c.surfaceAlt,
      ));
    }
    if (listing.compoundName != null && listing.compoundName!.isNotEmpty) {
      chips.add(_Chip(text: listing.compoundName!, color: c.accentNavy, bg: c.surface, strong: true));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color, required this.bg, this.strong = false});
  final String text;
  final Color color;
  final Color bg;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
  }
}

