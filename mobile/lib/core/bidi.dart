import 'package:flutter/widgets.dart';

/// Text direction for *user-supplied* strings.
///
/// The UI chrome follows the app locale, but content does not: an English
/// listing title inside an Arabic UI (or an Arabic message inside the
/// English one) inherits the wrong direction and its trailing punctuation
/// jumps to the wrong end — "Is this still available?" renders as
/// "?Is this still available", and "+20155…" as "20155…+".
///
/// Resolves the way the Unicode bidi algorithm picks a paragraph
/// direction: first strong character wins, neutrals and digits are
/// skipped, and a string with no strong character at all (a bare phone
/// number) falls back to LTR, which is how numbers read everywhere.
TextDirection directionOf(String text) {
  for (final rune in text.runes) {
    // Arabic, Arabic Supplement/Extended, Hebrew, Arabic Presentation
    // Forms — the RTL ranges this product can realistically meet.
    final isRtl = (rune >= 0x0590 && rune <= 0x08FF) ||
        (rune >= 0xFB1D && rune <= 0xFDFF) ||
        (rune >= 0xFE70 && rune <= 0xFEFF);
    if (isRtl) return TextDirection.rtl;

    final isLatin = (rune >= 0x0041 && rune <= 0x005A) ||
        (rune >= 0x0061 && rune <= 0x007A) ||
        (rune >= 0x00C0 && rune <= 0x024F);
    if (isLatin) return TextDirection.ltr;
  }
  return TextDirection.ltr;
}
