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
import '../../shared/widgets/verified_badge.dart';
import '../data/messaging_repository.dart';
import '../data/models.dart';
import '../data/unread_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final auth = ref.watch(authControllerProvider);
    final isBuyer = auth.user?.role == 'buyer';
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.messages),
        actions: [
          IconButton(
            tooltip: t.refresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
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
                      child: Text(_error!, style: TextStyle(color: c.textMuted)),
                    ),
                  )
                : _items.isEmpty
                    ? _Empty(isBuyer: isBuyer)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              Divider(color: c.border, height: 1, indent: 16, endIndent: 16),
                          itemBuilder: (context, i) => _ThreadTile(
                            thread: _items[i],
                            onTap: () async {
                              await context.push(
                                '${Routes.messages}/${_items[i].id}',
                                extra: _items[i],
                              );
                              // Explicit reload on return — badge / unread
                              // counts almost certainly changed.
                              unawaited(_load());
                            },
                          ),
                        ),
                      ),
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.thread, required this.onTap});
  final ThreadDto thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final other = thread.counterparty;
    final name = other?.fullName ?? '—';
    final when = thread.lastMessageAt ?? thread.createdAt;
    final dateStr = when == null
        ? ''
        : DateFormat.MMMd(Localizations.localeOf(context).toLanguageTag())
            .add_jm()
            .format(when.toLocal());

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _Avatar(name: name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            color: c.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (other?.role == 'broker' &&
                          other?.verificationStatus != null) ...[
                        const SizedBox(width: 6),
                        VerifiedBadge(status: other!.verificationStatus!, compact: true),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (thread.listingTitle != null)
                    Text(
                      t.conversationWith(thread.listingTitle!),
                      style: TextStyle(color: c.textSubtle, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  if (thread.lastMessage != null)
                    Text(
                      thread.lastMessage!,
                      style: TextStyle(color: c.textMuted, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(dateStr,
                    style: TextStyle(color: c.textSubtle, fontSize: 11)),
                const SizedBox(height: 6),
                if (thread.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${thread.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final initials = _initials(name);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(initials,
          style: TextStyle(
              color: c.textMuted, fontSize: 15, fontWeight: FontWeight.w600)),
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

class _Empty extends StatelessWidget {
  const _Empty({required this.isBuyer});
  final bool isBuyer;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, color: c.textSubtle, size: 48),
            const SizedBox(height: 12),
            Text(t.noMessagesYet,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              isBuyer ? t.noMessagesYetBuyerSub : t.noMessagesYetSub,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
