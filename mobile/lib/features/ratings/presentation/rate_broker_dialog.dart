import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../theme.dart';
import '../../auth/data/models.dart' show AuthException;
import '../../shared/widgets/star_row.dart';
import '../data/ratings_repository.dart';

/// Modal for buyer → broker rating. Returns the submitted stars via
/// Navigator.pop, or null if cancelled.
Future<int?> showRateBrokerDialog(
  BuildContext context,
  WidgetRef ref, {
  required int brokerId,
  required String brokerName,
  int? initialStars,
  String? initialNote,
}) {
  return showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _RateBrokerDialog(
      brokerId: brokerId,
      brokerName: brokerName,
      initialStars: initialStars,
      initialNote: initialNote,
    ),
  );
}

class _RateBrokerDialog extends ConsumerStatefulWidget {
  const _RateBrokerDialog({
    required this.brokerId,
    required this.brokerName,
    this.initialStars,
    this.initialNote,
  });
  final int brokerId;
  final String brokerName;
  final int? initialStars;
  final String? initialNote;

  @override
  ConsumerState<_RateBrokerDialog> createState() => _RateBrokerDialogState();
}

class _RateBrokerDialogState extends ConsumerState<_RateBrokerDialog> {
  late int _stars = widget.initialStars ?? 0;
  late final _noteCtrl = TextEditingController(text: widget.initialNote ?? '');
  bool _submitting = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = AppL10n.of(context)!;
    if (_stars < 1) return;
    setState(() => _submitting = true);
    try {
      await ref.read(ratingsRepositoryProvider).submit(
            brokerId: widget.brokerId,
            stars: _stars,
            note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(_stars);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.rateSubmitted)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is AuthException ? e.message : t.rateFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    return AlertDialog(
      title: Text(widget.brokerName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.rateBrokerSub, style: TextStyle(color: c.textMuted)),
          const SizedBox(height: 16),
          Center(
            child: StarRow.interactive(
              value: _stars.toDouble(),
              onChanged: (v) => setState(() => _stars = v),
            ),
          ),
          if (_stars > 0) ...[
            const SizedBox(height: 6),
            Center(
              child: Text(
                t.rateStars(_stars),
                style: TextStyle(color: c.textMuted, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _noteCtrl,
            maxLength: 500,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: t.rateNoteLabel,
              hintText: t.rateNoteHint,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: (_stars < 1 || _submitting) ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(t.rateSubmit),
        ),
      ],
    );
  }
}
