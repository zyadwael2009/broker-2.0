import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter, LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../router.dart';
import '../../../theme.dart';
import 'auth_controller.dart';

/// Two-step reset. Step 1: enter phone → we send an OTP. Step 2: enter
/// OTP + new password (twice).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _pw1Ctrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();

  String? _phoneE164;
  bool _submitting = false;
  int _step = 1; // 1 = enter phone; 2 = enter code + new password

  @override
  void dispose() {
    _codeCtrl.dispose();
    _pw1Ctrl.dispose();
    _pw2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneE164;
    if (phone == null || phone.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final debug = await ref.read(authControllerProvider.notifier).forgotPassword(phone);
      if (!mounted) return;
      // Dev-mode convenience: prefill the code if server leaked it.
      if (debug != null && debug.length == 6) _codeCtrl.text = debug;
      setState(() => _step = 2);
    } catch (_) {
      // Anti-enumeration means we always advance; if the server truly
      // errored, the reset call will fail with a clear message anyway.
      if (mounted) setState(() => _step = 2);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _reset() async {
    final t = AppL10n.of(context)!;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    final ok = await ref.read(authControllerProvider.notifier).resetPassword(
          phoneE164: _phoneE164!,
          code: _codeCtrl.text.trim(),
          newPassword: _pw1Ctrl.text,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.forgotPasswordSuccess)),
      );
      context.go(Routes.login);
    } else {
      final err = ref.read(authControllerProvider).error ?? t.codeIncorrect;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(t.forgotPasswordTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _step == 1 ? t.forgotPasswordStep1Sub : t.forgotPasswordStep2Sub,
                  style: TextStyle(color: c.textMuted, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 24),
                if (_step == 1) ...[
                  IntlPhoneField(
                    initialCountryCode: 'EG',
                    decoration: InputDecoration(labelText: t.phone),
                    onChanged: (PhoneNumber v) => _phoneE164 = v.completeNumber,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _submitting ? null : _sendCode,
                    child: _submitting
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(t.forgotPasswordSendCode),
                  ),
                ] else ...[
                  TextFormField(
                    controller: _codeCtrl,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700,
                      letterSpacing: 10, fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(labelText: t.verifyPhoneCodeLabel),
                    validator: (v) =>
                        (v == null || v.trim().length != 6) ? t.codeIncorrect : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _pw1Ctrl,
                    obscureText: true,
                    decoration: InputDecoration(labelText: t.newPassword),
                    validator: (v) =>
                        (v == null || v.length < 8) ? t.passwordMin8 : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pw2Ctrl,
                    obscureText: true,
                    decoration: InputDecoration(labelText: t.confirmPassword),
                    validator: (v) =>
                        v != _pw1Ctrl.text ? t.passwordsDoNotMatch : null,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _submitting ? null : _reset,
                    child: _submitting
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(t.forgotPasswordConfirmReset),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: _submitting ? null : () => setState(() => _step = 1),
                      child: const Text('Change phone number'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
