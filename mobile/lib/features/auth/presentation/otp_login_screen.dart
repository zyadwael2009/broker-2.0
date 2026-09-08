import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../theme.dart';
import '../../shared/widgets/wasit_logo.dart';

/// Placeholder for the SMS-OTP-only sign-in path advertised on the
/// login screen's "Alternative sign-in" section. Full flow ships in
/// Phase 3 backend work — this screen exists now so the route target
/// resolves and users see a real "coming soon" screen instead of a
/// broken navigation.
///
/// TODO(phase3): replace with a two-step flow —
///   1. phone → POST /auth/login-otp/send
///   2. code  → POST /auth/login-otp/verify → JWT
class OtpLoginScreen extends ConsumerWidget {
  const OtpLoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context)!;
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(title: Text(t.otpLoginTitle)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                WasitLogo(size: 88),
                const SizedBox(height: 24),
                Text(
                  t.comingSoon,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  t.otpLoginComingSoon,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textMuted, height: 1.6),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.pop(),
                  child: Text(t.signIn),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
