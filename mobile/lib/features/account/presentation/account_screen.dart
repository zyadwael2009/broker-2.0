import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../core/bidi.dart';
import '../../../router.dart';
import '../../../theme.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/delete_account_dialog.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/language_toggle_button.dart';
import '../../shared/widgets/theme_toggle_button.dart';
import '../../shared/widgets/verified_badge.dart';

/// Account tab — user profile + settings. Consolidates what used to
/// live in the AppBar overflow menu (sign out, delete account, theme
/// toggle, language toggle) into a proper first-class screen the
/// bottom nav can reach.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: Text(t.navAccount)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Profile header card
          if (user != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: c.surfaceHigh,
                    child: Text(
                      user.fullName.isNotEmpty ? user.fullName[0] : '?',
                      style: TextStyle(
                        color: c.text, fontSize: 22, fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.fullName,
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text(
                          user.phone,
                          // A bare phone number has no strong character,
                          // so it must be pinned LTR or the leading + flips.
                          textDirection: directionOf(user.phone),
                          style: TextStyle(color: c.textMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        if (user.role == 'broker' && auth.brokerProfile != null)
                          VerifiedBadge(
                            status: auth.brokerProfile!.verificationStatus,
                            compact: true,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // Preferences group
          _SectionHeader(label: t.accountPreferences),
          const SizedBox(height: 8),
          _SettingsRow(
            leading: Icons.brightness_6_outlined,
            title: t.accountTheme,
            trailing: const ThemeToggleButton(),
          ),
          _SettingsRow(
            leading: Icons.language_outlined,
            title: t.accountLanguage,
            trailing: const LanguageToggleButton(),
          ),

          _SettingsRow(
            leading: Icons.query_stats_rounded,
            title: t.priceTransparency,
            onTap: () => context.push(Routes.marketPrices),
          ),

          const SizedBox(height: 20),

          // Account actions group
          _SectionHeader(label: t.accountActions),
          const SizedBox(height: 8),
          _SettingsRow(
            leading: Icons.logout_rounded,
            title: t.signOut,
            onTap: () => ref.read(authControllerProvider.notifier).logout(),
          ),
          _SettingsRow(
            leading: Icons.delete_forever_outlined,
            title: t.deleteAccount,
            danger: true,
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => const DeleteAccountDialog(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentTab: AppTab.account),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 4, left: 4, bottom: 4),
      child: Text(
        label,
        style: TextStyle(
          color: c.textSubtle,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.leading,
    required this.title,
    this.trailing,
    this.onTap,
    this.danger = false,
  });
  final IconData leading;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = danger ? c.rejected : c.text;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(leading, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
