import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../theme.dart';

class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.status,
    this.subtitle,
    this.reason,
  });

  final String status;
  final String? subtitle;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final (bg, fg, line, icon, heading) = _tokens(status, c, t);

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: 8),
              Text(
                heading,
                style: TextStyle(
                  color: fg,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(color: c.textMuted, fontSize: 13, height: 1.4),
            ),
          ],
          if (reason != null && reason!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ReasonBox(reason: reason!),
          ],
        ],
      ),
    );
  }

  (Color, Color, Color, IconData, String) _tokens(
      String status, AppColors c, AppL10n t) {
    switch (status) {
      case 'verified':
        return (c.verifiedBg, c.verified, c.verifiedLine,
            Icons.verified_rounded, t.verifyStatusVerifiedHeading);
      case 'rejected':
        return (c.rejectedBg, c.rejected, c.rejectedLine,
            Icons.error_outline_rounded, t.verifyStatusRejectedHeading);
      case 'pending':
      default:
        return (c.pendingBg, c.pending, c.pendingLine,
            Icons.schedule_rounded, t.verifyStatusPendingHeading);
    }
  }
}

class _ReasonBox extends StatelessWidget {
  const _ReasonBox({required this.reason});
  final String reason;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    // Directional borders so the accent-rail stays on the leading edge
    // in both LTR and RTL.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        border: BorderDirectional(
          top: BorderSide(color: c.rejectedLine),
          end: BorderSide(color: c.rejectedLine),
          bottom: BorderSide(color: c.rejectedLine),
          start: BorderSide(color: c.rejected, width: 3),
        ),
        borderRadius: const BorderRadiusDirectional.only(
          topStart: Radius.circular(3),
          topEnd: Radius.circular(8),
          bottomStart: Radius.circular(3),
          bottomEnd: Radius.circular(8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.reviewerNote,
            style: TextStyle(
              color: c.rejected,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(reason, style: TextStyle(color: c.text, fontSize: 13, height: 1.45)),
        ],
      ),
    );
  }
}
