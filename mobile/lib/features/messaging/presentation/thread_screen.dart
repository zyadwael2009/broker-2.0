import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../theme.dart';
import '../../auth/data/models.dart' show AuthException;
import '../../auth/presentation/auth_controller.dart';
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
    }
    _load(initial: true);
    unawaited(_loadMyRating());
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _load());
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

      // Auto-scroll to bottom on new messages (delayed a frame so the
      // ListView has the new items measured).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is AuthException ? e.message : e.toString();
      });
    }
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is AuthException ? e.message : t.cannotSendMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final auth = ref.watch(authControllerProvider);
    final meId = auth.user?.id ?? -1;
    final c = context.colors;
    final hint = _hint;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(hint?.counterparty?.fullName ?? '—',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            if (hint?.listingTitle != null)
              Text(
                t.conversationWith(hint!.listingTitle!),
                style: TextStyle(color: c.textMuted, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          if (hint?.counterparty?.role == 'broker' &&
              hint?.counterparty?.verificationStatus != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Center(
                child: VerifiedBadge(
                  status: hint!.counterparty!.verificationStatus!,
                  compact: true,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
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
                          padding: const EdgeInsets.all(12),
                          itemCount: _messages.length,
                          itemBuilder: (context, i) => _Bubble(
                            message: _messages[i],
                            isMe: _messages[i].senderId == meId,
                          ),
                        ),
            ),
            // Buyer + has sent ≥1 message + no rating yet → show the prompt.
            if (auth.user?.role == 'buyer' &&
                _myRatingChecked &&
                _myRating == null &&
                _messages.any((m) => m.senderId == meId))
              _RatePromptCard(onTap: _openRateDialog),
            _Composer(
              controller: _sendCtrl,
              sending: _sending,
              onSend: _send,
              hint: t.sendMessagePlaceholder,
              sendLabel: t.sendMessage,
            ),
          ],
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


class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.isMe});
  final MessageDto message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = isMe ? c.primary : c.surfaceAlt;
    final fg = isMe ? Colors.white : c.text;
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
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: bg,
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
            Text(message.body, style: TextStyle(color: fg, fontSize: 14, height: 1.35)),
            const SizedBox(height: 2),
            Text(
              stamp,
              style: TextStyle(
                color: isMe ? Colors.white70 : c.textSubtle,
                fontSize: 10,
              ),
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
    required this.sendLabel,
  });
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final String hint;
  final String sendLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                counterText: '',
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: sending ? null : onSend,
            style: FilledButton.styleFrom(
              minimumSize: const Size(64, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: sending
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}
