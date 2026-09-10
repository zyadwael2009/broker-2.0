import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens. Whole app pulls colors from here so a palette change
/// never sprawls into feature code. Palette follows the 7-level Material 3
/// surface hierarchy from `proptech_trust_narrative/DESIGN.md` (Stitch),
/// tuned for high-contrast dark-first credential UI.
class AppColors {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceLowest,
    required this.surfaceLow,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textMuted,
    required this.textSubtle,
    required this.primary,
    required this.primaryHover,
    required this.primaryDark,
    required this.accent,
    required this.accentNavy,
    required this.verified,
    required this.verifiedBg,
    required this.verifiedLine,
    required this.pending,
    required this.pendingBg,
    required this.pendingLine,
    required this.rejected,
    required this.rejectedBg,
    required this.rejectedLine,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  /// Deepest tone in the 7-level hierarchy — page washes UNDER cards.
  final Color surfaceLowest;
  /// A hair above background — quiet section fills, empty-state canvases.
  final Color surfaceLow;
  /// Above surface — hovered rows, selected filter chips.
  final Color surfaceHigh;
  /// Top of the hierarchy — floating action bars, modal peaks.
  final Color surfaceHighest;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color textMuted;
  final Color textSubtle;
  final Color primary;
  final Color primaryHover;
  /// Deep teal used for `filled-tonal` variants of primary buttons and
  /// selected filter-chip backgrounds where a full-saturation primary
  /// would burn the eye.
  final Color primaryDark;
  final Color accent;
  /// Deep navy accent — reserved for credential-adjacent surfaces
  /// (broker public-profile pill, section labels that echo the web
  /// palette). Distinct from [accent] which is the star-rating gold.
  final Color accentNavy;
  final Color verified;
  final Color verifiedBg;
  final Color verifiedLine;
  final Color pending;
  final Color pendingBg;
  final Color pendingLine;
  final Color rejected;
  final Color rejectedBg;
  final Color rejectedLine;

  static const light = AppColors(
    background: Color(0xFFF5F7FA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEDF1F5),
    surfaceLowest: Color(0xFFF9FAFC),
    surfaceLow: Color(0xFFF1F4F8),
    surfaceHigh: Color(0xFFE5EAF0),
    surfaceHighest: Color(0xFFDBE1E8),
    border: Color(0xFFDFE6EC),
    borderStrong: Color(0xFFC6D0DA),
    text: Color(0xFF0C1418),
    textMuted: Color(0xFF566571),
    textSubtle: Color(0xFF8592A0),
    primary: Color(0xFF0B7CA8), // deeper Nile teal
    primaryHover: Color(0xFF096389),
    primaryDark: Color(0xFF00485E),
    accent: Color(0xFFE8973A), // gold, for star ratings
    accentNavy: Color(0xFF14213D), // matches the web credential page
    verified: Color(0xFF0E9F6E),
    verifiedBg: Color(0xFFDCF7EA),
    verifiedLine: Color(0xFF97E1C3),
    pending: Color(0xFFD97706),
    pendingBg: Color(0xFFFEF3D0),
    pendingLine: Color(0xFFF0CB7A),
    rejected: Color(0xFFD62D2D),
    rejectedBg: Color(0xFFFEE4E2),
    rejectedLine: Color(0xFFF3B0AC),
  );

  // Dark palette follows the 7-level surface hierarchy from
  // proptech_trust_narrative/DESIGN.md — each level ~4-6% brighter than
  // the last so nested containers stay visually distinct on OLED.
  //
  //   Lowest  Low   Bg   Surface Alt    High   Highest
  //   #070E1B #141C29 #0A121F #131C2C #1B2438 #222A38 #2D3543
  //
  // Bg/surface/alt keep the values that already ship (mobile app +
  // web already use these) so this only ADDS tones; nothing existing
  // shifts hex.
  static const dark = AppColors(
    background: Color(0xFF0A121F),      // page canvas
    surface: Color(0xFF131C2C),         // cards, app bar
    surfaceAlt: Color(0xFF1B2438),      // elevated modals, chips selected
    surfaceLowest: Color(0xFF070E1B),   // washes under listing photos
    surfaceLow: Color(0xFF141C29),      // section fills, empty states
    surfaceHigh: Color(0xFF222A38),     // hovered rows, selected chips
    surfaceHighest: Color(0xFF2D3543),  // floating bars, dropdown menus
    border: Color(0xFF253048),
    borderStrong: Color(0xFF3A4966),
    text: Color(0xFFE8ECF3),
    textMuted: Color(0xFF99A3B4),
    textSubtle: Color(0xFF6C7789),
    primary: Color(0xFF4CBEDA),
    primaryHover: Color(0xFF66CDE8),
    primaryDark: Color(0xFF0A6580),
    accent: Color(0xFFE5B84D),
    accentNavy: Color(0xFF7A93B5),
    verified: Color(0xFF4CC088),
    verifiedBg: Color(0xFF142B22),
    verifiedLine: Color(0xFF275544),
    pending: Color(0xFFF59E0B),
    pendingBg: Color(0xFF2D2210),
    pendingLine: Color(0x57F59E0B),
    rejected: Color(0xFFF17272),
    rejectedBg: Color(0x24F17272),
    rejectedLine: Color(0x57F17272),
  );
}

/// Access via `Theme.of(context).extension<AppColorsExt>()!.c`.
/// The [context.colors] extension below wraps that boilerplate.
class AppColorsExt extends ThemeExtension<AppColorsExt> {
  const AppColorsExt(this.c);
  final AppColors c;

  @override
  ThemeExtension<AppColorsExt> copyWith({AppColors? c}) =>
      AppColorsExt(c ?? this.c);

  @override
  ThemeExtension<AppColorsExt> lerp(
      covariant ThemeExtension<AppColorsExt>? other, double t) {
    // Palette swaps discretely at theme change; no interpolation needed.
    return this;
  }
}

extension BuildContextColors on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColorsExt>()!.c;
}

ThemeData _themeFrom(AppColors c, Brightness brightness) {
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.primary,
    onPrimary: Colors.white,
    secondary: c.accent,
    onSecondary: Colors.white,
    error: c.rejected,
    onError: Colors.white,
    surface: c.surface,
    onSurface: c.text,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    canvasColor: c.surface,
    dividerColor: c.border,
    extensions: [AppColorsExt(c)],
    appBarTheme: AppBarTheme(
      backgroundColor: c.surface,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      // Stitch specs a fixed 56px app bar with 16px horizontal padding.
      toolbarHeight: 56,
      titleSpacing: 16,
      titleTextStyle: TextStyle(
        color: c.text,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
      iconTheme: IconThemeData(color: c.text, size: 22),
      actionsIconTheme: IconThemeData(color: c.text, size: 22),
      surfaceTintColor: Colors.transparent,
      shape: Border(bottom: BorderSide(color: c.border)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      // Stitch specs a 44px input height; content padding lands us there.
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        // Focus ring: 1.6px border + a soft ambient glow via the
        // MaterialStates on child widgets. We mimic the CSS "ring" by
        // drawing a thicker focused border here.
        borderSide: BorderSide(color: c.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.rejected),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.rejected, width: 1.6),
      ),
      labelStyle: TextStyle(color: c.textMuted, fontWeight: FontWeight.w500),
      hintStyle: TextStyle(color: c.textMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        // Text on teal must be primary-ink (dark navy), not white.
        // Stitch's DESIGN.md § Buttons — Primary CTA.
        foregroundColor: brightness == Brightness.dark
            ? c.background          // dark bg = navy text on teal
            : Colors.white,         // light theme keeps white for contrast
        minimumSize: const Size.fromHeight(44),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.text,
        backgroundColor: c.surfaceAlt,
        minimumSize: const Size.fromHeight(44),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        side: BorderSide(color: c.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.primary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.border),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surfaceAlt,
      selectedColor: c.primary.withValues(alpha: 0.15),
      side: BorderSide(color: c.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: TextStyle(color: c.textMuted, fontWeight: FontWeight.w600, fontSize: 13),
      secondaryLabelStyle: TextStyle(color: c.primary, fontWeight: FontWeight.w600, fontSize: 13),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      indicatorColor: c.primary.withValues(alpha: 0.15),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? c.primary : c.textMuted,
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? c.primary : c.textMuted,
          size: 24,
        );
      }),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.surfaceHighest,
      contentTextStyle: TextStyle(color: c.text),
      actionTextColor: c.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    textTheme: _typography(c),
  );
}

TextTheme _typography(AppColors c) {
  // Cairo for Arabic body & headlines, Inter for Latin runs.
  // google_fonts loads both from Google's CDN on first launch, then
  // caches to disk. No .ttf assets to bundle. Arabic needs generous
  // line-height (1.5-1.6) so tashkeel and descenders don't clip.
  //
  // We use Cairo for the entire textTheme (it renders Latin cleanly
  // too via its Latin subset), then override the labelSmall/label
  // scales to Inter where we want the tighter tech feel.
  final baseCairo = GoogleFonts.cairoTextTheme(ThemeData(brightness: Brightness.dark).textTheme);

  TextStyle cairo({
    required double size,
    required FontWeight weight,
    Color? color,
    double height = 1.5,
    double letterSpacing = 0,
  }) =>
      baseCairo.bodyMedium!.copyWith(
        color: color ?? c.text,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
      );

  return TextTheme(
    // Headlines
    headlineLarge: cairo(size: 32, weight: FontWeight.w700, height: 1.4, letterSpacing: -0.3),
    headlineMedium: cairo(size: 26, weight: FontWeight.w700, height: 1.4, letterSpacing: -0.2),
    headlineSmall: cairo(size: 22, weight: FontWeight.w700, height: 1.4, letterSpacing: -0.2),
    // Titles
    titleLarge: cairo(size: 18, weight: FontWeight.w700, height: 1.5, letterSpacing: -0.1),
    titleMedium: cairo(size: 16, weight: FontWeight.w600, height: 1.5),
    titleSmall: cairo(size: 14, weight: FontWeight.w600, height: 1.5),
    // Body
    bodyLarge: cairo(size: 16, weight: FontWeight.w400, height: 1.6),
    bodyMedium: cairo(size: 14, weight: FontWeight.w400, height: 1.55),
    bodySmall: cairo(size: 12, weight: FontWeight.w400, color: c.textMuted, height: 1.55),
    // Labels
    labelLarge: cairo(size: 14, weight: FontWeight.w600, height: 1.4),
    labelMedium: cairo(size: 12, weight: FontWeight.w600, color: c.textMuted, height: 1.4),
    // Micro-label for empty states and section headers. Latin-style
    // uppercase tracking looks off in Arabic runs, so keep the Cairo
    // family but drop the wide letter-spacing.
    labelSmall: cairo(size: 11, weight: FontWeight.w600, color: c.textSubtle, height: 1.4),
  );
}

ThemeData buildLightTheme() => _themeFrom(AppColors.light, Brightness.light);
ThemeData buildDarkTheme()  => _themeFrom(AppColors.dark,  Brightness.dark);
