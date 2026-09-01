import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/delete_account_dialog.dart';

/// AppBar action wrapping the sign-out and delete-account entries in a
/// single overflow menu. Replaces the standalone logout IconButton across
/// screens so the destructive "delete account" is discoverable (Play
/// User Data policy) without being one accidental tap away.
class AccountMenuButton extends ConsumerWidget {
  const AccountMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context)!;
    return PopupMenuButton<_AccountAction>(
      tooltip: t.signOut,
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (action) {
        switch (action) {
          case _AccountAction.signOut:
            ref.read(authControllerProvider.notifier).logout();
            break;
          case _AccountAction.deleteAccount:
            showDialog<void>(
              context: context,
              builder: (_) => const DeleteAccountDialog(),
            );
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _AccountAction.signOut,
          child: Row(
            children: [
              const Icon(Icons.logout_rounded, size: 18),
              const SizedBox(width: 10),
              Text(t.signOut),
            ],
          ),
        ),
        PopupMenuItem(
          value: _AccountAction.deleteAccount,
          child: Row(
            children: [
              Icon(Icons.delete_forever_outlined,
                  size: 18, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 10),
              Text(
                t.deleteAccount,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _AccountAction { signOut, deleteAccount }
