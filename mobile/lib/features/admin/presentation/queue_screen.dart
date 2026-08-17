import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../router.dart';
import '../../../theme.dart';
import '../../auth/data/models.dart' show AuthException;
import '../../auth/presentation/auth_controller.dart';
import '../../shared/widgets/language_toggle_button.dart';
import '../../shared/widgets/theme_toggle_button.dart';
import '../../shared/widgets/verified_badge.dart';
import '../data/admin_repository.dart';
import '../data/models.dart';
import '../../reports/presentation/reports_queue_screen.dart';
import 'flagged_listings_screen.dart';
import 'pending_documents_screen.dart';

/// Admin landing: the pending review queue. Filter chips let you switch
/// to the verified or rejected lists without leaving the screen.
class AdminQueueScreen extends ConsumerStatefulWidget {
  const AdminQueueScreen({super.key});

  @override
  ConsumerState<AdminQueueScreen> createState() => _AdminQueueScreenState();
}

class _AdminQueueScreenState extends ConsumerState<AdminQueueScreen> {
  String _filter = 'pending';
  bool _loading = true;
  String? _error;
  List<AdminBrokerDto> _items = const [];

  // Top-level tab: 'brokers' | 'listings' (flagged) | 'documents' (pending) | 'reports'.
  String _tab = 'brokers';

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
      final items =
          await ref.read(adminRepositoryProvider).listBrokers(status: _filter);
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

  void _changeFilter(String next) {
    if (next == _filter) return;
    setState(() => _filter = next);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.adminTitle),
        actions: [
          if (_tab == 'brokers')
            IconButton(
              tooltip: t.refresh,
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loading ? null : _load,
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
        child: Column(
          children: [
            // Top-level tab switcher. Uses ScrollView so the 3 segments
            // don't overflow narrow screens.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'brokers',
                      icon: const Icon(Icons.verified_user_rounded),
                      label: Text(t.brokersTab),
                    ),
                    ButtonSegment(
                      value: 'listings',
                      icon: const Icon(Icons.flag_rounded),
                      label: Text(t.flaggedTab),
                    ),
                    ButtonSegment(
                      value: 'documents',
                      icon: const Icon(Icons.description_rounded),
                      label: Text(t.docsTab),
                    ),
                    ButtonSegment(
                      value: 'reports',
                      icon: const Icon(Icons.report_outlined),
                      label: Text(t.adminReportsTab),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (s) => setState(() => _tab = s.first),
                ),
              ),
            ),
            if (_tab == 'brokers') ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    _FilterChip(
                      label: t.filterPending,
                      active: _filter == 'pending',
                      onTap: () => _changeFilter('pending'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: t.filterVerified,
                      active: _filter == 'verified',
                      onTap: () => _changeFilter('verified'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: t.filterRejected,
                      active: _filter == 'rejected',
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
                        : _items.isEmpty
                            ? _EmptyState(filter: _filter)
                            : RefreshIndicator(
                                onRefresh: _load,
                                child: ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                                  itemCount: _items.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, i) {
                                    final b = _items[i];
                                    return _BrokerTile(
                                      broker: b,
                                      onTap: () async {
                                        final changed = await context.push<bool>(
                                          '${Routes.adminBrokers}/${b.userId}',
                                        );
                                        if (changed == true) unawaited(_load());
                                      },
                                    );
                                  },
                                ),
                              ),
              ),
            ] else if (_tab == 'listings') ...[
              const Expanded(child: FlaggedListingsScreen()),
            ] else if (_tab == 'documents') ...[
              const Expanded(child: PendingDocumentsScreen()),
            ] else ...[
              const Expanded(child: ReportsQueueScreen()),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
            color: active ? Colors.white : c.textMuted,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _BrokerTile extends StatelessWidget {
  const _BrokerTile({required this.broker, required this.onTap});
  final AdminBrokerDto broker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
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
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      broker.phone,
                      style: TextStyle(color: c.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              VerifiedBadge(status: broker.verificationStatus, compact: true),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  color: c.textSubtle,
                  textDirection: Directionality.of(context)),
            ],
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
    final initials = _initialsOf(name);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: c.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w600,
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
            Text(line, style: TextStyle(color: c.textMuted)),
          ],
        ),
      ),
    );
  }
}
