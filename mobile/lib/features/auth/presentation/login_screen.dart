import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../router.dart';
import '../../../theme.dart';
import '../../shared/widgets/wasit_logo.dart';
import '../data/models.dart';
import 'auth_controller.dart';

/// Sign-in screen — matches the Stitch mockup:
///
///  ┌────────────────────────────────────┐
///  │              [logo tile]           │
///  │        مرحباً بك في وسيط            │
///  │  المنصة الأولى الموثقة للوساطة…    │
///  │      [credential pill]             │
///  │                                    │
///  │  Phone (+20 EG flag)               │
///  │  Password  · نسيت كلمة المرور؟      │
///  │  ┌──────────────────────────────┐  │
///  │  │     تسجيل الدخول              │  │
///  │  └──────────────────────────────┘  │
///  │        ─── أو المتابعة عبر ───    │
///  │  [Egyptian Digital ID SSO — قريباً]│
///  │  [تسجيل سريع برمز التحقق — قريباً] │
///  │     ليس لديك حساب؟ إنشاء حساب      │
///  │                                    │
///  │  [feature card] [feature card]     │
///  │  [green trust footer]              │
///  └────────────────────────────────────┘
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  String _phoneE164 = '';
  bool _showPassword = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = AppL10n.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_phoneE164.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.phoneRequired)),
      );
      return;
    }
    final ok = await ref.read(authControllerProvider.notifier).login(
          LoginRequest(phone: _phoneE164, password: _passwordCtrl.text),
        );
    if (!mounted) return;
    if (!ok) {
      final err = ref.read(authControllerProvider).error;
      if (err != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      }
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — ${AppL10n.of(context)!.comingSoon}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final state = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Hero ──────────────────────────────────────────
                Align(
                  alignment: Alignment.center,
                  child: WasitLogo(size: 76),
                ),
                const SizedBox(height: 20),
                Text(
                  t.loginHeroTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  t.loginHeroSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textMuted, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.center,
                  child: CredentialPill(label: t.loginCredentialPill),
                ),
                const SizedBox(height: 24),

                // ── Form card ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Phone label + hint row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(t.phone, style: _labelStyle(c)),
                          Text(t.loginPhoneHint, style: _hintStyle(c)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: IntlPhoneField(
                          decoration: const InputDecoration(),
                          initialCountryCode: 'EG',
                          onChanged: (p) => _phoneE164 = p.completeNumber,
                          invalidNumberMessage: t.phoneInvalid,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Password label + forgot link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(t.password, style: _labelStyle(c)),
                          InkWell(
                            onTap: state.submitting
                                ? null
                                : () => context.push(Routes.forgotPassword),
                            child: Text(
                              t.forgotPassword,
                              style: TextStyle(
                                color: c.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordCtrl,
                        decoration: InputDecoration(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                              color: c.textMuted,
                            ),
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                        obscureText: !_showPassword,
                        validator: (v) =>
                            (v == null || v.length < 8) ? t.passwordMin8 : null,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: state.submitting ? null : _submit,
                        child: state.submitting
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2, color: c.background,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(t.signIn),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_back_rounded, size: 18),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Alt sign-in divider ───────────────────────────
                Row(
                  children: [
                    Expanded(child: Divider(color: c.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(t.loginAltDivider,
                          style: TextStyle(color: c.textMuted, fontSize: 12)),
                    ),
                    Expanded(child: Divider(color: c.border)),
                  ],
                ),
                const SizedBox(height: 14),
                _AltSignInButton(
                  icon: Icons.fingerprint_rounded,
                  iconColor: c.verified,
                  iconBg: c.verifiedBg,
                  title: t.loginSsoDigitalEgypt,
                  subtitle: t.loginSsoDigitalEgyptSub,
                  comingSoon: true,
                  onTap: () => _showComingSoon(t.loginSsoDigitalEgypt),
                ),
                const SizedBox(height: 10),
                _AltSignInButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  iconColor: c.primary,
                  iconBg: c.primary.withValues(alpha: 0.15),
                  title: t.loginOtpTitle,
                  subtitle: t.loginOtpSub,
                  comingSoon: false,
                  onTap: () => context.push(Routes.otpLogin),
                ),
                const SizedBox(height: 20),

                // ── Bottom register prompt ───────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(t.loginNoAccountPrompt,
                        style: TextStyle(color: c.textMuted, fontSize: 13)),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => context.go(Routes.register),
                      child: Text(
                        t.loginRegisterCta,
                        style: TextStyle(
                          color: c.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Trust feature cards (2 across) ───────────────
                Row(
                  children: [
                    Expanded(
                      child: _TrustFeatureCard(
                        icon: Icons.gavel_rounded,
                        iconColor: c.primary,
                        title: t.loginTrustContracts,
                        subtitle: t.loginTrustContractsSub,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TrustFeatureCard(
                        icon: Icons.fact_check_outlined,
                        iconColor: c.verified,
                        title: t.loginTrustInspect,
                        subtitle: t.loginTrustInspectSub,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Green success footer ──────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.verifiedBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.verifiedLine),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          size: 22, color: c.verified),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.loginFooterTitle,
                              style: TextStyle(
                                color: c.verified,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t.loginFooterSub,
                              style: TextStyle(
                                color: c.verified.withValues(alpha: 0.85),
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _labelStyle(AppColors c) => TextStyle(
        color: c.text,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      );

  TextStyle _hintStyle(AppColors c) => TextStyle(
        color: c.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      );
}

/// Alternative sign-in option row (SSO, OTP). Renders as a card with
/// an icon on the right (RTL), title + subtitle stacked, and an arrow
/// or "قريباً" pill on the left.
class _AltSignInButton extends StatelessWidget {
  const _AltSignInButton({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.comingSoon,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final bool comingSoon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppL10n.of(context)!;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: c.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(color: c.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              if (comingSoon)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.pendingBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: c.pendingLine),
                  ),
                  child: Text(
                    t.comingSoon,
                    style: TextStyle(
                      color: c.pending, fontSize: 10, fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Icon(Icons.arrow_back_ios_new_rounded,
                    size: 14, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two-up trust feature card (with icon, title, and one-line subtitle).
class _TrustFeatureCard extends StatelessWidget {
  const _TrustFeatureCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: c.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(color: c.textMuted, fontSize: 10.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
