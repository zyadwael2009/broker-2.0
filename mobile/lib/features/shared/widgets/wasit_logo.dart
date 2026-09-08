import 'package:flutter/material.dart';

import '../../../theme.dart';

/// Branded logomark — the teal Wasit pin on a rounded-square dark tile,
/// matching how it appears in every Stitch mockup's hero.
///
/// Sizes to whatever [size] the caller gives. The inner mark is 60%
/// of the tile so the surrounding square reads as a rounded card.
class WasitLogo extends StatelessWidget {
  const WasitLogo({super.key, this.size = 72});
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: c.border),
      ),
      alignment: Alignment.center,
      child: Padding(
        // Inset the transparent-fg PNG so the mark centers optically —
        // the pin's tail visually shifts the mass upward, so we pad the
        // top a touch more than the bottom.
        padding: EdgeInsets.only(
          top: size * 0.18,
          bottom: size * 0.14,
          left: size * 0.20,
          right: size * 0.20,
        ),
        child: Image.asset(
          'assets/icon/app_icon_fg.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

/// Small "credential" trust pill used in auth-flow heroes:
/// "اعتماد رسمي وسجل عقاري إلكتروني" style.
class CredentialPill extends StatelessWidget {
  const CredentialPill({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.verifiedBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.verified.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 14, color: c.verified),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: c.verified,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
