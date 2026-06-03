import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────
// Semantic color tokens via ThemeExtension
// ─────────────────────────────────────────────

class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color bg;
  final Color surface;
  final Color card;
  final Color cardAlt;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color divider;
  final Color inputFill;
  final Color inputBorder;

  const AppThemeColors({
    required this.bg,
    required this.surface,
    required this.card,
    required this.cardAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.divider,
    required this.inputFill,
    required this.inputBorder,
  });

  static AppThemeColors of(BuildContext context) =>
      Theme.of(context).extension<AppThemeColors>()!;

  // ── Taste-Skill: Dark Monochrome (Zinc 950/900) + High Contrast ──
  static const dark = AppThemeColors(
    bg: Color(0xFF09090B),          // Zinc 950
    surface: Color(0xFF09090B),     // Zinc 950
    card: Color(0xFF18181B),        // Zinc 900
    cardAlt: Color(0xFF27272A),     // Zinc 800
    textPrimary: Color(0xFFFAFAFA), // Zinc 50
    textSecondary: Color(0xFFA1A1AA), // Zinc 400
    textMuted: Color(0xFF71717A),     // Zinc 500
    divider: Color(0xFF27272A),       // Zinc 800
    inputFill: Color(0xFF09090B),
    inputBorder: Color(0xFF27272A),
  );

  // ── Taste-Skill: Light Monochrome (Pure White / Zinc 50) ──
  static const light = AppThemeColors(
    bg: Color(0xFFFAFAFA),       // Zinc 50
    surface: Color(0xFFF4F4F5),  // Zinc 100
    card: Color(0xFFFFFFFF),     // Pure White
    cardAlt: Color(0xFFE4E4E7),  // Zinc 200
    textPrimary: Color(0xFF09090B),   // Zinc 950
    textSecondary: Color(0xFF52525B), // Zinc 600
    textMuted: Color(0xFFA1A1AA),     // Zinc 400
    divider: Color(0xFFE4E4E7),       // Zinc 200
    inputFill: Color(0xFFFAFAFA),
    inputBorder: Color(0xFFE4E4E7),
  );

  static AppThemeColors createLight(Color primary) => light;

  @override
  AppThemeColors copyWith({
    Color? bg, Color? surface, Color? card, Color? cardAlt,
    Color? textPrimary, Color? textSecondary, Color? textMuted,
    Color? divider, Color? inputFill, Color? inputBorder,
  }) => AppThemeColors(
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    card: card ?? this.card,
    cardAlt: cardAlt ?? this.cardAlt,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textMuted: textMuted ?? this.textMuted,
    divider: divider ?? this.divider,
    inputFill: inputFill ?? this.inputFill,
    inputBorder: inputBorder ?? this.inputBorder,
  );

  @override
  AppThemeColors lerp(AppThemeColors? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardAlt: Color.lerp(cardAlt, other.cardAlt, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
    );
  }
}

// ─────────────────────────────────────────────
// Legacy static colors
// ─────────────────────────────────────────────

class AppColors {
  // Taste-Skill: Electric Blue (Saturated Pop)
  static Color primary = const Color(0xFF2563EB); // Blue 600
  static Color primaryLight = const Color(0xFF3B82F6); // Blue 500
  static Color primaryDark = const Color(0xFF1D4ED8); // Blue 700

  // Semantic
  static const success = Color(0xFF10B981); // Emerald 500
  static const warning = Color(0xFFF59E0B); // Amber 500
  static const danger = Color(0xFFEF4444);  // Red 500
  static const info = Color(0xFF0EA5E9);    // Sky 500

  static LinearGradient get primaryGradient => LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static void updateColors(Color brandColor, bool isDark) {
    primary = brandColor;
    if (isDark) {
      primaryLight = const Color(0xFF3B82F6);
      primaryDark = const Color(0xFF1E3A8A);
    } else {
      primaryLight = Color.alphaBlend(Colors.white.withValues(alpha: 0.2), brandColor);
      primaryDark = Color.alphaBlend(Colors.black.withValues(alpha: 0.2), brandColor);
    }
  }
}

// ─────────────────────────────────────────────
// ThemeData builders
// ─────────────────────────────────────────────

class AppTheme {
  // Taste-Skill: SHAPE CONSISTENCY LOCK (12px everywhere)
  static const double _radius = 12.0;

  static ThemeData darkTheme(Color primaryColor) => _buildTheme(Brightness.dark, AppThemeColors.dark, primaryColor);
  static ThemeData lightTheme(Color primaryColor) => _buildTheme(Brightness.light, AppThemeColors.light, primaryColor);

  static ThemeData _buildTheme(Brightness brightness, AppThemeColors colors, Color primaryColor) {
    final isDark = brightness == Brightness.dark;
    final base = isDark ? ThemeData.dark() : ThemeData.light();
    
    // Primary colors
    final primaryLight = Color.alphaBlend(Colors.white.withValues(alpha: 0.2), primaryColor);
    final primaryDark = Color.alphaBlend(Colors.black.withValues(alpha: 0.2), primaryColor);

    // Taste-Skill: Typography (Outfit for display, Inter for body - tracking tightened)
    final outfitTextTheme = GoogleFonts.outfitTextTheme(base.textTheme);
    final interTextTheme = GoogleFonts.interTextTheme(base.textTheme);

    final textTheme = base.textTheme.copyWith(
      displayLarge: outfitTextTheme.displayLarge?.copyWith(letterSpacing: -1.0, height: 1.1),
      displayMedium: outfitTextTheme.displayMedium?.copyWith(letterSpacing: -0.5, height: 1.1),
      displaySmall: outfitTextTheme.displaySmall?.copyWith(letterSpacing: -0.25, height: 1.1),
      headlineLarge: outfitTextTheme.headlineLarge?.copyWith(letterSpacing: -0.5, height: 1.2),
      headlineMedium: outfitTextTheme.headlineMedium?.copyWith(letterSpacing: -0.25, height: 1.2),
      headlineSmall: outfitTextTheme.headlineSmall?.copyWith(letterSpacing: 0, height: 1.2),
      titleLarge: outfitTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: outfitTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: outfitTextTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: interTextTheme.bodyLarge?.copyWith(letterSpacing: -0.01),
      bodyMedium: interTextTheme.bodyMedium?.copyWith(letterSpacing: -0.01),
      bodySmall: interTextTheme.bodySmall?.copyWith(letterSpacing: 0),
      labelLarge: interTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
      labelMedium: interTextTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
      labelSmall: interTextTheme.labelSmall?.copyWith(fontWeight: FontWeight.w500),
    ).apply(
      bodyColor: colors.textPrimary,
      displayColor: colors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      extensions: [colors],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: primaryLight,
        onSecondary: Colors.white,
        surface: colors.surface,
        onSurface: colors.textPrimary,
        error: AppColors.danger,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: colors.bg,
      cardColor: colors.card,
      dividerColor: colors.divider,
      dividerTheme: DividerThemeData(
        color: colors.divider.withValues(alpha: 0.5),
        thickness: 1,
        space: 0, // Taste-Skill: minimal space
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.bg,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20, fontWeight: FontWeight.w600, color: colors.textPrimary, letterSpacing: -0.5
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: colors.card,
        elevation: 0, // Taste-Skill: No shadows unless active elevation
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: BorderSide(color: colors.divider, width: 1), // Taste-Skill: 1px border instead of shadow
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.card,
        selectedItemColor: primaryColor,
        unselectedItemColor: colors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0, // No shadow
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: primaryLight, width: 2),
        ),
        hintStyle: TextStyle(color: colors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          elevation: 0, // Taste-Skill: No fake shadows
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const StadiumBorder(),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.card,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(_radius)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: BorderSide(color: colors.divider, width: 1),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: BorderSide(color: colors.divider, width: 1),
        ),
      ),
    );
  }
}
