import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../theme.dart';

/// The trust-status pill for a broker. Localized via AppL10n.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, required this.status, this.compact = false});

  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final spec = _spec(status, c, t);

    return Semantics(
      label: '${spec.label} status',
      container: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 3 : 4,
        ),
        decoration: BoxDecoration(
          color: spec.bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: spec.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(spec.icon, size: compact ? 12 : 14, color: spec.fg),
            SizedBox(width: compact ? 4 : 5),
            Text(
              spec.label,
              style: TextStyle(
                color: spec.fg,
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static _BadgeSpec _spec(String status, AppColors c, AppL10n t) {
    switch (status) {
      case 'verified':
        return _BadgeSpec(
            t.statusVerified, Icons.check_rounded, c.verified, c.verifiedBg, c.verifiedLine);
      case 'rejected':
        return _BadgeSpec(
            t.statusRejected, Icons.close_rounded, c.rejected, c.rejectedBg, c.rejectedLine);
      case 'pending':
      default:
        return _BadgeSpec(
            t.statusPending, Icons.schedule_rounded, c.pending, c.pendingBg, c.pendingLine);
    }
  }
}

class _BadgeSpec {
  const _BadgeSpec(this.label, this.icon, this.fg, this.bg, this.line);
  final String label;
  final IconData icon;
  final Color fg;
  final Color bg;
  final Color line;
}
