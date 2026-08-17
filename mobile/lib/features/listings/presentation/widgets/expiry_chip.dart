import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../../theme.dart';
import '../../data/models.dart';

class ExpiryChip extends StatelessWidget {
  const ExpiryChip({super.key, required this.listing});
  final ListingDto listing;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final days = listing.daysUntilExpiry();

    late final Color fg;
    late final Color bg;
    late final Color line;
    late final IconData icon;
    late final String label;

    if (listing.isExpired || (days != null && days <= 0)) {
      fg = c.rejected;
      bg = c.rejectedBg;
      line = c.rejectedLine;
      icon = Icons.error_outline_rounded;
      label = t.expiryExpired;
    } else if (days != null && days <= 5) {
      fg = c.pending;
      bg = c.pendingBg;
      line = c.pendingLine;
      icon = Icons.schedule_rounded;
      label = t.expiryDaysLeft(days);
    } else if (days != null) {
      fg = c.verified;
      bg = c.verifiedBg;
      line = c.verifiedLine;
      icon = Icons.check_circle_outline_rounded;
      label = t.expiryActive(days);
    } else {
      fg = c.textMuted;
      bg = c.surfaceAlt;
      line = c.border;
      icon = Icons.help_outline_rounded;
      label = listing.status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
