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

/// Register screen — matches the Stitch mockup:
///
///  ┌────────────────────────────────────┐
///  │        [logo with verified dot]    │
///  │      [pill: منظومة التسجيل]         │
///  │    انضم إلى شبكة وسيط الموثقة       │
///  │  اختر نوع حسابك للبدء…             │
///  │                                    │
///  │  ┌─── نوع الحساب  · خطوة 1 من 2 ──┐│
///  │  │  Buyer/Renter · Broker (رخصة) ││
///  │  │  [banner: ضمانة التحقق]        ││
///  │  │  Full name  (كما في البطاقة)   ││
///  │  │  Phone      (+20)              ││
///  │  │  Email      (اختياري)          ││
///  │  │  Password   [strength meter]   ││
///  │  │  [checkbox: ربط فوري بالسجل]   ││
///  │  │  [checkbox: agree to terms]    ││
///  │  │  [Create account CTA]          ││
///  │  └───────────────────────────────┘│
///  │  [3 trust cards: مشفرة·قانوني·دعم]│
///  │  Already have? Sign in             │
///  └────────────────────────────────────┘
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String _phoneE164 = '';
  String _role = 'buyer';
  bool _agreedTerms = false;
  bool _linkRegistry = true;   // Egyptian land-registry link (opt-out)
  bool _showPassword = false;
  double _passwordStrength = 0.0;

  @override
  void initState() {
    super.initState();
    _passwordCtrl.addListener(_recalcPasswordStrength);
  }

  @override
  void dispose() {
    _passwordCtrl.removeListener(_recalcPasswordStrength);
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  /// Simple client-side strength score in [0.0, 1.0]. Not a security
  /// check — the backend enforces the real password rules; this is
  /// UI feedback so users don't ship "12345678" thinking it's strong.
  void _recalcPasswordStrength() {
    final p = _passwordCtrl.text;
    double score = 0;
    if (p.length >= 8) score += 0.25;
    if (p.length >= 12) score += 0.15;
    if (RegExp(r'[A-Z]').hasMatch(p)) score += 0.20;
    if (RegExp(r'[0-9]').hasMatch(p)) score += 0.20;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) score += 0.20;
    setState(() => _passwordStrength = score.clamp(0.0, 1.0));
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
    if (!_agreedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.registerMustAgreeTerms)),
      );
      return;
    }
    final ok = await ref.read(authControllerProvider.notifier).register(
          RegisterRequest(
            phone: _phoneE164,
            password: _passwordCtrl.text,
            fullName: _nameCtrl.text.trim(),
            role: _role,
            email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          ),
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
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      WasitLogo(size: 76),
                      Positioned(
                        bottom: -6,
                        left: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: c.background,
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                              color: c.verifiedBg,
                              shape: BoxShape.circle,
                              border: Border.all(color: c.verified),
                            ),
                            child: Icon(Icons.verified_rounded,
                                size: 14, color: c.verified),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.center,
                  child: CredentialPill(label: t.registerHeroPill),
                ),
                const SizedBox(height: 14),
                Text(
                  t.registerHeroTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  t.registerHeroSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textMuted, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 20),

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
                      // Role toggle w/ "step 1 of 2" indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(t.registerAccountType,
                              style: _labelStyle(c, big: true)),
                          Text(t.registerStep(1, 2),
                              style: TextStyle(
                                color: c.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              )),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _RoleToggle(
                        role: _role,
                        onChanged: (v) => setState(() => _role = v),
                      ),
                      const SizedBox(height: 14),
                      // Trust banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.shield_moon_outlined,
                                size: 20, color: c.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.registerTrustBannerTitle,
                                      style: TextStyle(
                                          color: c.text,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12)),
                                  const SizedBox(height: 2),
                                  Text(t.registerTrustBannerSub,
                                      style: TextStyle(
                                          color: c.textMuted, fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Full name
                      _FieldLabelRow(
                        label: t.fullName,
                        hint: t.registerFullNameHint,
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: t.registerFullNameExample,
                          prefixIcon: Icon(Icons.person_outline_rounded,
                              color: c.textMuted, size: 20),
                        ),
                        validator: (v) => (v == null || v.trim().length < 2)
                            ? t.namePleaseEnter
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // Phone
                      Text(t.phone, style: _labelStyle(c)),
                      const SizedBox(height: 6),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: IntlPhoneField(
                          decoration: const InputDecoration(hintText: '10XXXXXXXX'),
                          initialCountryCode: 'EG',
                          onChanged: (p) => _phoneE164 = p.completeNumber,
                          invalidNumberMessage: t.phoneInvalid,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Email
                      _FieldLabelRow(
                        label: t.emailField,
                        hint: t.registerEmailOptionalHint,
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'name@domain.com',
                          prefixIcon: Icon(Icons.mail_outline_rounded,
                              color: c.textMuted, size: 20),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Password + strength meter
                      _FieldLabelRow(
                        label: t.password,
                        hint: t.registerPasswordHint,
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: !_showPassword,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.lock_outline_rounded,
                              color: c.textMuted, size: 20),
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
                        validator: (v) => (v == null || v.length < 8)
                            ? t.passwordMin8
                            : null,
                      ),
                      const SizedBox(height: 8),
                      _PasswordStrengthBar(strength: _passwordStrength),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 12, color: c.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              t.registerPasswordRule,
                              style: TextStyle(color: c.textMuted, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Land-registry link opt-in
                      _CheckboxCard(
                        value: _linkRegistry,
                        onChanged: (v) => setState(() => _linkRegistry = v ?? false),
                        title: t.registerLinkRegistryTitle,
                        subtitle: t.registerLinkRegistrySub,
                        icon: Icons.account_balance_outlined,
                      ),
                      const SizedBox(height: 12),

                      // Terms checkbox
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _agreedTerms,
                            onChanged: (v) => setState(() => _agreedTerms = v ?? false),
                            visualDensity: VisualDensity.compact,
                            side: BorderSide(color: c.borderStrong),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                t.registerAgreeTerms,
                                style: TextStyle(
                                  color: c.text,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      FilledButton(
                        onPressed: state.submitting ? null : _submit,
                        child: state.submitting
                            ? SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: c.background),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(t.registerContinueCta),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_back_rounded, size: 18),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Trust footer: 3 columns ──────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _MiniTrustCard(
                        icon: Icons.shield_outlined,
                        iconColor: c.verified,
                        title: t.registerTrustEncrypted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniTrustCard(
                        icon: Icons.account_balance_outlined,
                        iconColor: c.accent,
                        title: t.registerTrustLicensed,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniTrustCard(
                        icon: Icons.support_agent_rounded,
                        iconColor: c.primary,
                        title: t.registerTrustSupport,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Already have account ──────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(t.registerPromptLogin,
                        style: TextStyle(color: c.textMuted, fontSize: 13)),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => context.go(Routes.login),
                      child: Text(
                        t.signIn,
                        style: TextStyle(
                          color: c.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _labelStyle(AppColors c, {bool big = false}) => TextStyle(
        color: c.text,
        fontSize: big ? 14 : 13,
        fontWeight: FontWeight.w700,
      );
}

/// Label row with the field name on the right (RTL leading) and a small
/// hint like "اختياري" or "كما في البطاقة" on the left.
class _FieldLabelRow extends StatelessWidget {
  const _FieldLabelRow({required this.label, required this.hint});
  final String label;
  final String hint;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: c.text, fontSize: 13, fontWeight: FontWeight.w700)),
        Text(hint,
            style: TextStyle(color: c.textMuted, fontSize: 11)),
      ],
    );
  }
}

/// Role picker matching the Stitch design's two-pill row.
class _RoleToggle extends StatelessWidget {
  const _RoleToggle({required this.role, required this.onChanged});
  final String role;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppL10n.of(context)!;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RoleChip(
              label: t.roleBuyer,
              icon: Icons.person_outline_rounded,
              active: role == 'buyer',
              onTap: () => onChanged('buyer'),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _RoleChip(
              label: t.registerRoleBrokerLicensed,
              icon: Icons.badge_outlined,
              active: role == 'broker',
              trailingBadge: t.registerRoleBrokerLicenseChip,
              onTap: () => onChanged('broker'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.trailingBadge,
  });
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final String? trailingBadge;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: active ? c.primary : Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16,
                  color: active ? c.background : c.textMuted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? c.background : c.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              if (trailingBadge != null && !active) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    trailingBadge!,
                    style: TextStyle(
                        color: c.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple 4-segment strength bar. Empty → 4 muted bars; grows as
/// [strength] climbs from 0 to 1.
class _PasswordStrengthBar extends StatelessWidget {
  const _PasswordStrengthBar({required this.strength});
  final double strength;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final segments = 4;
    final filled = (strength * segments).ceil().clamp(0, segments);
    final Color barColor = strength >= 0.75
        ? c.verified
        : strength >= 0.5
            ? c.primary
            : strength >= 0.25
                ? c.pending
                : c.rejected;
    return Row(
      children: List.generate(segments, (i) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i == segments - 1 ? 0 : 4),
            height: 4,
            decoration: BoxDecoration(
              color: i < filled ? barColor : c.surfaceHigh,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

/// Opt-in checkbox rendered as a big card with an icon + title + sub.
class _CheckboxCard extends StatelessWidget {
  const _CheckboxCard({
    required this.value,
    required this.onChanged,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  final bool value;
  final ValueChanged<bool?> onChanged;
  final String title;
  final String subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surfaceAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Checkbox(
                value: value,
                onChanged: onChanged,
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: c.borderStrong),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 16, color: c.verified),
                        const SizedBox(width: 6),
                        Text(title,
                            style: TextStyle(
                                color: c.text,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(color: c.textMuted, fontSize: 11)),
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

class _MiniTrustCard extends StatelessWidget {
  const _MiniTrustCard({
    required this.icon,
    required this.iconColor,
    required this.title,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: c.text, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
