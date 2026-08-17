import 'dart:async';
import 'dart:ui' as ui;

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/image_compressor.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../theme.dart';
import '../../auth/data/models.dart' show AuthException;
import '../../auth/presentation/auth_controller.dart';
import '../../shared/widgets/language_toggle_button.dart';
import '../../shared/widgets/status_card.dart';
import '../../shared/widgets/theme_toggle_button.dart';
import '../data/broker_repository.dart';
import '../data/models.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _goeicCtrl = TextEditingController();

  VerificationStatusDto? _status;
  bool _loading = true;
  bool _submitting = false;
  String? _loadError;

  PlatformFile? _pickedFile;

  // PDPL consent — the GOEIC number + doc are "sensitive personal
  // data" under Egypt's PDPL (Law 151/2020), which requires explicit
  // consent. Submit stays disabled until this is checked.
  bool _pdplConsent = false;

  static const _allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png', 'webp'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _goeicCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final status = await ref.read(brokerRepositoryProvider).fetchMyStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _goeicCtrl.text = status.goeicRegistrationNumber ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e is AuthException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    var file = result.files.single;

    // Compress images before submit so the multipart body stays small.
    // PDFs are passed through untouched (path-only on native, no need to
    // pull them into RAM).
    final ext = (file.extension ?? '').toLowerCase();
    final isImage = ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'webp';
    if (isImage) {
      Uint8List? compressed;
      if (file.bytes != null) {
        compressed = await compressImage(file.bytes!);
      } else if (!kIsWeb && file.path != null) {
        compressed = await compressImageFromPath(file.path!);
        if (compressed.isEmpty) compressed = null; // plugin refused → keep original
      }
      if (compressed != null) {
        file = PlatformFile(
          name: file.name,
          size: compressed.length,
          bytes: compressed,
        );
      }
    }
    if (!mounted) return;
    setState(() => _pickedFile = file);
  }

  Future<void> _submit() async {
    final t = AppL10n.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    final file = _pickedFile;
    final hasSource = file != null && (file.path != null || file.bytes != null);
    if (!hasSource) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.verifyPickDocument)),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final status = await ref.read(brokerRepositoryProvider).submit(
            goeicRegistrationNumber: _goeicCtrl.text.trim(),
            documentFilename: file.name,
            documentPath: file.path,
            documentBytes: file.bytes,
          );
      if (!mounted) return;
      setState(() {
        _status = status;
        _submitting = false;
        _pickedFile = null;
      });
      unawaited(ref.read(authControllerProvider.notifier).refreshMe());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.verifySubmitted)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is AuthException ? e.message : t.verifySubmitFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.verifyTitle),
        actions: [
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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? _ErrorState(message: _loadError!, onRetry: _load)
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _StatusHeader(status: _status!),
                      const SizedBox(height: 20),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SectionLabel(
                              _status!.status == 'verified'
                                  ? t.updateRegistration
                                  : t.registrationDetails,
                            ),
                            const SizedBox(height: 8),
                            // GOEIC numbers are Latin/digits — force LTR
                            // so they render sanely in RTL contexts.
                            Directionality(
                              textDirection: ui.TextDirection.ltr,
                              child: TextFormField(
                                controller: _goeicCtrl,
                                decoration: InputDecoration(
                                  labelText: t.goeicField,
                                  hintText: t.goeicHint,
                                ),
                                textInputAction: TextInputAction.next,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? t.required
                                        : null,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _DocumentPicker(
                              file: _pickedFile,
                              onPick: _pickFile,
                            ),
                            const SizedBox(height: 16),
                            _PdplConsentTile(
                              value: _pdplConsent,
                              onChanged: (v) =>
                                  setState(() => _pdplConsent = v ?? false),
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              // Disabled until consent is checked (PDPL).
                              onPressed: (_submitting || !_pdplConsent)
                                  ? null
                                  : _submit,
                              child: _submitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _status!.status == 'rejected'
                                          ? t.resubmitDocuments
                                          : _status!.status == 'verified'
                                              ? t.submitNewDocuments
                                              : t.submitForReview,
                                    ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              t.verifyHonestNote,
                              style: TextStyle(
                                color: c.textSubtle,
                                fontSize: 11,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.status});
  final VerificationStatusDto status;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    String? subtitle;
    switch (status.status) {
      case 'verified':
        final when = status.verifiedAt;
        subtitle = when != null
            ? t.verifyStatusVerifiedSubDated(
                DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
                    .format(when.toLocal()))
            : t.verifyStatusVerifiedSubUndated;
        break;
      case 'pending':
        subtitle = t.verifyStatusPendingSub;
        break;
      case 'rejected':
        subtitle = t.verifyStatusRejectedSub;
        break;
    }
    return StatusCard(
      status: status.status,
      subtitle: subtitle,
      reason: status.status == 'rejected' ? status.rejectionReason : null,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: c.textSubtle,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
      ),
    );
  }
}

class _DocumentPicker extends StatelessWidget {
  const _DocumentPicker({required this.file, required this.onPick});
  final PlatformFile? file;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final hasFile = file != null;
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border),
              ),
              child: Center(
                child: Icon(
                  hasFile ? Icons.description_rounded : Icons.upload_file_rounded,
                  color: hasFile ? c.primary : c.textMuted,
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
                    hasFile ? file!.name : t.chooseDocument,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasFile
                        ? t.tapToReplace(_formatBytes(file!.size))
                        : t.documentAllowed,
                    style: TextStyle(color: c.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Auto-mirroring chevron: reads as "next" in either direction.
            Icon(Icons.chevron_right_rounded,
                color: c.textSubtle,
                textDirection: Directionality.of(context)),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: c.textMuted, size: 44),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: Text(t.retry)),
          ],
        ),
      ),
    );
  }
}


/// PDPL consent tile — explicit checkbox required before the broker
/// can submit their GOEIC number + registration doc (both count as
/// "sensitive personal data" under Egypt's PDPL, Law 151/2020).
class _PdplConsentTile extends StatelessWidget {
  const _PdplConsentTile({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          border: Border.all(color: value ? c.primary : c.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                t.pdplConsent,
                style: TextStyle(
                  color: c.text,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
