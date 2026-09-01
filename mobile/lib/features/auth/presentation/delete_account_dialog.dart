import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../theme.dart';
import '../data/models.dart' show AuthException;
import 'auth_controller.dart';

/// Confirmation dialog for permanent account deletion.
///
/// Required by the Google Play User Data policy: a signed-in user must
/// be able to delete their account entirely from within the app, not
/// only via an off-platform request. The backend anonymizes the row
/// (nulls PII, deactivates) rather than DROPping it so foreign keys on
/// existing listings/messages/ratings stay intact.
///
/// Usage:
///   showDialog(
///     context: context,
///     builder: (_) => const DeleteAccountDialog(),
///   );
class DeleteAccountDialog extends ConsumerStatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  ConsumerState<DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<DeleteAccountDialog> {
  final _passwordCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final t = AppL10n.of(context)!;
    final pw = _passwordCtrl.text;
    if (pw.isEmpty) {
      setState(() => _error = t.password);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount(pw);
      if (!mounted) return;
      Navigator.of(context).pop();
      // The router listens on authControllerProvider and redirects to
      // /login as soon as state.user goes null (done inside
      // deleteAccount above), so we don't push a route ourselves.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.deleteAccountDone)),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;

    return AlertDialog(
      title: Text(t.deleteAccountTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.deleteAccountBody, style: TextStyle(color: c.textMuted)),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            autofocus: true,
            enabled: !_submitting,
            decoration: InputDecoration(
              labelText: t.password,
              errorText: _error,
            ),
            onSubmitted: (_) => _submitting ? null : _confirm(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(t.cancel),
        ),
        FilledButton(
          // Destructive-action red — overrides the theme's primary teal
          // so the confirm button reads as dangerous, not routine.
          style: FilledButton.styleFrom(backgroundColor: c.rejected),
          onPressed: _submitting ? null : _confirm,
          child: _submitting
              ? const SizedBox(
                  height: 18, width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(t.deleteAccountConfirm),
        ),
      ],
    );
  }
}
