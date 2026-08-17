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
import '../../auth/data/auth_repository.dart';
import '../../auth/data/models.dart' show AuthException;
import '../../auth/presentation/auth_controller.dart';
import '../../shared/widgets/inbox_icon_button.dart';
import '../../shared/widgets/language_toggle_button.dart';
import '../../shared/widgets/theme_toggle_button.dart';
import '../../shared/widgets/verified_badge.dart';
import '../../shared/widgets/verify_phone_banner.dart';
import '../data/listings_repository.dart';
import '../data/listings_signal.dart';
import '../data/models.dart';
import 'widgets/listing_card.dart';

class MyListingsScreen extends ConsumerStatefulWidget {
  const MyListingsScreen({super.key});

  @override
  ConsumerState<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends ConsumerState<MyListingsScreen> {
  bool _loading = true;
  String? _error;
  List<ListingDto> _items = const [];

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
      final items = await ref.read(listingsRepositoryProvider).mine();
      if (!mounted) return;
      setState(() {
        _items = items;
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
    final auth = ref.watch(authControllerProvider);
    final verified = auth.brokerProfile?.verificationStatus == 'verified';
    final c = context.colors;

    ref.listen<int>(listingsRevProvider, (_, __) => unawaited(_load()));

    return Scaffold(
      appBar: AppBar(
        title: Text(t.myListings),
        actions: [
          const InboxIconButton(),
          IconButton(
            tooltip: t.analyticsTitle,
            icon: const Icon(Icons.insights_rounded),
            onPressed: () => context.push(Routes.brokerAnalytics),
          ),
          IconButton(
            tooltip: t.priceTransparency,
            icon: const Icon(Icons.query_stats_rounded),
            onPressed: () => context.push(Routes.marketPrices),
          ),
          IconButton(
            tooltip: t.verifyMyStatus,
            icon: Icon(
              Icons.shield_rounded,
              color: verified ? c.verified : c.pending,
            ),
            onPressed: () => context.push(Routes.brokerVerify),
          ),
          const LanguageToggleButton(),
          const ThemeToggleButton(),
          IconButton(
            tooltip: t.signOut,
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: !verified
            ? _UnverifiedGate(status: auth.brokerProfile?.verificationStatus ?? 'pending')
            : _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!, style: TextStyle(color: c.textMuted)),
                        ),
                      )
                    : Column(
                        children: [
                          const VerifyPhoneBanner(),
                          if (auth.user != null)
                            _SharePublicProfilePill(brokerId: auth.user!.id),
                          if (auth.user?.referralCode != null)
                            _ReferralCard(code: auth.user!.referralCode!),
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: _load,
                              child: _items.isEmpty
                                  ? const _EmptyMyListings()
                                  : ListView.separated(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: _items.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                                      itemBuilder: (context, i) {
                                        final l = _items[i];
                                        return ListingCard(
                                          listing: l,
                                          showBroker: false,
                                          onTap: () async {
                                            final changed = await context.push<bool>(
                                              '${Routes.listings}/${l.id}',
                                            );
                                            if (changed == true) unawaited(_load());
                                          },
                                        );
                                      },
                                    ),
                            ),
                          ),
                        ],
                      ),
      ),
      floatingActionButton: verified
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await context.push<bool>(Routes.brokerListingsNew);
                if (created == true) unawaited(_load());
              },
              icon: const Icon(Icons.add_rounded),
              label: Text(t.newListing),
            )
          : null,
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

class _EmptyMyListings extends StatelessWidget {
  const _EmptyMyListings();

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.home_work_rounded, size: 48, color: c.textSubtle),
                  const SizedBox(height: 12),
                  Text(t.noListingsYet,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(t.noListingsHint,
                      style: TextStyle(color: c.textMuted)),
                ],
              ),
            ),
          ),
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
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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

