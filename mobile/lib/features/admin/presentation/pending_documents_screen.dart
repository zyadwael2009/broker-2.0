import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../../core/document_opener.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../theme.dart';
import '../../auth/data/models.dart' show AuthException;
import '../../documents/data/documents_repository.dart';
import '../../documents/data/models.dart';

/// Admin's Phase-4 queue: uploaded property documents awaiting review.
/// Self-reported checklist items intentionally aren't here — admins only
/// see actual uploads.
class PendingDocumentsScreen extends ConsumerStatefulWidget {
  const PendingDocumentsScreen({super.key});

  @override
  ConsumerState<PendingDocumentsScreen> createState() =>
      _PendingDocumentsScreenState();
}

class _PendingDocumentsScreenState
    extends ConsumerState<PendingDocumentsScreen> {
  bool _loading = true;
  String? _error;
  List<PendingDocumentDto> _items = const [];

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
      final rows = await ref.read(documentsRepositoryProvider).pendingForAdmin();
      if (!mounted) return;
      setState(() {
        _items = rows;
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

  Future<void> _approve(PendingDocumentDto d) async {
    try {
      await ref.read(documentsRepositoryProvider).adminApprove(d.id);
      if (!mounted) return;
      setState(() => _items.removeWhere((x) => x.id == d.id));
      final t = AppL10n.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.documentVerified)),
      );
    } catch (e) {
      if (!mounted) return;
      final t = AppL10n.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is AuthException ? e.message : t.approveFailed)),
      );
    }
  }

  Future<void> _reject(PendingDocumentDto d) async {
    final t = AppL10n.of(context)!;
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.rejectionReasonTitle),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          autofocus: true,
          decoration: InputDecoration(hintText: t.rejectionReasonHint),
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
      ),
    );
    ctrl.dispose();
    if (reason == null || reason.trim().isEmpty) return;

    try {
      await ref.read(documentsRepositoryProvider).adminReject(d.id, reason.trim());
      if (!mounted) return;
      setState(() => _items.removeWhere((x) => x.id == d.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.documentRejected)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is AuthException ? e.message : t.rejectFailed)),
      );
    }
  }

  Future<void> _openDoc(PendingDocumentDto d) async {
    final url = d.documentUrl;
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
      if (!result.success && mounted) {
        final t = AppL10n.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.couldNotOpenDocument(result.error ?? '?'))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final t = AppL10n.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.couldNotOpenDocument('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, style: TextStyle(color: c.textMuted)),
                ),
              )
            : _items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_rounded, size: 44, color: c.textSubtle),
                          const SizedBox(height: 10),
                          Text(AppL10n.of(context)!.noPendingDocs,
                              style: TextStyle(color: c.textMuted)),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _PendingDocTile(
                        item: _items[i],
                        onOpen: () => _openDoc(_items[i]),
                        onApprove: () => _approve(_items[i]),
                        onReject: () => _reject(_items[i]),
                      ),
                    ),
                  );
  }
}

class _PendingDocTile extends StatelessWidget {
  const _PendingDocTile({
    required this.item,
    required this.onOpen,
    required this.onApprove,
    required this.onReject,
  });
  final PendingDocumentDto item;
  final VoidCallback onOpen;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppL10n.of(context)!;
    final ext = (item.documentUrl ?? '').split('.').last.toUpperCase();
    final df = DateFormat('d MMM, HH:mm',
        Localizations.localeOf(context).toLanguageTag());

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _localizedKindLabel(item.kind, t),
                        style: TextStyle(
                          color: c.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: c.pendingBg,
                        border: Border.all(color: c.pendingLine),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        ext.isEmpty ? 'FILE' : ext,
                        style: TextStyle(
                          color: c.pending,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.listingTitle}  ·  #${item.listingId}',
                  style: TextStyle(color: c.textMuted, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                if (item.brokerName != null)
                  Text(
                    '${item.brokerName}  ·  ${item.brokerPhone ?? ""}',
                    style: TextStyle(color: c.textMuted, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                if (item.updatedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    t.submittedRelative(df.format(item.updatedAt!.toLocal())),
                    style: TextStyle(color: c.textSubtle, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          Divider(color: c.border, height: 1),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  icon: const Icon(Icons.visibility_rounded, size: 18),
                  label: Text(t.view),
                  onPressed: onOpen,
                ),
              ),
              Container(width: 1, height: 32, color: c.border),
              Expanded(
                child: TextButton.icon(
                  icon: Icon(Icons.close_rounded, size: 18, color: c.rejected),
                  label: Text(t.reject, style: TextStyle(color: c.rejected)),
                  onPressed: onReject,
                ),
              ),
              Container(width: 1, height: 32, color: c.border),
              Expanded(
                child: TextButton.icon(
                  icon: Icon(Icons.check_rounded, size: 18, color: c.verified),
                  label: Text(t.approve, style: TextStyle(color: c.verified)),
                  onPressed: onApprove,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _localizedKindLabel(String kind, AppL10n t) {
  switch (kind) {
    case DocumentKinds.titleDeed:
      return t.docsTitleDeed;
    case DocumentKinds.noLiens:
      return t.docsNoLiens;
    case DocumentKinds.taxClearance:
      return t.docsTaxClearance;
    default:
      return kind;
  }
}
