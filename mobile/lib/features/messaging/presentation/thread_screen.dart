import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/env.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../router.dart';
import '../../../theme.dart';
import '../../auth/data/models.dart' show AuthException;
import '../../auth/presentation/auth_controller.dart';
import '../../listings/data/listings_repository.dart';
import '../../listings/data/models.dart' show ListingDto;
import '../../ratings/data/models.dart' as ratings;
import '../../ratings/data/ratings_repository.dart';
import '../../ratings/presentation/rate_broker_dialog.dart';
import '../../shared/widgets/verified_badge.dart';
import '../data/messaging_repository.dart';
import '../data/models.dart';
import '../data/unread_provider.dart';

class ThreadScreen extends ConsumerStatefulWidget {
  const ThreadScreen({super.key, required this.threadId, this.hint});
  final int threadId;

  /// Optional seed — when opened from the inbox we pass the thread DTO
  /// so we can show the counterparty header immediately without waiting
  /// for the first messages fetch.
  final ThreadDto? hint;

  @override
  ConsumerState<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends ConsumerState<ThreadScreen>
    with WidgetsBindingObserver {
  final _sendCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<MessageDto> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _poll;
  int _lastId = 0;
  ThreadDto? _resolvedHint; // populated from server when widget.hint is null
  ListingDto? _listing;
  ratings.RatingDto? _myRating;
  bool _myRatingChecked = false;
  int _myRatingRetries = 0;

  ThreadDto? get _hint => widget.hint ?? _resolvedHint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // If we arrived via a deep link (no hint), fetch the thread summary
    // in parallel so the AppBar can render the counterparty name.
    if (widget.hint == null) {
      unawaited(_fetchHint());
    } else {
      unawaited(_fetchListing(widget.hint!.listingId));
    }
    _load(initial: true);
    unawaited(_loadMyRating());
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  /// The property being negotiated is the context for every message in
  /// here, so the header card shows it with its real price and photo.
  /// Best-effort: a failure just leaves the card off.
  Future<void> _fetchListing(int listingId) async {
    try {
      final l = await ref
          .read(listingsRepositoryProvider)
          .get(listingId, usePublic: Env.screenshotMode);
      if (!mounted) return;
      setState(() => _listing = l);
    } catch (_) {
      // Header card is decoration; the conversation is the screen.
    }
  }

  Future<void> _loadMyRating() async {
    // Only buyers can rate brokers.
    final auth = ref.read(authControllerProvider);
    if (auth.user?.role != 'buyer') {
      if (mounted) setState(() => _myRatingChecked = true);
      return;
    }
    final brokerId = _hint?.counterparty?.id;
    if (brokerId == null) {
      // Header hasn't landed yet — retry a few times, then give up so
      // this doesn't spin forever if the hint fetch never succeeds.
      if (_myRatingRetries++ < 6) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) unawaited(_loadMyRating());
        });
      } else {
        if (mounted) setState(() => _myRatingChecked = true);
      }
      return;
    }
    try {
      final r = await ref.read(ratingsRepositoryProvider).myRating(brokerId);
      if (!mounted) return;
      setState(() {
        _myRating = r;
        _myRatingChecked = true;
      });
    } catch (_) {
      if (mounted) setState(() => _myRatingChecked = true);
    }
  }

  Future<void> _openRateDialog() async {
    final brokerId = _hint?.counterparty?.id;
    final brokerName = _hint?.counterparty?.fullName;
    if (brokerId == null || brokerName == null) return;
    final result = await showRateBrokerDialog(
      context, ref,
      brokerId: brokerId,
      brokerName: brokerName,
      initialStars: _myRating?.stars,
      initialNote: _myRating?.note,
    );
    if (result != null) {
      unawaited(_loadMyRating());
    }
  }

  Future<void> _fetchHint() async {
    try {
      final t = await ref
          .read(messagingRepositoryProvider)
          .getThread(widget.threadId);
      if (!mounted) return;
      setState(() => _resolvedHint = t);
      unawaited(_fetchListing(t.listingId));
    } catch (_) {
      // Silent — the message list still loads. Header just stays generic.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Foreground/background pause: no ticker changes yet, but the timer
    // will fire fewer times in the background per platform policy anyway.
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _sendCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    if (!mounted) return;
    try {
      final repo = ref.read(messagingRepositoryProvider);
      final rows = await repo.messages(widget.threadId,
          since: initial ? null : (_lastId == 0 ? null : _lastId));
      if (!mounted) return;
      // Any successful poll — even one that returned zero new messages —
      // means the connection is healthy, so clear any stale error banner.
      if (rows.isEmpty) {
        setState(() {
          _loading = false;
          _error = null;
        });
        return;
      }
      setState(() {
        if (initial) {
          _messages = rows;
        } else {
          _messages = [..._messages, ...rows];
        }
        _lastId = _messages.last.id;
        _loading = false;
        _error = null;
      });
      // Refresh the global inbox badge — polling here just marked ours read.
      unawaited(ref.read(unreadCountProvider.notifier).refresh());
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is AuthException ? e.message : e.toString();
      });
    }
  }

  void _scrollToBottom() {
    // Delayed a frame so the ListView has the new items measured.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final t = AppL10n.of(context)!;
    final body = _sendCtrl.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final msg = await ref.read(messagingRepositoryProvider).send(widget.threadId, body);
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, msg];
        _lastId = msg.id;
        _sending = false;
        _sendCtrl.clear();
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is AuthException ? e.message : t.cannotSendMessage)),
      );
    }
  }

  /// Quick replies PREFILL the composer rather than sending. These are
  /// commitments about a real property — nobody should be able to
  /// promise a viewing time with one stray tap.
  void _prefill(String text) {
    _sendCtrl
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final auth = ref.watch(authControllerProvider);
    final meId = auth.user?.id ?? -1;
    final c = context.colors;
    final hint = _hint;
    final other = hint?.counterparty;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.threadTitle),
        actions: [
          if (hint != null)
            IconButton(
              tooltip: t.viewListing,
              icon: const Icon(Icons.apartment_rounded),
              onPressed: () =>
                  context.push('${Routes.listings}/${hint.listingId}'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (other != null) _CounterpartyBar(counterparty: other),
            if (_listing != null)
              _ListingContextCard(
                listing: _listing!,
                onOpen: () =>
                    context.push('${Routes.listings}/${_listing!.id}'),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(_error!,
                                style: TextStyle(color: c.textMuted)),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          // +1 for the on-the-record banner that opens
                          // every thread.
                          itemCount: _messages.length + 1,
                          itemBuilder: (context, i) {
                            if (i == 0) return const _ThreadSecurityNote();
                            final index = i - 1;
                            final msg = _messages[index];
                            final prev =
                                index == 0 ? null : _messages[index - 1];
                            return Column(
                              children: [
                                if (_needsDateDivider(prev, msg))
                                  _DateDivider(when: msg.createdAt),
                                _Bubble(
                                  message: msg,
                                  isMe: msg.senderId == meId,
                                ),
                              ],
                            );
                          },
                        ),
            ),
            // Buyer + has sent ≥1 message + no rating yet → show the prompt.
            if (auth.user?.role == 'buyer' &&
                _myRatingChecked &&
                _myRating == null &&
                _messages.any((m) => m.senderId == meId))
              _RatePromptCard(onTap: _openRateDialog),
            _QuickReplies(
              isBroker: auth.user?.role == 'broker',
              onPick: _prefill,
            ),
            _Composer(
              controller: _sendCtrl,
              sending: _sending,
              onSend: _send,
              hint: t.sendMessagePlaceholder,
            ),
          ],
        ),
      ),
    );
  }

  bool _needsDateDivider(MessageDto? prev, MessageDto current) {
    final now = current.createdAt;
    if (now == null) return false;
    if (prev?.createdAt == null) return true;
    final a = prev!.createdAt!.toLocal();
    final b = now.toLocal();
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }
}

/// Who you're talking to, pinned under the app bar: name, what they are,
/// and whether we verified them.
class _CounterpartyBar extends StatelessWidget {
  const _CounterpartyBar({required this.counterparty});
  final ThreadCounterparty counterparty;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final isBroker = counterparty.role == 'broker';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c.surfaceHigh,
              shape: BoxShape.circle,
              border: Border.all(color: c.border),
            ),
            alignment: Alignment.center,
            child: Text(
              counterparty.fullName.trim().isEmpty
                  ? '?'
                  : counterparty.fullName.trim().characters.first.toUpperCase(),
              style: TextStyle(
                  color: c.textMuted, fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  counterparty.fullName,
                  style: TextStyle(
                      color: c.text, fontSize: 15, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isBroker ? t.brokerLicensedLabel : t.roleBuyer,
                  style: TextStyle(color: c.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (isBroker && counterparty.verificationStatus != null)
            VerifiedBadge(status: counterparty.verificationStatus!, compact: true),
        ],
      ),
    );
  }
}

class _ListingContextCard extends StatelessWidget {
  const _ListingContextCard({required this.listing, required this.onOpen});
  final ListingDto listing;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final cover = listing.photos.isNotEmpty ? listing.photos.first : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 54,
                  height: 46,
                  child: cover == null
                      ? Container(
                          color: c.surfaceHigh,
                          alignment: Alignment.center,
                          child: Icon(Icons.image_rounded,
                              size: 18, color: c.textSubtle),
                        )
                      : CachedNetworkImage(
                          imageUrl: '${Env.apiBaseUrl}${cover.url}',
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: c.surfaceHigh),
                          errorWidget: (_, __, ___) => Container(
                            color: c.surfaceHigh,
                            alignment: Alignment.center,
                            child: Icon(Icons.image_rounded,
                                size: 18, color: c.textSubtle),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      style: TextStyle(
                          color: c.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${listing.priceGrouped} ${listing.listingKind == 'rent' ? t.currencyEgpPerMonth : t.currencyEgp}',
                      style: TextStyle(
                          color: c.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                t.viewListing,
                style: TextStyle(
                    color: c.primary, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              Icon(Icons.chevron_left_rounded, size: 18, color: c.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens every thread: says what the platform actually does — keeps the
/// conversation on the record between two identified accounts. It does
/// not claim end-to-end encryption, which we don't implement.
class _ThreadSecurityNote extends StatelessWidget {
  const _ThreadSecurityNote();

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceLow,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, size: 18, color: c.verified),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t.threadSecurityNote,
              style: TextStyle(color: c.textMuted, fontSize: 11, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.when});
  final DateTime? when;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (when == null) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context).toLanguageTag();
    final label = DateFormat.yMMMd(locale).format(when!.toLocal());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
                color: c.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _RatePromptCard extends StatelessWidget {
  const _RatePromptCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(Icons.star_rounded, color: c.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t.rateBroker,
              style: TextStyle(
                color: c.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(onPressed: onTap, child: Text(t.rateSubmit)),
        ],
      ),
    );
  }
}

/// The three things people actually type in a property negotiation.
/// Tapping one drops it in the composer to edit and send.
class _QuickReplies extends StatelessWidget {
  const _QuickReplies({required this.isBroker, required this.onPick});
  final bool isBroker;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final replies = isBroker
        ? [t.quickReplyBrokerViewing, t.quickReplyBrokerDocs, t.quickReplyBrokerPrice]
        : [t.quickReplyBuyerViewing, t.quickReplyBuyerDocs, t.quickReplyBuyerPrice];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: replies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => InkWell(
          onTap: () => onPick(replies[i]),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              replies[i],
              style: TextStyle(
                  color: c.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.isMe});
  final MessageDto message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = isMe ? c.primary : c.surface;
    // Primary-ink on teal in dark mode per the design system's button
    // rule — white on this teal fails contrast.
    final fg = isMe ? (dark ? c.background : Colors.white) : c.text;
    final when = message.createdAt;
    final stamp = when == null
        ? ''
        : DateFormat.jm(Localizations.localeOf(context).toLanguageTag())
            .format(when.toLocal());

    return Align(
      alignment: isMe ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        decoration: BoxDecoration(
          color: bg,
          border: isMe ? null : Border.all(color: c.border),
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(14),
            topEnd: const Radius.circular(14),
            bottomStart: Radius.circular(isMe ? 14 : 4),
            bottomEnd: Radius.circular(isMe ? 4 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.body, style: TextStyle(color: fg, fontSize: 14, height: 1.45)),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stamp,
                  style: TextStyle(
                    color: isMe
                        ? fg.withValues(alpha: 0.7)
                        : c.textSubtle,
                    fontSize: 10,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  // Single tick = delivered, double = the other side
                  // opened it. Read state comes from the server, so it
                  // is a fact rather than an optimistic guess.
                  Icon(
                    message.readAt == null ? Icons.check_rounded : Icons.done_all_rounded,
                    size: 13,
                    color: fg.withValues(alpha: 0.75),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.hint,
  });
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              maxLength: 2000,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: hint,
                fillColor: c.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: c.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: c.primary, width: 1.6),
                ),
                counterText: '',
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            height: 48,
            child: Material(
              color: c.primary,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: sending ? null : onSend,
                child: Center(
                  child: sending
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: dark ? c.background : Colors.white,
                          ),
                        )
                      : Icon(Icons.send_rounded,
                          size: 20, color: dark ? c.background : Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
