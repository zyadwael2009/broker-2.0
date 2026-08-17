import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../router.dart';
import '../../../theme.dart';
import '../../auth/data/models.dart' show AuthException;
import '../data/models.dart';
import '../data/reports_repository.dart';

/// Admin's Phase-11 queue: buyer/broker reports. Filter chips flip
/// between open / resolved / dismissed. Actions per open report:
/// Dismiss, Resolve — no action, Take action (+ optional note).
class ReportsQueueScreen extends ConsumerStatefulWidget {
  const ReportsQueueScreen({super.key});

  @override
  ConsumerState<ReportsQueueScreen> createState() =>
      _ReportsQueueScreenState();
}

class _ReportsQueueScreenState extends ConsumerState<ReportsQueueScreen> {
  String _filter = ReportStatuses.open;
  bool _loading = true;
  String? _error;
  List<ReportDto> _items = const [];

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
      final items = await ref
          .read(reportsRepositoryProvider)
          .listForAdmin(status: _filter);
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

  Future<void> _resolve(ReportDto r, String action) async {
    String? note;
    if (action == 'resolved_action') {
      note = await _promptForNote();
      if (note == null) return; // cancelled
    }
    try {
      await ref.read(reportsRepositoryProvider).resolve(
            reportId: r.id,
            action: action,
            note: note,
          );
      if (!mounted) return;
      final t = AppL10n.of(context)!;
      setState(() => _items.removeWhere((x) => x.id == r.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          action == 'dismiss' ? t.adminReportDismissed : t.adminReportResolved,
        )),
      );
    } catch (e) {
      if (!mounted) return;
      final t = AppL10n.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is AuthException ? e.message : t.rejectFailed)),
      );
    }
  }

  Future<String?> _promptForNote() async {
    final t = AppL10n.of(context)!;
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.adminResolveDialogTitle),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          maxLength: 1000,
          decoration: InputDecoration(labelText: t.adminResolveNoteLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(t.adminTakeAction),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              _Chip(
                label: t.adminReportsOpen,
                active: _filter == ReportStatuses.open,
                onTap: () {
                  setState(() => _filter = ReportStatuses.open);
                  _load();
                },
              ),
              const SizedBox(width: 8),
              _Chip(
                label: t.adminReportsResolved,
                active: _filter == ReportStatuses.resolvedAction ||
                    _filter == ReportStatuses.resolvedNoAction,
                onTap: () {
                  // Show resolved_action by default; UI merges both.
                  setState(() => _filter = ReportStatuses.resolvedAction);
                  _load();
                },
              ),
              const SizedBox(width: 8),
              _Chip(
                label: t.adminReportsDismissed,
                active: _filter == ReportStatuses.dismissed,
                onTap: () {
                  setState(() => _filter = ReportStatuses.dismissed);
                  _load();
                },
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
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inbox_rounded,
                                    color: c.textSubtle, size: 44),
                                const SizedBox(height: 10),
                                Text(
                                  _filter == ReportStatuses.open
                                      ? t.adminNoOpenReports
                                      : _filter == ReportStatuses.dismissed
                                          ? t.adminNoDismissedReports
                                          : t.adminNoResolvedReports,
                                  style: TextStyle(color: c.textMuted),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(20),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) => _ReportTile(
                              report: _items[i],
                              onOpenTarget: () => _openTarget(_items[i]),
                              onDismiss: _filter == ReportStatuses.open
                                  ? () => _resolve(_items[i], 'dismiss')
                                  : null,
                              onResolveNoAction: _filter == ReportStatuses.open
                                  ? () => _resolve(_items[i], 'resolved_no_action')
                                  : null,
                              onTakeAction: _filter == ReportStatuses.open
                                  ? () => _resolve(_items[i], 'resolved_action')
                                  : null,
                            ),
                          ),
                        ),
        ),
      ],
    );
  }

  void _openTarget(ReportDto r) {
    if (r.targetType == ReportTargetTypes.listing) {
      context.push('${Routes.listings}/${r.targetId}');
    } else {
      context.push('${Routes.brokerProfile}/${r.targetId}');
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});
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
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.report,
    required this.onOpenTarget,
    this.onDismiss,
    this.onResolveNoAction,
    this.onTakeAction,
  });
  final ReportDto report;
  final VoidCallback onOpenTarget;
  final VoidCallback? onDismiss;
  final VoidCallback? onResolveNoAction;
  final VoidCallback? onTakeAction;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final df = DateFormat('d MMM, HH:mm', locale);
    final reasonLabel = switch (report.reason) {
      ReportReasons.fraud => t.reasonFraud,
      ReportReasons.spam => t.reasonSpam,
      ReportReasons.inappropriate => t.reasonInappropriate,
      ReportReasons.wrongInfo => t.reasonWrongInfo,
      _ => t.reasonOther,
    };
    final targetLabel = report.targetType == ReportTargetTypes.listing
        ? 'listing #${report.targetId}'
        : 'broker #${report.targetId}';

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onOpenTarget,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.rejectedBg,
                          border: Border.all(color: c.rejectedLine),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(reasonLabel,
                            style: TextStyle(
                              color: c.rejected,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.adminReportAbout(targetLabel),
                          style: TextStyle(
                            color: c.text,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.adminReportedBy(report.reporter?.fullName ?? '—'),
                    style: TextStyle(color: c.textMuted, fontSize: 12),
                  ),
                  if (report.note != null && report.note!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(report.note!,
                        style: TextStyle(color: c.text, fontSize: 13)),
                  ],
                  if (report.createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(df.format(report.createdAt!.toLocal()),
                        style: TextStyle(color: c.textSubtle, fontSize: 11)),
                  ],
                  if (report.resolutionNote != null &&
                      report.resolutionNote!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        report.resolutionNote!,
                        style: TextStyle(color: c.textMuted, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (onDismiss != null || onResolveNoAction != null || onTakeAction != null) ...[
            Divider(color: c.border, height: 1),
            Row(
              children: [
                if (onDismiss != null)
                  Expanded(
                    child: TextButton(
                      onPressed: onDismiss,
                      child: Text(t.adminDismiss),
                    ),
                  ),
                if (onResolveNoAction != null) ...[
                  Container(width: 1, height: 32, color: c.border),
                  Expanded(
                    child: TextButton(
                      onPressed: onResolveNoAction,
                      child: Text(t.adminResolveNoAction),
                    ),
                  ),
                ],
                if (onTakeAction != null) ...[
                  Container(width: 1, height: 32, color: c.border),
                  Expanded(
                    child: TextButton(
                      onPressed: onTakeAction,
                      child: Text(t.adminTakeAction,
                          style: TextStyle(color: c.rejected)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
