import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../router.dart';
import '../../../theme.dart';
import '../../auth/presentation/auth_controller.dart';

/// Soft-flag reminder for accounts with phone_verified=false.
/// Sits above the buyer browse feed and broker my-listings. Renders
/// nothing if the user is already verified.
class VerifyPhoneBanner extends ConsumerWidget {
  const VerifyPhoneBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null || user.phoneVerified) return const SizedBox.shrink();

    final t = AppL10n.of(context)!;
    final c = context.colors;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: c.pendingBg,
        border: Border.all(color: c.pendingLine),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.sms_rounded, size: 20, color: c.pending),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t.verifyBannerText,
              style: TextStyle(
                color: c.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => context.push(Routes.verifyPhone),
            style: TextButton.styleFrom(
              foregroundColor: c.pending,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(t.verifyBannerCta),
          ),
        ],
      ),
    );
  }
}
