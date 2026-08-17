import 'package:flutter/material.dart';

/// Design tokens. The whole app pulls colors from here so a palette
/// change never sprawls into feature code. Two AppColors instances —
/// one for light, one for dark — are exposed as [BuildContext]
/// extensions on ThemeData below.
class AppColors {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textMuted,
    required this.textSubtle,
    required this.primary,
    required this.primaryHover,
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
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color textMuted;
  final Color textSubtle;
  final Color primary;
  final Color primaryHover;
  final Color accent;
  /// Deep navy accent — matches the web credential page. Reserved for
  /// credential-adjacent surfaces (the broker's public-profile pill,
  /// section labels that echo the web palette). Distinct from [accent]
  /// which is the star-rating gold.
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
    border: Color(0xFFDFE6EC),
    borderStrong: Color(0xFFC6D0DA),
    text: Color(0xFF0C1418),
    textMuted: Color(0xFF566571),
    textSubtle: Color(0xFF8592A0),
    primary: Color(0xFF0B7CA8), // deeper Nile teal
    primaryHover: Color(0xFF096389),
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

  static const dark = AppColors(
    background: Color(0xFF0B1116),
    surface: Color(0xFF151C22),
    surfaceAlt: Color(0xFF1D252C),
    border: Color(0xFF2A343D),
    borderStrong: Color(0xFF3B4753),
    text: Color(0xFFE8ECF1),
    textMuted: Color(0xFF99A4B0),
    textSubtle: Color(0xFF6C7783),
    primary: Color(0xFF4FBCE3),
    primaryHover: Color(0xFF6ECAEB),
    accent: Color(0xFFF3AE5E),
    accentNavy: Color(0xFF7A93B5), // lighter navy for dark surfaces
    verified: Color(0xFF4ADAA2),
    verifiedBg: Color(0x244ADAA2), // ~14% alpha
    verifiedLine: Color(0x524ADAA2), // ~32% alpha
    pending: Color(0xFFF0B045),
    pendingBg: Color(0x24F0B045),
    pendingLine: Color(0x57F0B045),
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
      titleTextStyle: TextStyle(
        color: c.text,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      iconTheme: IconThemeData(color: c.textMuted),
      surfaceTintColor: Colors.transparent,
      shape: Border(bottom: BorderSide(color: c.border)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
        borderSide: BorderSide(color: c.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.rejected),
      ),
      labelStyle: TextStyle(color: c.textMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.05,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.primary,
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: c.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: c.primary),
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
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.text,
      contentTextStyle: TextStyle(color: c.surface),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    textTheme: _typography(c),
  );
}

TextTheme _typography(AppColors c) {
  // Rely on the system sans (Roboto on Android, San Francisco on iOS).
  // Cairo bundling is a follow-up when we localize for Arabic.
  return TextTheme(
    headlineSmall: TextStyle(
      color: c.text, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.2,
    ),
    titleLarge: TextStyle(
      color: c.text, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.1,
    ),
    titleMedium: TextStyle(
      color: c.text, fontSize: 15, fontWeight: FontWeight.w600,
    ),
    titleSmall: TextStyle(
      color: c.text, fontSize: 13, fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(color: c.text, fontSize: 15, height: 1.4),
    bodyMedium: TextStyle(color: c.text, fontSize: 14, height: 1.4),
    bodySmall: TextStyle(color: c.textMuted, fontSize: 13, height: 1.4),
    labelLarge: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w600),
    labelMedium: TextStyle(color: c.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
    // Uppercase micro-label used across empty states and section headers.
    labelSmall: TextStyle(
      color: c.textSubtle,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.4,
    ),
  );
}

ThemeData buildLightTheme() => _themeFrom(AppColors.light, Brightness.light);
ThemeData buildDarkTheme()  => _themeFrom(AppColors.dark,  Brightness.dark);
