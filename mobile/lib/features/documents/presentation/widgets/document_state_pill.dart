import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../../theme.dart';
import '../../data/models.dart';

class DocumentStatePill extends StatelessWidget {
  const DocumentStatePill({super.key, required this.state, this.compact = false});

  final String state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final spec = _specFor(state, c, t);

    return Container(
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
          Icon(spec.icon, size: compact ? 12 : 13, color: spec.fg),
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
    );
  }

  static _PillSpec _specFor(String state, AppColors c, AppL10n t) {
    switch (state) {
      case DocumentStates.verified:
        return _PillSpec(t.adminVerified, Icons.verified_rounded,
            c.verified, c.verifiedBg, c.verifiedLine);
      case DocumentStates.pending:
        return _PillSpec(t.awaitingReview, Icons.schedule_rounded,
            c.pending, c.pendingBg, c.pendingLine);
      case DocumentStates.rejected:
        return _PillSpec(t.statusRejected, Icons.close_rounded,
            c.rejected, c.rejectedBg, c.rejectedLine);
      case DocumentStates.selfReported:
        return _PillSpec(t.selfReported, Icons.person_outline_rounded,
            c.textMuted, c.surfaceAlt, c.border);
      case DocumentStates.unset:
      default:
        return _PillSpec(t.notProvided, Icons.remove_rounded,
            c.textSubtle, c.surfaceAlt, c.border);
    }
  }
}

class _PillSpec {
  const _PillSpec(this.label, this.icon, this.fg, this.bg, this.line);
  final String label;
  final IconData icon;
  final Color fg;
  final Color bg;
  final Color line;
}
