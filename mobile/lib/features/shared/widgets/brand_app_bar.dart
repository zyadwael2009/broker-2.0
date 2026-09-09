import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../theme.dart';
import 'account_menu_button.dart';
import 'inbox_icon_button.dart';
import 'language_toggle_button.dart';
import 'theme_toggle_button.dart';
import 'wasit_logo.dart';

/// The branded top bar from the Stitch mockups (screens 3 and 5): the
/// logo tile on the leading edge, the wordmark with a "verified" pill
/// beside it, a one-line credential subtitle underneath, and the quick
/// actions (inbox, theme, language, account) trailing.
///
/// Used on the tab-level screens a user lands on. Pushed detail screens
/// keep a plain [AppBar] with a back arrow — repeating the brand block
/// on every screen would drown the thing the user tapped into.
class BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandAppBar({super.key, this.actions});

  /// Overrides the default action cluster when a screen needs its own.
  final List<Widget>? actions;

  // 56px (Stitch's app-bar spec) plus room for the credential subtitle.
  static const double _height = 64;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;

    return AppBar(
      toolbarHeight: _height,
      leadingWidth: 56,
      leading: const Padding(
        padding: EdgeInsets.only(left: 12, right: 4),
        child: Center(child: WasitLogo(size: 36)),
      ),
      titleSpacing: 4,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  t.appTitle,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: -0.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              _MiniVerifiedPill(label: t.statusVerified),
            ],
          ),
          Text(
            t.brandTagline,
            style: TextStyle(
              color: c.textMuted,
              fontSize: 11,
              height: 1.3,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      actions: actions ??
          const [
            InboxIconButton(),
            ThemeToggleButton(),
            LanguageToggleButton(),
            AccountMenuButton(),
          ],
    );
  }
}

/// A tighter [VerifiedBadge] — sized to sit inline with the wordmark
/// without pushing the app-bar row taller.
class _MiniVerifiedPill extends StatelessWidget {
  const _MiniVerifiedPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: c.verifiedBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.verifiedLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 11, color: c.verified),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: c.verified,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
