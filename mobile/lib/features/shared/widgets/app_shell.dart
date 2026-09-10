import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../router.dart';
import '../../../theme.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../messaging/data/unread_provider.dart';

/// Persistent bottom navigation matching the 4-tab design from Stitch:
///
///   تصفح (browse)  ·  عقاراتي / المفضلة (role-swap)  ·  محادثات (inbox)  ·  حسابي
///
/// Each authed content screen embeds this in its `bottomNavigationBar`
/// slot. `currentTab` tells the widget which one to draw as active.
///
/// Not a StatefulShellRoute — this is a plain Widget with imperative
/// `context.go()` navigation. Tab state (scroll position, filters) is
/// not preserved across tab switches; that's a deliberate trade-off
/// for a much smaller router refactor.
class AppBottomNav extends ConsumerWidget {
  const AppBottomNav({super.key, required this.currentTab});

  final AppTab currentTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final auth = ref.watch(authControllerProvider);
    final unread = ref.watch(unreadCountProvider);
    final role = auth.user?.role ?? 'buyer';

    // Tab 2 ("mine") is role-dependent.
    final mineIcon = switch (role) {
      'broker' => Icons.apartment_rounded,
      'admin' => Icons.shield_outlined,
      _ => Icons.favorite_border_rounded,
    };
    final mineLabel = switch (role) {
      'broker' => t.navMyListings,
      'admin' => t.navAdminQueue,
      _ => t.navSaved,
    };
    final mineRoute = switch (role) {
      'broker' => Routes.brokerListings,
      'admin' => Routes.adminQueue,
      _ => Routes.savedListings,
    };

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: NavigationBar(
        selectedIndex: currentTab.index,
        onDestinationSelected: (i) {
          final dest = AppTab.values[i];
          if (dest == currentTab) return;
          switch (dest) {
            case AppTab.browse:
              context.go(Routes.home);
              break;
            case AppTab.mine:
              context.go(mineRoute);
              break;
            case AppTab.messages:
              context.go(Routes.messages);
              break;
            case AppTab.account:
              context.go(Routes.account);
              break;
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.search_rounded),
            selectedIcon: const Icon(Icons.search_rounded),
            label: t.navBrowse,
          ),
          NavigationDestination(
            icon: Icon(mineIcon),
            selectedIcon: Icon(mineIcon),
            label: mineLabel,
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 99 ? '99+' : '$unread'),
              backgroundColor: c.primary,
              textColor: c.background,
              child: const Icon(Icons.chat_bubble_outline_rounded),
            ),
            selectedIcon: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 99 ? '99+' : '$unread'),
              backgroundColor: c.primary,
              textColor: c.background,
              child: const Icon(Icons.chat_bubble_rounded),
            ),
            label: t.navMessages,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: t.navAccount,
          ),
        ],
      ),
    );
  }
}

/// Discriminates which nav-bar tab a screen belongs to.
enum AppTab { browse, mine, messages, account }
