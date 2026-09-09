import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../router.dart';
import '../../../theme.dart';
import '../../auth/data/models.dart' show AuthException;
import '../../auth/presentation/auth_controller.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/brand_app_bar.dart';
import '../data/messaging_repository.dart';
import '../data/models.dart';
import '../data/unread_provider.dart';

/// Which slice of the inbox is showing. Filtering is client-side: the
/// thread list is small (one thread per listing conversation) and a
/// server round-trip per chip tap would be slower than the filter is
/// worth.
enum _InboxFilter { all, unread }

class ThreadsListScreen extends ConsumerStatefulWidget {
  const ThreadsListScreen({super.key});

  @override
  ConsumerState<ThreadsListScreen> createState() => _ThreadsListScreenState();
}

class _ThreadsListScreenState extends ConsumerState<ThreadsListScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  String? _error;
  List<ThreadDto> _items = const [];
  Timer? _poll;

  final _searchCtrl = TextEditingController();
  String _query = '';
  _InboxFilter _filter = _InboxFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    // Poll every 30s while visible; foreground/background handled below.
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _searchCtrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    try {
      final rows = await ref.read(messagingRepositoryProvider).listThreads();
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
        _error = null;
      });
      // Update the global unread badge in one place.
      unawaited(ref.read(unreadCountProvider.notifier).refresh());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is AuthException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  List<ThreadDto> get _visible {
    final q = _query.toLowerCase();
    return _items.where((th) {
      if (_filter == _InboxFilter.unread && th.unreadCount == 0) return false;
      if (q.isEmpty) return true;
      final name = th.counterparty?.fullName.toLowerCase() ?? '';
      final listing = th.listingTitle?.toLowerCase() ?? '';
      // A pasted listing number should find its thread too.
      return name.contains(q) ||
          listing.contains(q) ||
          '${th.listingId}'.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final auth = ref.watch(authControllerProvider);
    final isBuyer = auth.user?.role == 'buyer';
    final c = context.colors;
    final rows = _visible;
    final unreadThreads = _items.where((th) => th.unreadCount > 0).length;

    return Scaffold(
      appBar: const BrandAppBar(),
      bottomNavigationBar: const AppBottomNav(currentTab: AppTab.messages),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                t.inboxTitle,
                                style: Theme.of(context).textTheme.headlineSmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              tooltip: t.refresh,
                              onPressed: _load,
                              icon: Icon(Icons.refresh_rounded, color: c.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _query = v.trim()),
                          decoration: InputDecoration(
                            hintText: t.inboxSearchHint,
                            prefixIcon: Icon(Icons.search_rounded,
                                size: 20, color: c.textMuted),
                            suffixIcon: _searchCtrl.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: t.clear,
                                    icon: Icon(Icons.close_rounded,
                                        size: 18, color: c.textMuted),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _query = '');
                                    },
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _FilterChip(
                              label: t.inboxFilterAll(_items.length),
                              icon: Icons.forum_outlined,
                              selected: _filter == _InboxFilter.all,
                              onTap: () =>
                                  setState(() => _filter = _InboxFilter.all),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: t.inboxFilterUnread(unreadThreads),
                              icon: Icons.mark_chat_unread_outlined,
                              selected: _filter == _InboxFilter.unread,
                              onTap: () =>
                                  setState(() => _filter = _InboxFilter.unread),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const _InboxTrustBanner(),
                        const SizedBox(height: 12),
                        if (_items.isEmpty)
                          _Empty(isBuyer: isBuyer)
                        else if (rows.isEmpty)
                          _NoMatches(
                            onClear: () {
                              _searchCtrl.clear();
                              setState(() {
                                _query = '';
                                _filter = _InboxFilter.all;
                              });
                            },
                          )
                        else
                          for (final th in rows) ...[
                            _ThreadCard(
                              thread: th,
                              onTap: () async {
                                await context.push(
                                  '${Routes.messages}/${th.id}',
                                  extra: th,
                                );
                                // Explicit reload on return — badge /
                                // unread counts almost certainly changed.
                                unawaited(_load());
                              },
                            ),
                            const SizedBox(height: 10),
                          ],
                        const SizedBox(height: 6),
                        const _SafetyGuidanceCard(),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_outline_rounded,
                                size: 13, color: c.textSubtle),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                t.inboxPrivacyNote,
                                style: TextStyle(
                                    color: c.textSubtle, fontSize: 11, height: 1.5),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({required this.thread, required this.onTap});
  final ThreadDto thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final other = thread.counterparty;
    final name = other?.fullName ?? '—';
    final when = thread.lastMessageAt ?? thread.createdAt;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateStr = when == null ? '' : _relativeStamp(when.toLocal(), locale);
    final unread = thread.unreadCount > 0;

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: unread ? c.primary.withValues(alpha: 0.45) : c.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(
                name: name,
                verified: other?.role == 'broker' &&
                    other?.verificationStatus == 'verified',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: TextStyle(
                              color: c.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (other != null) ...[
                          const SizedBox(width: 6),
                          _RolePill(role: other.role, status: other.verificationStatus),
                        ],
                        const Spacer(),
                        Text(dateStr,
                            style: TextStyle(color: c.textSubtle, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    if (thread.listingTitle != null)
                      Row(
                        children: [
                          Icon(Icons.apartment_rounded,
                              size: 13, color: c.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              thread.listingTitle!,
                              style: TextStyle(
                                  color: c.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            t.listingRef(thread.listingId),
                            style:
                                TextStyle(color: c.textSubtle, fontSize: 11),
                          ),
                        ],
                      ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            thread.lastMessage ?? t.threadNoMessagesYet,
                            style: TextStyle(
                              color: unread ? c.text : c.textMuted,
                              fontSize: 13,
                              fontWeight:
                                  unread ? FontWeight.w600 : FontWeight.w400,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${thread.unreadCount}',
                              style: TextStyle(
                                color: c.background,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
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

/// Today → time, this week → weekday, older → date. Same convention
/// every messaging app uses, because it is the one that reads fastest.
String _relativeStamp(DateTime when, String locale) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(when.year, when.month, when.day);
  final daysAgo = today.difference(that).inDays;
  if (daysAgo <= 0) return DateFormat.jm(locale).format(when);
  if (daysAgo < 7) return DateFormat.EEEE(locale).format(when);
  return DateFormat.yMd(locale).format(when);
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.role, this.status});
  final String role;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final verifiedBroker = role == 'broker' && status == 'verified';
    final label = role == 'broker' ? t.brokerLicensedLabel : t.roleBuyer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: verifiedBroker ? c.verifiedBg : c.surfaceAlt,
        border: Border.all(color: verifiedBroker ? c.verifiedLine : c.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: verifiedBroker ? c.verified : c.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.verified = false});
  final String name;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.surfaceHigh,
              shape: BoxShape.circle,
              border: Border.all(color: c.border),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(name),
              style: TextStyle(
                  color: c.textMuted, fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          if (verified)
            PositionedDirectional(
              bottom: -2,
              end: -2,
              child: Container(
                padding: const EdgeInsets.all(1.5),
                decoration:
                    BoxDecoration(color: c.surface, shape: BoxShape.circle),
                child:
                    Icon(Icons.verified_rounded, size: 15, color: c.verified),
              ),
            ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

/// What the platform actually guarantees about these conversations —
/// they're on the record and tied to verified identities. Deliberately
/// does not claim end-to-end encryption, which we don't implement.
class _InboxTrustBanner extends StatelessWidget {
  const _InboxTrustBanner();

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceLow,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c.verifiedBg,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: c.verifiedLine),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.gavel_rounded, size: 17, color: c.verified),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.inboxTrustTitle,
                  style: TextStyle(
                      color: c.text, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  t.inboxTrustBody,
                  style: TextStyle(color: c.textMuted, fontSize: 11, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The two rules that actually protect an Egyptian buyer in a property
/// deal. Worth repeating where the negotiation happens.
class _SafetyGuidanceCard extends StatelessWidget {
  const _SafetyGuidanceCard();

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;

    Widget tile(IconData icon, Color tint, String title, String body) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14, color: tint),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                            color: tint,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: TextStyle(color: c.textMuted, fontSize: 11, height: 1.5),
                ),
              ],
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(12),
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
              Icon(Icons.tips_and_updates_outlined, size: 17, color: c.accent),
              const SizedBox(width: 8),
              Text(
                t.safetyGuidanceTitle,
                style: TextStyle(
                    color: c.text, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              tile(Icons.payments_outlined, c.rejected, t.safetyNoCashTitle,
                  t.safetyNoCashBody),
              const SizedBox(width: 8),
              tile(Icons.fact_check_outlined, c.verified, t.safetyCheckDeedTitle,
                  t.safetyCheckDeedBody),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: c.surfaceLow,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 36, color: c.textSubtle),
          const SizedBox(height: 10),
          Text(t.inboxNoMatches,
              style: TextStyle(color: c.textMuted), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onClear, child: Text(t.clear)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = selected ? (dark ? c.background : Colors.white) : c.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.primary : c.surface,
          border: Border.all(color: selected ? c.primary : c.border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                  color: fg, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
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

class _Empty extends StatelessWidget {
  const _Empty({required this.isBuyer});
  final bool isBuyer;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      decoration: BoxDecoration(
        color: c.surfaceLow,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(Icons.forum_outlined, color: c.textSubtle, size: 44),
          const SizedBox(height: 12),
          Text(t.noMessagesYet,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            isBuyer ? t.noMessagesYetBuyerSub : t.noMessagesYetSub,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
