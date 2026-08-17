import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../auth/data/models.dart' show AuthException;
import '../data/models.dart';
import '../data/reports_repository.dart';

/// Report dialog for listings or brokers. Returns the created ReportDto
/// on success, null on cancel.
Future<ReportDto?> showReportDialog(
  BuildContext context,
  WidgetRef ref, {
  required String targetType,
  required int targetId,
  required String targetLabel, // "This listing" / "Broker: {name}"
}) {
  return showDialog<ReportDto>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ReportDialog(
      targetType: targetType,
      targetId: targetId,
      targetLabel: targetLabel,
    ),
  );
}

class _ReportDialog extends ConsumerStatefulWidget {
  const _ReportDialog({
    required this.targetType,
    required this.targetId,
    required this.targetLabel,
  });
  final String targetType;
  final int targetId;
  final String targetLabel;

  @override
  ConsumerState<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends ConsumerState<_ReportDialog> {
  String _reason = ReportReasons.fraud;
  final _noteCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = AppL10n.of(context)!;
    setState(() => _submitting = true);
    try {
      final report = await ref.read(reportsRepositoryProvider).submit(
            targetType: widget.targetType,
            targetId: widget.targetId,
            reason: _reason,
            note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(report);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.reportSubmitted)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is AuthException ? e.message : t.reportFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    return AlertDialog(
      title: Text(widget.targetType == ReportTargetTypes.listing
          ? t.reportListing
          : t.reportBroker),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.targetLabel,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration: InputDecoration(labelText: t.reportReason),
              items: [
                DropdownMenuItem(value: ReportReasons.fraud, child: Text(t.reasonFraud)),
                DropdownMenuItem(value: ReportReasons.spam, child: Text(t.reasonSpam)),
                DropdownMenuItem(
                    value: ReportReasons.inappropriate, child: Text(t.reasonInappropriate)),
                DropdownMenuItem(
                    value: ReportReasons.wrongInfo, child: Text(t.reasonWrongInfo)),
                DropdownMenuItem(value: ReportReasons.other, child: Text(t.reasonOther)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _reason = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              maxLength: 1000,
              maxLines: 3,
              decoration: InputDecoration(labelText: t.reportNoteLabel),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(t.reportSubmit),
        ),
      ],
    );
  }
}
