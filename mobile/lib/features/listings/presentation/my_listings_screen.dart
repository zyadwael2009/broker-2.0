import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/env.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../router.dart';
import '../../../theme.dart';
import '../../analytics/data/analytics_repository.dart';
import '../../analytics/data/models.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/models.dart' show AuthException;
import '../../auth/presentation/auth_controller.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/brand_app_bar.dart';
import '../../shared/widgets/verified_badge.dart';
import '../../shared/widgets/verify_phone_banner.dart';
import '../data/listings_repository.dart';
import '../data/listings_signal.dart';
import '../data/models.dart';
import 'widgets/broker_listing_row.dart';

/// Which slice of the portfolio is showing. Maps to real listing state —
/// there is no "draft" in the data model, so the tabs don't pretend
/// there is one.
enum _Bucket { live, expired, archived }

class MyListingsScreen extends ConsumerStatefulWidget {
  const MyListingsScreen({super.key});

  @override
  ConsumerState<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends ConsumerState<MyListingsScreen> {
  bool _loading = true;
  String? _error;
  List<ListingDto> _items = const [];
  AnalyticsPayloadDto? _analytics;
  _Bucket _bucket = _Bucket.live;

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
      // Listings are the screen; analytics only decorate it, so a
      // failing analytics call must not blank the portfolio.
      final analyticsFut = ref
          .read(analyticsRepositoryProvider)
          .fetchMyAnalytics()
          .then<AnalyticsPayloadDto?>((v) => v)
          .catchError((_) => null);
      final items = await ref.read(listingsRepositoryProvider).mine();
      final analytics = await analyticsFut;
      if (!mounted) return;
      setState(() {
        _items = items;
        _analytics = analytics;
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

  bool _isExpired(ListingDto l) {
    final days = l.daysUntilExpiry();
    return l.isExpired || (days != null && days <= 0);
  }

  List<ListingDto> _bucketed(_Bucket bucket) => switch (bucket) {
        _Bucket.live =>
          _items.where((l) => l.status == 'active' && !_isExpired(l)).toList(),
        _Bucket.expired =>
          _items.where((l) => l.status == 'active' && _isExpired(l)).toList(),
        _Bucket.archived =>
          _items.where((l) => l.status != 'active').toList(),
      };

  ListingAnalyticsDto? _statsFor(int listingId) {
    final rows = _analytics?.byListing;
    if (rows == null) return null;
    for (final r in rows) {
      if (r.id == listingId) return r;
    }
    return null;
  }

  Future<void> _delete(ListingDto listing) async {
    final t = AppL10n.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.deleteListingTitle),
        content: Text(t.deleteListingBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: context.colors.rejected),
            child: Text(t.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(listingsRepositoryProvider).delete(listing.id);
      if (!mounted) return;
      bumpListingsRev(ref);
      unawaited(_load());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is AuthException ? e.message : t.deleteFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final auth = ref.watch(authControllerProvider);
    final verified = auth.brokerProfile?.verificationStatus == 'verified';
    final c = context.colors;

    ref.listen<int>(listingsRevProvider, (_, __) => unawaited(_load()));

    if (!verified) {
      return Scaffold(
        appBar: const BrandAppBar(),
        bottomNavigationBar: const AppBottomNav(currentTab: AppTab.mine),
        body: SafeArea(
          child: _UnverifiedGate(
              status: auth.brokerProfile?.verificationStatus ?? 'pending'),
        ),
      );
    }

    final rows = _bucketed(_bucket);

    return Scaffold(
      appBar: const BrandAppBar(),
      bottomNavigationBar: const AppBottomNav(currentTab: AppTab.mine),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        const VerifyPhoneBanner(),
                        const SizedBox(height: 12),
                        _PortfolioHeader(
                          onAdd: () async {
                            final created = await context
                                .push<bool>(Routes.brokerListingsNew);
                            if (created == true) unawaited(_load());
                          },
                        ),
                        const SizedBox(height: 14),
                        _PerformanceCard(
                          summary: _analytics?.summary,
                          onOpenAnalytics: () =>
                              context.push(Routes.brokerAnalytics),
                        ),
                        const SizedBox(height: 14),
                        _BucketTabs(
                          current: _bucket,
                          counts: {
                            for (final b in _Bucket.values)
                              b: _bucketed(b).length,
                          },
                          onChanged: (b) => setState(() => _bucket = b),
                        ),
                        const SizedBox(height: 14),
                        if (rows.isEmpty)
                          _EmptyBucket(bucket: _bucket)
                        else
                          for (final l in rows) ...[
                            BrokerListingRow(
                              listing: l,
                              stats: _statsFor(l.id),
                              onOpen: () async {
                                final changed = await context
                                    .push<bool>('${Routes.listings}/${l.id}');
                                if (changed == true) unawaited(_load());
                              },
                              onAnalytics: () =>
                                  context.push(Routes.brokerAnalytics),
                              onDelete: () => _delete(l),
                            ),
                            const SizedBox(height: 12),
                          ],
                        const SizedBox(height: 8),
                        _WhyVerificationCard(),
                        const SizedBox(height: 12),
                        if (auth.user != null)
                          _SharePublicProfilePill(brokerId: auth.user!.id),
                        if (auth.user?.referralCode != null)
                          _ReferralCard(code: auth.user!.referralCode!),
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => context.push(Routes.brokerVerify),
                            icon: Icon(Icons.shield_rounded,
                                size: 16, color: c.verified),
                            label: Text(t.verifyMyStatus),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

/// Title block: what this screen is, and the one action that matters.
class _PortfolioHeader extends ConsumerWidget {
  const _PortfolioHeader({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context)!;
    final c = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      t.myListings,
                      style: Theme.of(context).textTheme.headlineSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const VerifiedBadge(status: 'verified', compact: true),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                t.myListingsSubtitle,
                style: TextStyle(color: c.textMuted, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
          label: Text(t.newListing),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
        ),
      ],
    );
  }
}

/// This week's numbers, straight from /brokers/me/analytics. Renders a
/// quiet placeholder rather than zeros when the call didn't land.
class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({required this.summary, required this.onOpenAnalytics});
  final AnalyticsSummaryDto? summary;
  final VoidCallback onOpenAnalytics;

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
              Container(
                width: 7,
                height: 7,
                decoration:
                    BoxDecoration(color: c.verified, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.portfolioPerformanceTitle,
                  style: TextStyle(
                      color: c.text, fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: onOpenAnalytics,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(t.seeDetails),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (summary == null)
            Text(t.analyticsError, style: TextStyle(color: c.textMuted, fontSize: 12))
          else
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    value: '${summary!.viewsLast7d}',
                    label: t.statViews7d,
                    tint: c.primary,
                  ),
                ),
                _Divider(),
                Expanded(
                  child: _Stat(
                    value: '${summary!.messagesLast7d}',
                    label: t.statInquiries7d,
                    tint: c.verified,
                  ),
                ),
                _Divider(),
                Expanded(
                  child: _Stat(
                    value: '${summary!.activeListings}',
                    label: t.statLiveListings,
                    tint: c.accent,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 34,
        color: context.colors.border,
        margin: const EdgeInsets.symmetric(horizontal: 8),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.tint});
  final String value;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
              color: tint, fontSize: 20, fontWeight: FontWeight.w700, height: 1.3),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textSubtle, fontSize: 11, height: 1.4),
          maxLines: 2,
        ),
      ],
    );
  }
}

class _BucketTabs extends StatelessWidget {
  const _BucketTabs({
    required this.current,
    required this.counts,
    required this.onChanged,
  });
  final _Bucket current;
  final Map<_Bucket, int> counts;
  final ValueChanged<_Bucket> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;

    String label(_Bucket b) => switch (b) {
          _Bucket.live => t.bucketLive(counts[b] ?? 0),
          _Bucket.expired => t.bucketExpired(counts[b] ?? 0),
          _Bucket.archived => t.bucketArchived(counts[b] ?? 0),
        };

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final b in _Bucket.values)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(b),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: b == current ? c.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label(b),
                    style: TextStyle(
                      color: b == current
                          ? (dark ? c.background : Colors.white)
                          : c.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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

class _EmptyBucket extends StatelessWidget {
  const _EmptyBucket({required this.bucket});
  final _Bucket bucket;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final (icon, title, sub) = switch (bucket) {
      _Bucket.live => (Icons.home_work_rounded, t.noListingsYet, t.noListingsHint),
      _Bucket.expired => (Icons.schedule_rounded, t.bucketEmptyExpired, t.bucketEmptyExpiredSub),
      _Bucket.archived => (Icons.inventory_2_outlined, t.bucketEmptyArchived, t.bucketEmptyArchivedSub),
    };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      decoration: BoxDecoration(
        color: c.surfaceLow,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: c.textSubtle),
          const SizedBox(height: 12),
          Text(title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(sub,
              style: TextStyle(color: c.textMuted, fontSize: 12),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Why the verified badge is worth the paperwork — the mockup's closing
/// note, kept factual: it explains what the badge means, and doesn't
/// promise engagement numbers we haven't measured.
class _WhyVerificationCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.verifiedBg,
        border: Border.all(color: c.verifiedLine),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, size: 20, color: c.verified),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.whyVerificationTitle,
                  style: TextStyle(
                      color: c.verified,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  t.whyVerificationBody,
                  style: TextStyle(color: c.textMuted, fontSize: 12, height: 1.5),
                ),
              ],
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
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Icon(Icons.wifi_off_rounded, color: c.textSubtle, size: 44),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(message,
              textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
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
    );
  }
}

class _UnverifiedGate extends StatelessWidget {
  const _UnverifiedGate({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final title = status == 'rejected'
        ? t.unverifiedRejectedTitle
        : t.unverifiedNotYetTitle;
    final sub = status == 'rejected'
        ? t.unverifiedRejectedSub
        : t.unverifiedNotYetSub;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.shield_rounded, size: 32, color: c.pending),
            ),
            const SizedBox(height: 16),
            VerifiedBadge(status: status),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted, height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(t.openVerification),
              onPressed: () => context.push(Routes.brokerVerify),
            ),
          ],
        ),
      ),
    );
  }
}

/// Persistent row that shows the broker's shareable public profile URL
/// and lets them copy it. Sits at the top of the my-listings screen
/// only for verified brokers — for anyone else the URL wouldn't work
/// anyway (the /b/<id> route 404s for unverified brokers).
class _SharePublicProfilePill extends StatelessWidget {
  const _SharePublicProfilePill({required this.brokerId});
  final int brokerId;

  String get _shareUrl {
    final base = Env.publicBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/b/$brokerId';
  }

  String get _displayHost {
    // Show a compact host+path, not the scheme; matches the visual in
    // the web credential-page URL pill.
    return _shareUrl
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceAll(RegExp(r'/+$'), '');
  }

  Future<void> _copy(BuildContext context) async {
    final t = AppL10n.of(context)!;
    await Clipboard.setData(ClipboardData(text: _shareUrl));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.sharePublicProfileCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: c.accentNavy.withValues(alpha: 0.10),
              border: Border.all(
                color: c.accentNavy.withValues(alpha: 0.25),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.link_rounded, size: 16, color: c.accentNavy),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.sharePublicProfileTitle,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.02,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _displayHost,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textMuted,
                    fontSize: 12,
                    fontFamily: 'monospace',
                    letterSpacing: 0.02,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => _copy(context),
            style: TextButton.styleFrom(
              foregroundColor: c.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(t.copy),
          ),
        ],
      ),
    );
  }
}

/// Phase G1 — referral card. Shows the broker's shareable link with
/// their `?ref=<code>` appended, a copy + WhatsApp share button, and
/// a running count of how many brokers signed up through them.
class _ReferralCard extends ConsumerStatefulWidget {
  const _ReferralCard({required this.code});
  final String code;

  @override
  ConsumerState<_ReferralCard> createState() => _ReferralCardState();
}

class _ReferralCardState extends ConsumerState<_ReferralCard> {
  int? _count;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ref.read(authRepositoryProvider).fetchReferrals();
    if (!mounted || data == null) return;
    setState(() => _count = (data['count'] as num?)?.toInt() ?? 0);
  }

  String get _refUrl {
    final base = Env.publicBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/?ref=${widget.code}';
  }

  Future<void> _copy() async {
    final t = AppL10n.of(context)!;
    await Clipboard.setData(ClipboardData(text: _refUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.referralCopied)),
    );
  }

  Future<void> _shareWhatsApp() async {
    final t = AppL10n.of(context)!;
    final body = '${t.referralShareText}\n$_refUrl';
    final wa = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(body)}');
    try {
      await launchUrl(wa, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.whatsappOpenFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;

    final displayUrl = _refUrl.replaceFirst(RegExp(r'^https?://'), '');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.12),
                  border: Border.all(color: c.accent.withValues(alpha: 0.28)),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.card_giftcard_rounded, size: 16, color: c.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t.referralTitle,
                  style: TextStyle(color: c.text, fontSize: 13,
                      fontWeight: FontWeight.w700, letterSpacing: 0.02),
                ),
              ),
              if (_count != null && _count! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.verifiedBg,
                    border: Border.all(color: c.verifiedLine),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    t.referralJoinedCount(_count!),
                    style: TextStyle(color: c.verified, fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            displayUrl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.textMuted, fontSize: 12,
                fontFamily: 'monospace', letterSpacing: 0.02),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.link_rounded, size: 16),
                  label: Text(t.copy),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _shareWhatsApp,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: Text(t.shareWhatsApp),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
