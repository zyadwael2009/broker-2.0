import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../router.dart';
import '../../../theme.dart';
import '../../messaging/data/unread_provider.dart';

/// AppBar action that opens the inbox and renders a red dot when there
/// are unread messages. One provider drives it everywhere.
class InboxIconButton extends ConsumerWidget {
  const InboxIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context)!;
    final unread = ref.watch(unreadCountProvider);
    final c = context.colors;

    return IconButton(
      tooltip: t.messagesTooltip,
      onPressed: () => context.push(Routes.messages),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.forum_rounded),
          if (unread > 0)
            PositionedDirectional(
              top: -2,
              end: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                decoration: BoxDecoration(
                  color: c.rejected,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: c.surface, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
