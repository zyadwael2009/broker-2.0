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
import '../../documents/data/documents_repository.dart';
import '../../reports/data/reports_repository.dart';
import '../../reports/presentation/reports_queue_screen.dart';
import '../../shared/widgets/account_menu_button.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/language_toggle_button.dart';
import '../../shared/widgets/theme_toggle_button.dart';
import '../../shared/widgets/verified_badge.dart';
import '../data/admin_repository.dart';
import '../data/models.dart';
import 'flagged_listings_screen.dart';
import 'pending_documents_screen.dart';

/// The four queues an admin works through. Everything on this screen —
/// the counters, the sidebar, the chips — is a view onto one of these.
enum _Queue { brokers, listings, documents, reports }

/// Admin console: what is waiting, how much of it, and the decision on
/// each item — the compliance desk from the Stitch admin mockup.
///
/// Wide screens get the mockup's sidebar; phones get a chip row instead,
/// because a 220px rail on a 390px screen leaves no room for the actual
/// work.
class AdminQueueScreen extends ConsumerStatefulWidget {
  const AdminQueueScreen({super.key});

  @override
  ConsumerState<AdminQueueScreen> createState() => _AdminQueueScreenState();
}

class _AdminQueueScreenState extends ConsumerState<AdminQueueScreen> {
  _Queue _queue = _Queue.brokers;
  String _brokerFilter = 'pending';
  bool _loading = true;
  String? _error;
  List<AdminBrokerDto> _brokers = const [];

  /// Null means "not counted yet" — the KPI card shows a dash rather
  /// than a zero it hasn't earned.
  final Map<_Queue, int?> _counts = {for (final q in _Queue.values) q: null};

  @override
  void initState() {
    super.initState();
    _load();
    unawaited(_loadCounts());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ref
          .read(adminRepositoryProvider)
          .listBrokers(status: _brokerFilter);
      if (!mounted) return;
      setState(() {
        _brokers = items;
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

  /// Four independent counts, fetched together. Each one fails on its
  /// own: a broken reports endpoint shouldn't blank the whole header.
  Future<void> _loadCounts() async {
    final admin = ref.read(adminRepositoryProvider);
    final docs = ref.read(documentsRepositoryProvider);
    final reports = ref.read(reportsRepositoryProvider);

    Future<void> count(_Queue q, Future<int> future) async {
      try {
        final n = await future;
        if (!mounted) return;
        setState(() => _counts[q] = n);
      } catch (_) {
        // Leave it null — the card shows a dash.
      }
    }

    await Future.wait([
      count(_Queue.brokers,
          admin.listBrokers(status: 'pending').then((r) => r.length)),
      count(_Queue.listings,
          admin.listFlaggedListings().then((r) => r.length)),
      count(_Queue.documents, docs.pendingForAdmin().then((r) => r.length)),
      count(_Queue.reports,
          reports.listForAdmin(status: 'open').then((r) => r.length)),
    ]);
  }

  Future<void> _refreshAll() async {
    await Future.wait([_load(), _loadCounts()]);
  }

  void _select(_Queue q) {
    if (q == _queue) return;
    setState(() => _queue = q);
    if (q == _Queue.brokers) unawaited(_load());
    // Counts go stale as soon as another queue is worked; refresh them
    // whenever the admin moves between queues.
    unawaited(_loadCounts());
  }

  Future<void> _approve(AdminBrokerDto broker) async {
    final t = AppL10n.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(adminRepositoryProvider).approve(broker.userId);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(t.brokerVerified)));
      unawaited(_refreshAll());
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e is AuthException ? e.message : t.approveFailed)),
      );
    }
  }

  Future<void> _reject(AdminBrokerDto broker) async {
    final t = AppL10n.of(context)!;
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.rejectionReasonTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(hintText: t.rejectionReasonHint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: FilledButton.styleFrom(
                backgroundColor: context.colors.rejected),
            child: Text(t.reject),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (reason == null || reason.isEmpty || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(adminRepositoryProvider).reject(broker.userId, reason);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(t.brokerRejected)));
      unawaited(_refreshAll());
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e is AuthException ? e.message : t.rejectFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final adminName = ref.watch(authControllerProvider).user?.fullName;

    return Scaffold(
      bottomNavigationBar: const AppBottomNav(currentTab: AppTab.mine),
      appBar: AppBar(
        title: Text(t.adminConsoleTitle),
        actions: [
          IconButton(
            tooltip: t.refresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : () => unawaited(_refreshAll()),
          ),
          const LanguageToggleButton(),
          const ThemeToggleButton(),
          const AccountMenuButton(),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final main = _MainColumn(
              wide: wide,
              queue: _queue,
              counts: _counts,
              adminName: adminName,
              onSelect: _select,
              child: _queueBody(),
            );
            if (!wide) return main;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Sidebar(
                  current: _queue,
                  counts: _counts,
                  adminName: adminName,
                  onSelect: _select,
                ),
                Expanded(child: main),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _queueBody() {
    switch (_queue) {
      case _Queue.listings:
        return const FlaggedListingsScreen();
      case _Queue.documents:
        return const PendingDocumentsScreen();
      case _Queue.reports:
        return const ReportsQueueScreen();
      case _Queue.brokers:
        return _brokersQueue();
    }
  }

  Widget _brokersQueue() {
    final t = AppL10n.of(context)!;
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(
            children: [
              _StatusChip(
                label: t.filterPending,
                active: _brokerFilter == 'pending',
                onTap: () => _changeFilter('pending'),
              ),
              const SizedBox(width: 8),
              _StatusChip(
                label: t.filterVerified,
                active: _brokerFilter == 'verified',
                onTap: () => _changeFilter('verified'),
              ),
              const SizedBox(width: 8),
              _StatusChip(
                label: t.filterRejected,
                active: _brokerFilter == 'rejected',
                onTap: () => _changeFilter('rejected'),
              ),
            ],
          ),
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
                  : _brokers.isEmpty
                      ? _EmptyState(filter: _brokerFilter)
                      : RefreshIndicator(
                          onRefresh: _refreshAll,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: _brokers.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final b = _brokers[i];
                              return _BrokerDecisionCard(
                                broker: b,
                                onOpen: () async {
                                  final changed = await context.push<bool>(
                                    '${Routes.adminBrokers}/${b.userId}',
                                  );
                                  if (changed == true) {
                                    unawaited(_refreshAll());
                                  }
                                },
                                onApprove: b.verificationStatus == 'pending'
                                    ? () => _approve(b)
                                    : null,
                                onReject: b.verificationStatus == 'pending'
                                    ? () => _reject(b)
                                    : null,
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  void _changeFilter(String next) {
    if (next == _brokerFilter) return;
    setState(() => _brokerFilter = next);
    unawaited(_load());
  }
}

/// Title block, the four counters, and (on phones) the queue chips.
class _MainColumn extends StatelessWidget {
  const _MainColumn({
    required this.wide,
    required this.queue,
    required this.counts,
    required this.adminName,
    required this.onSelect,
    required this.child,
  });

  final bool wide;
  final _Queue queue;
  final Map<_Queue, int?> counts;
  final String? adminName;
  final ValueChanged<_Queue> onSelect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.adminConsoleHeading,
                      style: Theme.of(context).textTheme.headlineSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (adminName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        border: Border.all(color: c.border),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_rounded,
                              size: 13, color: c.primary),
                          const SizedBox(width: 5),
                          Text(
                            adminName!,
                            style: TextStyle(
                                color: c.text,
                                fontSize: 11,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                t.adminConsoleSubtitle,
                style: TextStyle(color: c.textMuted, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 14),
              _KpiRow(counts: counts, current: queue, onSelect: onSelect),
              const SizedBox(height: 14),
              if (!wide)
                _QueueChips(current: queue, counts: counts, onSelect: onSelect),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(child: child),
      ],
    );
  }
}

/// The four counters. Two columns on a phone, four across on a desktop.
class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.counts,
    required this.current,
    required this.onSelect,
  });
  final Map<_Queue, int?> counts;
  final _Queue current;
  final ValueChanged<_Queue> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final perRow = constraints.maxWidth >= 720 ? 4 : 2;
        final width =
            (constraints.maxWidth - (perRow - 1) * 10) / perRow;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final q in _Queue.values)
              SizedBox(
                width: width,
                child: _KpiCard(
                  queue: q,
                  count: counts[q],
                  active: q == current,
                  onTap: () => onSelect(q),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.queue,
    required this.count,
    required this.active,
    required this.onTap,
  });
  final _Queue queue;
  final int? count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final spec = _queueSpec(queue, t, c);

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: active ? spec.tint : c.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: spec.tint.withValues(alpha: 0.14),
                      border:
                          Border.all(color: spec.tint.withValues(alpha: 0.35)),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Icon(spec.icon, size: 16, color: spec.tint),
                  ),
                  const Spacer(),
                  Text(
                    count == null ? '—' : '$count',
                    style: TextStyle(
                      color: c.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                spec.label,
                style: TextStyle(
                    color: c.text, fontSize: 12, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                spec.hint,
                style: TextStyle(color: c.textSubtle, fontSize: 11, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.current,
    required this.counts,
    required this.adminName,
    required this.onSelect,
  });
  final _Queue current;
  final Map<_Queue, int?> counts;
  final String? adminName;
  final ValueChanged<_Queue> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;

    return Container(
      width: 232,
      decoration: BoxDecoration(
        color: c.surface,
        // The rail hugs the leading edge in both directions, so the
        // divider is direction-aware rather than pinned to the right.
        border: BorderDirectional(end: BorderSide(color: c.border)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        children: [
          Row(
            children: [
              Icon(Icons.shield_rounded, size: 20, color: c.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.adminConsoleTitle,
                  style: TextStyle(
                      color: c.text, fontSize: 15, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (adminName != null) ...[
            const SizedBox(height: 4),
            Text(
              adminName!,
              style: TextStyle(color: c.textMuted, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 16),
          for (final q in _Queue.values) ...[
            _SidebarItem(
              queue: q,
              count: counts[q],
              active: q == current,
              onTap: () => onSelect(q),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.queue,
    required this.count,
    required this.active,
    required this.onTap,
  });
  final _Queue queue;
  final int? count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final spec = _queueSpec(queue, t, c);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = active ? (dark ? c.background : Colors.white) : c.textMuted;

    return Material(
      color: active ? c.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(spec.icon, size: 17, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  spec.label,
                  style: TextStyle(
                      color: active ? fg : c.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (count != null && count! > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: active
                        ? (dark ? c.background : Colors.white)
                            .withValues(alpha: 0.22)
                        : spec.tint.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: active ? fg : spec.tint,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QueueChips extends StatelessWidget {
  const _QueueChips({
    required this.current,
    required this.counts,
    required this.onSelect,
  });
  final _Queue current;
  final Map<_Queue, int?> counts;
  final ValueChanged<_Queue> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _Queue.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final q = _Queue.values[i];
          final spec = _queueSpec(q, t, c);
          final active = q == current;
          final fg = active ? (dark ? c.background : Colors.white) : c.textMuted;
          final n = counts[q];
          return InkWell(
            onTap: () => onSelect(q),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: active ? c.primary : c.surface,
                border: Border.all(color: active ? c.primary : c.border),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(spec.icon, size: 14, color: fg),
                  const SizedBox(width: 6),
                  Text(
                    n == null ? spec.label : '${spec.label} ($n)',
                    style: TextStyle(
                        color: fg, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One decision, one card: who is asking, what they submitted, and the
/// three things an admin can do about it.
class _BrokerDecisionCard extends StatelessWidget {
  const _BrokerDecisionCard({
    required this.broker,
    required this.onOpen,
    required this.onApprove,
    required this.onReject,
  });
  final AdminBrokerDto broker;
  final VoidCallback onOpen;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final when = broker.updatedAt;
    final stamp =
        when == null ? null : DateFormat.yMMMd(locale).add_jm().format(when.toLocal());

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      VerifiedBadge(
                          status: broker.verificationStatus, compact: true),
                      const Spacer(),
                      if (stamp != null)
                        Text(stamp,
                            style:
                                TextStyle(color: c.textSubtle, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _Avatar(name: broker.fullName),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              broker.fullName,
                              style: TextStyle(
                                color: c.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              broker.phone,
                              style:
                                  TextStyle(color: c.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _FactRow(
                    icon: Icons.badge_outlined,
                    label: t.goeicNumberLabel,
                    value: broker.goeicRegistrationNumber ?? '—',
                  ),
                  const SizedBox(height: 6),
                  _FactRow(
                    icon: Icons.attach_file_rounded,
                    label: t.registrationDocument,
                    value: broker.documentUrl == null
                        ? t.noDocumentSubmitted
                        : (broker.isPdfDoc ? 'PDF' : t.imageAttached),
                    warn: broker.documentUrl == null,
                  ),
                  if (broker.rejectionReason != null &&
                      broker.rejectionReason!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: c.rejectedBg,
                        border: Border.all(color: c.rejectedLine),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.previousRejectionReason,
                            style: TextStyle(
                                color: c.rejected,
                                fontSize: 10,
                                fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            broker.rejectionReason!,
                            style: TextStyle(
                                color: c.textMuted, fontSize: 12, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              border: Border(top: BorderSide(color: c.border)),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(13)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.folder_open_rounded, size: 16),
                    label: Text(t.openFile),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(38),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
                if (onReject != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.rejected,
                        backgroundColor: c.rejectedBg,
                        side: BorderSide(color: c.rejectedLine),
                        minimumSize: const Size.fromHeight(38),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: Text(t.reject),
                    ),
                  ),
                ],
                if (onApprove != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.verified_rounded, size: 16),
                      label: Text(t.approve),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(38),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.warn = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Icon(icon, size: 14, color: warn ? c.pending : c.textSubtle),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: c.textSubtle, fontSize: 11)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: warn ? c.pending : c.text,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? c.primary : c.surface,
          border: Border.all(color: active ? c.primary : c.border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? (dark ? c.background : Colors.white) : c.textMuted,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
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
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: c.surfaceHigh,
        shape: BoxShape.circle,
        border: Border.all(color: c.border),
      ),
      alignment: Alignment.center,
      child: Text(
        _initialsOf(name),
        style: TextStyle(
          color: c.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});
  final String filter;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final line = switch (filter) {
      'pending' => t.noPendingBrokers,
      'verified' => t.noVerifiedBrokers,
      'rejected' => t.noRejectedBrokers,
      _ => t.noPendingBrokers,
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, color: c.textSubtle, size: 44),
            const SizedBox(height: 10),
            Text(line,
                style: TextStyle(color: c.textMuted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _QueueSpec {
  const _QueueSpec(this.label, this.hint, this.icon, this.tint);
  final String label;
  final String hint;
  final IconData icon;
  final Color tint;
}

_QueueSpec _queueSpec(_Queue q, AppL10n t, AppColors c) => switch (q) {
      _Queue.brokers => _QueueSpec(
          t.kpiBrokersLabel, t.kpiBrokersHint, Icons.verified_user_rounded, c.primary),
      _Queue.listings => _QueueSpec(
          t.kpiListingsLabel, t.kpiListingsHint, Icons.flag_rounded, c.rejected),
      _Queue.documents => _QueueSpec(
          t.kpiDocumentsLabel, t.kpiDocumentsHint, Icons.description_rounded, c.accent),
      _Queue.reports => _QueueSpec(
          t.kpiReportsLabel, t.kpiReportsHint, Icons.report_outlined, c.pending),
    };
