import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/image_compressor.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../theme.dart';
import '../../auth/data/models.dart' show AuthException;
import '../data/documents_repository.dart';
import '../data/models.dart';
import 'widgets/document_state_pill.dart';

/// Renders the 3-row property-documents checklist inside a listing detail.
/// `isOwner` toggles the tap-to-manage behavior; buyers see the same rows
/// but read-only with an honest disclaimer under them.
class DocumentsSection extends ConsumerStatefulWidget {
  const DocumentsSection({
    super.key,
    required this.listingId,
    required this.isOwner,
  });

  final int listingId;
  final bool isOwner;

  @override
  ConsumerState<DocumentsSection> createState() => _DocumentsSectionState();
}

class _DocumentsSectionState extends ConsumerState<DocumentsSection> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<ListingDocumentDto> _docs = const [];

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
      final rows = await ref
          .read(documentsRepositoryProvider)
          .forListing(widget.listingId);
      if (!mounted) return;
      setState(() {
        _docs = rows;
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

  Future<void> _selfReport(String kind) async {
    final t = AppL10n.of(context)!;
    await _runOwnerAction(
      () => ref.read(documentsRepositoryProvider).selfReport(widget.listingId, kind),
      successMsg: t.docSelfReported,
    );
  }

  Future<void> _upload(String kind) async {
    // On web there's no path, so we have to load bytes. On native use
    // the path — file_picker with withData:true copies the whole file
    // into the Dart heap (dio's MultipartFile then keeps a second ref).
    // Matches the pattern in the broker verification screen.
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: kIsWeb,
    );
    if (picked == null || picked.files.isEmpty) return;
    if (!mounted) return;
    final file = picked.files.single;
    Uint8List? bytes = file.bytes;
    String? path = bytes == null ? file.path : null;
    if (bytes == null && path == null) return;

    // Grab the l10n handle BEFORE any awaits — compression yields
    // async gaps and BuildContext isn't safe to read after them.
    final t = AppL10n.of(context)!;

    // Compress images before upload — PDFs pass through untouched.
    final ext = (file.extension ?? '').toLowerCase();
    final isImage = ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'webp';
    if (isImage) {
      Uint8List? shrunk;
      if (bytes != null) {
        shrunk = await compressImage(bytes);
      } else if (!kIsWeb && path != null) {
        final out = await compressImageFromPath(path);
        shrunk = out.isEmpty ? null : out;
      }
      if (shrunk != null) {
        bytes = shrunk;
        path = null;
      }
    }
    if (!mounted) return;

    await _runOwnerAction(
      () => ref.read(documentsRepositoryProvider).upload(
            listingId: widget.listingId,
            kind: kind,
            filename: file.name,
            bytes: bytes,
            path: path,
          ),
      successMsg: t.docSubmitted,
    );
  }

  Future<void> _delete(String kind) async {
    final t = AppL10n.of(context)!;
    setState(() => _busy = true);
    try {
      await ref.read(documentsRepositoryProvider).delete(widget.listingId, kind);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.docCleared)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is AuthException ? e.message : t.deleteFailed)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runOwnerAction(
    Future<ListingDocumentDto> Function() op, {
    required String successMsg,
  }) async {
    setState(() => _busy = true);
    try {
      final updated = await op();
      if (!mounted) return;
      // Splice the updated row into local state; avoids a full reload flash.
      setState(() {
        _docs = [
          for (final d in _docs)
            if (d.kind == updated.kind) updated else d,
        ];
        // If the doc was previously "unset" (no row) we still need to
        // reload to pick up the fresh id/state.
        if (!_docs.any((d) => d.kind == updated.kind && d.id == updated.id)) {
          unawaited(_load());
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMsg)),
      );
    } catch (e) {
      if (!mounted) return;
      final t = AppL10n.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is AuthException ? e.message : t.actionFailed)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openOwnerActions(ListingDocumentDto row) async {
    if (widget.isOwner == false) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final t = AppL10n.of(context)!;
        final c = context.colors;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    _localizedKindLabel(row.kind, t),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (row.state == DocumentStates.rejected &&
                    row.rejectionReason != null) ...[
                  Container(
                    margin: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.rejectedBg,
                      border: Border.all(color: c.rejectedLine),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.reviewerNote,
                            style: TextStyle(
                              color: c.rejected, fontSize: 10,
                              fontWeight: FontWeight.w700, letterSpacing: 1.4,
                            )),
                        const SizedBox(height: 4),
                        Text(row.rejectionReason!,
                            style: TextStyle(color: c.text, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.upload_file_rounded),
                  title: Text(row.hasDocument ? t.replaceProof : t.uploadProof),
                  subtitle: Text(t.uploadProofSub),
                  onTap: () {
                    Navigator.pop(ctx);
                    _upload(row.kind);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.check_circle_outline_rounded),
                  title: Text(t.iHaveThisNoProof),
                  subtitle: Text(t.iHaveThisNoProofSub),
                  onTap: () {
                    Navigator.pop(ctx);
                    _selfReport(row.kind);
                  },
                ),
                if (!row.isUnset)
                  ListTile(
                    leading: Icon(Icons.delete_outline_rounded, color: c.rejected),
                    title: Text(t.remove, style: TextStyle(color: c.rejected)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _delete(row.kind);
                    },
                  ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(AppL10n.of(context)!.propertyDocuments,
                style: Theme.of(context).textTheme.labelSmall),
            const Spacer(),
            if (_busy)
              const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_error!, style: TextStyle(color: c.textMuted)),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _docs.length; i++) ...[
                  if (i > 0) Divider(color: c.border, height: 1, indent: 14, endIndent: 14),
                  _DocRow(
                    row: _docs[i],
                    isOwner: widget.isOwner,
                    onTap: widget.isOwner ? () => _openOwnerActions(_docs[i]) : null,
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(
          AppL10n.of(context)!.docsHonestNote,
          style: TextStyle(color: c.textSubtle, fontSize: 11, height: 1.5),
        ),
      ],
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

class _DocRow extends StatelessWidget {
  const _DocRow({
    required this.row,
    required this.isOwner,
    this.onTap,
  });
  final ListingDocumentDto row;
  final bool isOwner;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _localizedKindLabel(row.kind, AppL10n.of(context)!),
                    style: TextStyle(
                      color: c.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  DocumentStatePill(state: row.state, compact: true),
                ],
              ),
            ),
            if (isOwner)
              Icon(Icons.chevron_right_rounded,
                  color: c.textSubtle,
                  textDirection: Directionality.of(context)),
          ],
        ),
      ),
    );
  }
}
