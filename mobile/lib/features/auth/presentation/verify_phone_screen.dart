import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter, LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../router.dart';
import '../../../theme.dart';
import '../data/models.dart' show AuthException;
import 'auth_controller.dart';

/// After registration or later on demand: enter the 6-digit OTP.
/// "Skip for now" lets the user proceed to the landing with the verify
/// banner still nagging.
class VerifyPhoneScreen extends ConsumerStatefulWidget {
  const VerifyPhoneScreen({super.key});

  @override
  ConsumerState<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends ConsumerState<VerifyPhoneScreen> {
  final _codeCtrl = TextEditingController();
  bool _submitting = false;
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    // Send an initial OTP so entering the screen is enough; the user
    // doesn't have to press Resend to get their first code.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode(initial: true));
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendCode({bool initial = false}) async {
    try {
      final debugCode = await ref.read(authControllerProvider.notifier).sendPhoneOtp();
      if (!mounted) return;
      // Dev convenience: prefill the code field when the server echoes
      // it (only when SMS_DEBUG_RETURN_CODE=true). Prod SMS always comes
      // through and this is null.
      if (debugCode != null && debugCode.length == 6) {
        _codeCtrl.text = debugCode;
      }
      if (!initial) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code sent.')),
        );
      }
      _startResendCooldown();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is AuthException ? e.message : e.toString())),
      );
    }
  }

  void _startResendCooldown() {
    setState(() => _resendIn = 30);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _resendIn = _resendIn - 1);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _confirm() async {
    final t = AppL10n.of(context)!;
    setState(() => _submitting = true);
    final ok = await ref.read(authControllerProvider.notifier)
        .confirmPhoneOtp(_codeCtrl.text.trim());
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.verifyPhoneSuccess)),
      );
      final auth = ref.read(authControllerProvider);
      context.go(landingFor(auth.user?.role));
    } else {
      final err = ref.read(authControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? t.codeIncorrect)),
      );
    }
  }

  void _skip() {
    final auth = ref.read(authControllerProvider);
    context.go(landingFor(auth.user?.role));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final phone = ref.watch(authControllerProvider).user?.phone ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(t.verifyPhoneTitle),
        leading: null,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _submitting ? null : _skip,
            child: Text(t.verifyPhoneSkip),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Icon(Icons.sms_rounded, size: 44, color: c.primary),
              const SizedBox(height: 20),
              Text(
                t.verifyPhoneSub(phone),
                style: TextStyle(color: c.textMuted, fontSize: 15, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _codeCtrl,
                autofocus: true,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                style: const TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w700,
                  letterSpacing: 12,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  labelText: t.verifyPhoneCodeLabel,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _confirm,
                child: _submitting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(t.verifyPhoneConfirm),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: (_resendIn > 0 || _submitting) ? null : _sendCode,
                  child: Text(_resendIn > 0
                      ? t.verifyPhoneResendIn(_resendIn)
                      : t.verifyPhoneResend),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
