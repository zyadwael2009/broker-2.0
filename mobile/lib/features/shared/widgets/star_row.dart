import 'package:flutter/material.dart';

import '../../../theme.dart';

/// Star row in two modes:
///   const StarRow(value: 4.5, size: 14)                  → read-only
///   StarRow.interactive(value: initial, onChanged: (v){})→ 1..5 picker
class StarRow extends StatelessWidget {
  const StarRow({
    super.key,
    required this.value,
    this.size = 16,
    this.color,
  }) : onChanged = null, _interactive = false;

  const StarRow.interactive({
    super.key,
    required this.value,
    required ValueChanged<int> this.onChanged,
    this.size = 32,
    this.color,
  }) : _interactive = true;

  /// 0..5 (double for read; int in practice for interactive).
  final double value;
  final double size;
  final Color? color;
  final ValueChanged<int>? onChanged;
  final bool _interactive;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = color ?? c.accent; // Egyptian-gold accent
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starIndex = i + 1;
        final filled = value >= starIndex;
        final half = !filled && value >= starIndex - 0.5;
        Widget icon = Icon(
          filled
              ? Icons.star_rounded
              : half
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded,
          size: size,
          color: filled || half ? tint : c.textSubtle,
        );
        if (!_interactive) return icon;
        return InkResponse(
          onTap: () => onChanged!(starIndex),
          radius: size * 0.9,
          child: Padding(padding: const EdgeInsets.all(2), child: icon),
        );
      }),
    );
  }
}
