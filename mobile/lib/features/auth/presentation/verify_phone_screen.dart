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

/// Post-registration OTP verification screen. Matches the Stitch mockup:
///
///  ┌─────────────────────────────┐
///  │      [shield+chat icon]     │
///  │   تأكيد رقم الهاتف المحمول   │
///  │  تم إرسال رمز التحقق ..     │
///  │  +20 100 234 5678           │
///  │      ✎ تعديل الرقم           │
///  │                             │
///  │  [_][_][_][_][_][_]  <- 6-cell OTP
///  │  ✓ تم التحقق من 4 أرقام     │
///  │  🔒 مشفر تلقائياً            │
///  │                             │
///  │  ⏱  إعادة الإرسال خلال 00:46 │
///  │  ↻  إعادة الإرسال كرسالة    │
///  │                             │
///  │  [تأكيد الرمز والمتابعة]     │
///  │  تخطي هذه الخطوة مؤقتاً       │
///  │  🛡 وسيط يحمي بياناتك بـ256   │
///  └─────────────────────────────┘
class VerifyPhoneScreen extends ConsumerStatefulWidget {
  const VerifyPhoneScreen({super.key});

  @override
  ConsumerState<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends ConsumerState<VerifyPhoneScreen> {
  static const _codeLen = 6;
  final _codeCtrl = TextEditingController();
  final _focus = FocusNode();
  bool _submitting = false;
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode(initial: true));
    _codeCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _focus.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendCode({bool initial = false}) async {
    try {
      final debugCode = await ref.read(authControllerProvider.notifier).sendPhoneOtp();
      if (!mounted) return;
      if (debugCode != null && debugCode.length == 6) {
        _codeCtrl.text = debugCode;
      }
      if (!initial) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppL10n.of(context)!.verifyPhoneCodeSent)),
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
    setState(() => _resendIn = 60);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _resendIn = _resendIn - 1);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _confirm() async {
    final t = AppL10n.of(context)!;
    if (_codeCtrl.text.length != _codeLen) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.verifyPhoneCodeLabel)),
      );
      return;
    }
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

  String get _formattedTimer {
    final m = (_resendIn ~/ 60).toString().padLeft(2, '0');
    final s = (_resendIn % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final phone = ref.watch(authControllerProvider).user?.phone ?? '';
    final entered = _codeCtrl.text.length;

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Hero icon (shield + chat bubble stacked) ────────
              SizedBox(
                height: 128,
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 110, height: 110,
                        decoration: BoxDecoration(
                          color: c.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.border),
                        ),
                      ),
                      Container(
                        width: 76, height: 76,
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.verified_user_outlined,
                            size: 34, color: c.primary),
                      ),
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: c.verifiedBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.background, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: Icon(Icons.chat_rounded,
                              size: 14, color: c.verified),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Title + sub + phone number ──────────────────────
              Text(
                t.verifyPhoneTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                t.verifyPhoneIntro,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textMuted, height: 1.6),
              ),
              const SizedBox(height: 4),
              Text(
                phone,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _submitting
                    ? null
                    : () => context.go(Routes.register),
                icon: Icon(Icons.edit_outlined, size: 16, color: c.primary),
                label: Text(t.verifyPhoneEditNumber),
              ),
              const SizedBox(height: 12),

              // ── 6-cell OTP input card ───────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  children: [
                    _OtpCells(
                      length: _codeLen,
                      value: _codeCtrl.text,
                      focusNode: _focus,
                      onChanged: (v) {
                        _codeCtrl.text = v;
                        if (v.length == _codeLen && !_submitting) {
                          _confirm();
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                size: 14, color: c.verified),
                            const SizedBox(width: 4),
                            Text(
                              t.verifyPhoneDigitsEntered(entered),
                              style: TextStyle(
                                color: c.verified,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.lock_outline_rounded,
                                size: 12, color: c.pending),
                            const SizedBox(width: 4),
                            Text(
                              t.verifyPhoneAutoDecrypt,
                              style: TextStyle(
                                color: c.textMuted, fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Resend timer ────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule_rounded, size: 14, color: c.textMuted),
                  const SizedBox(width: 6),
                  Text(t.verifyPhoneResendInPrefix,
                      style: TextStyle(color: c.textMuted, fontSize: 12)),
                  const SizedBox(width: 8),
                  Text(
                    _formattedTimer,
                    style: TextStyle(
                        color: _resendIn > 0 ? c.accent : c.textSubtle,
                        fontSize: 13,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton.icon(
                  onPressed: (_resendIn > 0 || _submitting) ? null : _sendCode,
                  icon: Icon(Icons.replay_rounded,
                      size: 16,
                      color: _resendIn > 0 ? c.textSubtle : c.primary),
                  label: Text(t.verifyPhoneResendSms),
                ),
              ),
              const SizedBox(height: 16),

              // ── Confirm CTA ─────────────────────────────────────
              FilledButton(
                onPressed: (_submitting || entered != _codeLen) ? null : _confirm,
                child: _submitting
                    ? SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: c.background),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(t.verifyPhoneConfirmCta),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_back_rounded, size: 18),
                        ],
                      ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: _submitting ? null : _skip,
                  child: Text(t.verifyPhoneSkip,
                      style: TextStyle(color: c.textMuted)),
                ),
              ),
              const SizedBox(height: 14),

              // ── Security note ───────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 18, color: c.verified),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t.verifyPhoneSecurityNote,
                        style: TextStyle(color: c.textMuted, fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Six visually-distinct cells rendered on top of a hidden text field.
/// Tapping any cell focuses the field; keystrokes update the cells.
class _OtpCells extends StatelessWidget {
  const _OtpCells({
    required this.length,
    required this.value,
    required this.focusNode,
    required this.onChanged,
  });
  final int length;
  final String value;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      children: [
        Row(
          children: List.generate(length, (i) {
            final filled = i < value.length;
            final focused = i == value.length && focusNode.hasFocus;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i == length - 1 ? 0 : 8),
                height: 56,
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: focused
                        ? c.primary
                        : filled
                            ? c.primary.withValues(alpha: 0.4)
                            : c.border,
                    width: focused ? 1.6 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: filled
                    ? Text(
                        value[i],
                        style: TextStyle(
                          color: c.primary,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                        ),
                      )
                    : focused
                        ? Container(width: 2, height: 24, color: c.primary)
                        : Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              color: c.textSubtle.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                          ),
              ),
            );
          }),
        ),
        // Hidden underlying text field captures input.
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              autofocus: true,
              focusNode: focusNode,
              controller: TextEditingController.fromValue(
                TextEditingValue(
                  text: value,
                  selection: TextSelection.collapsed(offset: value.length),
                ),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(length),
              ],
              onChanged: onChanged,
              style: const TextStyle(fontSize: 24),
              decoration: const InputDecoration(border: InputBorder.none),
            ),
          ),
        ),
      ],
    );
  }
}
