import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../../core/document_opener.dart';
import '../../../core/nav.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../theme.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/data/models.dart' show AuthException;
import '../../shared/widgets/verified_badge.dart';
import '../data/admin_repository.dart';
import '../data/models.dart';

/// Admin detail: full broker info + document preview + approve/reject
/// action bar sticky at the bottom.
class AdminBrokerDetailScreen extends ConsumerStatefulWidget {
  const AdminBrokerDetailScreen({super.key, required this.brokerUserId});
  final int brokerUserId;

  @override
  ConsumerState<AdminBrokerDetailScreen> createState() =>
      _AdminBrokerDetailScreenState();
}

class _AdminBrokerDetailScreenState
    extends ConsumerState<AdminBrokerDetailScreen> {
  bool _loading = true;
  bool _acting = false;
  AdminBrokerDto? _broker;
  String? _error;
  bool _dirty = false; // set when we approve/reject so the queue refreshes

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
      final b =
          await ref.read(adminRepositoryProvider).detail(widget.brokerUserId);
      if (!mounted) return;
      setState(() {
        _broker = b;
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

  Future<void> _approve() async {
    setState(() => _acting = true);
    try {
      final updated =
          await ref.read(adminRepositoryProvider).approve(widget.brokerUserId);
      if (!mounted) return;
      setState(() {
        _broker = updated;
        _acting = false;
        _dirty = true;
      });
      final t = AppL10n.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.brokerVerified)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _acting = false);
      final t = AppL10n.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is AuthException ? e.message : t.approveFailed)),
      );
    }
  }

  Future<void> _reject() async {
    final reason = await _promptForReason();
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _acting = true);
    try {
      final updated = await ref
          .read(adminRepositoryProvider)
          .reject(widget.brokerUserId, reason.trim());
      if (!mounted) return;
      setState(() {
        _broker = updated;
        _acting = false;
        _dirty = true;
      });
      final t = AppL10n.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.brokerRejected)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _acting = false);
      final t = AppL10n.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is AuthException ? e.message : t.rejectFailed)),
      );
    }
  }

  Future<String?> _promptForReason() async {
    final t = AppL10n.of(context)!;
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(t.rejectionReasonTitle),
          content: TextField(
            controller: ctrl,
            maxLines: 4,
            autofocus: true,
            decoration: InputDecoration(
              hintText: t.rejectionReasonHint,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: Text(t.reject),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
    return result;
  }

  /// Fetches the broker's verification doc through Dio (which carries
  /// the admin's JWT) and hands the bytes to `openDocumentBytes` which
  /// does a real download-and-open — no data: URIs, no Chrome-Android
  /// data-URL block, no Intent-extras size cap.
  Future<void> _openDocument(BuildContext context, AdminBrokerDto b) async {
    final url = b.documentUrl;
    if (url == null) return;
    final api = ref.read(apiClientProvider);
    try {
      final res = await api.dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      if (res.statusCode != 200 || res.data == null) {
        throw Exception('Fetch failed (${res.statusCode}).');
      }
      final filename = url.split('/').last;
      final result = await openDocumentBytes(
        bytes: Uint8List.fromList(res.data!),
        filenameWithExt: filename,
      );
      if (!result.success && context.mounted) {
        final t = AppL10n.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.couldNotOpenDocument(result.error ?? '?'))),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      final t = AppL10n.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.couldNotOpenDocument('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppL10n.of(context)!;
    return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => safePop<bool>(
              context,
              forRole: ref.read(authControllerProvider).user,
              result: _dirty,
            ),
          ),
          title: Text(_broker?.fullName ?? t.brokerLabel),
        ),
        body: SafeArea(
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
                  : _Body(broker: _broker!, onOpenDocument: () => _openDocument(context, _broker!)),
        ),
        bottomNavigationBar: _broker == null
            ? null
            : _ActionBar(
                broker: _broker!,
                acting: _acting,
                onApprove: _approve,
                onReject: _reject,
              ),
      );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.broker, required this.onOpenDocument});
  final AdminBrokerDto broker;
  final VoidCallback onOpenDocument;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Text(
                _initialsOf(broker.fullName),
                style: TextStyle(
                  color: c.textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    broker.fullName,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(broker.phone, style: TextStyle(color: c.textMuted, fontSize: 13)),
                ],
              ),
            ),
            VerifiedBadge(status: broker.verificationStatus),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: _KV(
                  label: AppL10n.of(context)!.goeicShort,
                  value: broker.goeicRegistrationNumber ?? '—',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _KV(
                  label: AppL10n.of(context)!.lastUpdate,
                  value: broker.updatedAt == null
                      ? '—'
                      : DateFormat('d MMM, HH:mm',
                              Localizations.localeOf(context).toLanguageTag())
                          .format(broker.updatedAt!.toLocal()),
                ),
              ),
            ],
          ),
        ),
        if (broker.rejectionReason != null && broker.rejectionReason!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.rejectedBg,
              border: Border.all(color: c.rejectedLine),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppL10n.of(context)!.previousRejectionReason,
                  style: TextStyle(
                    color: c.rejected,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(broker.rejectionReason!,
                    style: TextStyle(color: c.text, fontSize: 13)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          AppL10n.of(context)!.registrationDocument,
          style: TextStyle(
            color: c.textSubtle,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        _DocumentTile(broker: broker, onOpen: onOpenDocument),
      ],
    );
  }

  String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }
}

class _KV extends StatelessWidget {
  const _KV({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: c.textSubtle,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: c.text,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.broker, required this.onOpen});
  final AdminBrokerDto broker;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasDoc = broker.documentUrl != null;
    final isPdf = broker.isPdfDoc;
    final ext = (broker.documentUrl ?? '').split('.').last.toUpperCase();

    return InkWell(
      onTap: hasDoc ? onOpen : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                hasDoc ? ext : '—',
                style: TextStyle(
                  color: isPdf ? c.rejected : c.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasDoc
                        ? (broker.documentUrl!.split('/').last)
                        : AppL10n.of(context)!.noDocumentSubmitted,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasDoc
                        ? AppL10n.of(context)!.tapToOpen
                        : AppL10n.of(context)!.brokerHasNotUploaded,
                    style: TextStyle(color: c.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (hasDoc)
              Icon(Icons.open_in_new_rounded, color: c.textSubtle, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.broker,
    required this.acting,
    required this.onApprove,
    required this.onReject,
  });
  final AdminBrokerDto broker;
  final bool acting;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final approveDisabled =
        acting || broker.documentUrl == null || broker.verificationStatus == 'verified';
    final rejectDisabled =
        acting || broker.verificationStatus == 'rejected';

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: rejectDisabled ? null : onReject,
              icon: Icon(Icons.close_rounded, color: rejectDisabled ? null : c.rejected),
              label: Text(AppL10n.of(context)!.reject,
                  style: TextStyle(color: rejectDisabled ? null : c.rejected)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: rejectDisabled ? c.border : c.rejectedLine),
                foregroundColor: c.rejected,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: approveDisabled ? null : onApprove,
              icon: const Icon(Icons.check_rounded),
              label: Text(AppL10n.of(context)!.approve),
              style: FilledButton.styleFrom(
                backgroundColor: approveDisabled ? c.borderStrong : c.verified,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
