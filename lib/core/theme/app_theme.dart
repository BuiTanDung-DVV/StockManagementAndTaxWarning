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

  /// Convenience accessor
  static AppThemeColors of(BuildContext context) =>
      Theme.of(context).extension<AppThemeColors>()!;

  // ── Dark palette (Sleek Dark Obsidian & Space Navy) ──
  static const dark = AppThemeColors(
    bg: Color(0xFF080C16),          // deep space navy
    surface: Color(0xFF101625),     // dark container surface
    card: Color(0xFF171E30),        // elevated slate-navy card
    cardAlt: Color(0xFF20293F),     // high-contrast active state
    textPrimary: Color(0xFFF8FAFC), // crisp slate-50 white text
    textSecondary: Color(0xFFCBD5E1), // slate-300 secondary text
    textMuted: Color(0xFF64748B),     // slate-500 muted text
    divider: Color(0xFF1E293B),
    inputFill: Color(0xFF101625),
    inputBorder: Color(0xFF334155),
  );

  // ── Light palette (Lumina POS style - Vivid & Clean) ──
  static const light = AppThemeColors(
    bg: Color(0xFFF7F5FF),       // Lumina Background
    surface: Color(0xFFEFEFFF),  // Structural Sections (Surface Container Low)
    card: Color(0xFFFFFFFF),     // Interactive/Lifted (Lowest)
    cardAlt: Color(0xFFD5DBFF),  // Active States (Highest)
    textPrimary: Color(0xFF232C51),   // On Surface (no pure black)
    textSecondary: Color(0xFF515981), // On Surface Variant
    textMuted: Color(0xFFA2ABD7),     // Outline Variant (Ghost)
    divider: Color(0xFFD5DBFF),       // Soft tone shifts instead of hard lines
    inputFill: Color(0xFFEFEFFF),
    inputBorder: Color(0x26A2ABD7),   // 15% opacity Ghost Border
  );

  // ── Create dynamic light palette (Dynamic Tinting via HSLColor) ──
  static AppThemeColors createLight(Color primary) {
    final hsl = HSLColor.fromColor(primary);
    
    // Nền sáng và các thẻ (surface) pha nhẹ màu chính
    final bg = hsl.withLightness(0.97).withSaturation(0.08).toColor();
    final surface = hsl.withLightness(0.94).withSaturation(0.12).toColor();
    const card = Colors.white;
    final cardAlt = hsl.withLightness(0.88).withSaturation(0.18).toColor();
    
    // Chữ tương phản cao có sắc tố pha từ màu chính
    final textPrimary = hsl.withLightness(0.15).withSaturation(0.30).toColor();
    final textSecondary = hsl.withLightness(0.32).withSaturation(0.20).toColor();
    final textMuted = hsl.withLightness(0.50).withSaturation(0.15).toColor();
    
    final divider = hsl.withLightness(0.92).withSaturation(0.10).toColor();
    final inputFill = hsl.withLightness(0.96).withSaturation(0.06).toColor();
    final inputBorder = primary.withValues(alpha: 0.15);
    
    return AppThemeColors(
      bg: bg,
      surface: surface,
      card: card,
      cardAlt: cardAlt,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      textMuted: textMuted,
      divider: divider,
      inputFill: inputFill,
      inputBorder: inputBorder,
    );
  }

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
  static Color primary = const Color(0xFF0058BB);
  static Color primaryLight = const Color(0xFF6C9FFF);
  static Color primaryDark = const Color(0xFF004CA4);

  // Semantic
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFB31B25);
  static const info = Color(0xFF06B6D4);

  // Lumina Button Gradient
  static LinearGradient get primaryGradient => LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static void updateColors(Color brandColor, bool isDark) {
    primary = brandColor;
    if (isDark) {
      primaryLight = const Color(0xFF818CF8);
      primaryDark = const Color(0xFF312E81);
    } else {
      primaryLight = Color.alphaBlend(Colors.white.withValues(alpha: 0.35), brandColor);
      primaryDark = Color.alphaBlend(Colors.black.withValues(alpha: 0.25), brandColor);
    }
  }
}

// ─────────────────────────────────────────────
// ThemeData builders
// ─────────────────────────────────────────────

class AppTheme {
  static ThemeData darkTheme(Color primaryColor) => _buildTheme(Brightness.dark, AppThemeColors.dark, primaryColor);
  static ThemeData lightTheme(Color primaryColor) => _buildTheme(Brightness.light, AppThemeColors.createLight(primaryColor), primaryColor);

  static ThemeData _buildTheme(Brightness brightness, AppThemeColors colors, Color primaryColor) {
    final isDark = brightness == Brightness.dark;
    final base = isDark ? ThemeData.dark() : ThemeData.light();
    final primaryLight = Color.alphaBlend(Colors.white.withValues(alpha: 0.35), primaryColor);
    final primaryDark = Color.alphaBlend(Colors.black.withValues(alpha: 0.25), primaryColor);

    final outfitTextTheme = GoogleFonts.outfitTextTheme(base.textTheme);
    final interTextTheme = GoogleFonts.interTextTheme(base.textTheme);

    final textTheme = base.textTheme.copyWith(
      displayLarge: outfitTextTheme.displayLarge,
      displayMedium: outfitTextTheme.displayMedium,
      displaySmall: outfitTextTheme.displaySmall,
      headlineLarge: outfitTextTheme.headlineLarge,
      headlineMedium: outfitTextTheme.headlineMedium,
      headlineSmall: outfitTextTheme.headlineSmall,
      titleLarge: outfitTextTheme.titleLarge,
      titleMedium: outfitTextTheme.titleMedium,
      titleSmall: outfitTextTheme.titleSmall,
      bodyLarge: interTextTheme.bodyLarge,
      bodyMedium: interTextTheme.bodyMedium,
      bodySmall: interTextTheme.bodySmall,
      labelLarge: interTextTheme.labelLarge,
      labelMedium: interTextTheme.labelMedium,
      labelSmall: interTextTheme.labelSmall,
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
        color: colors.divider,
        thickness: 1,
        space: 16,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 22, fontWeight: FontWeight.bold, color: colors.textPrimary,
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: colors.card,
        elevation: isDark ? 0 : 0, // No shadow by default to preserve the glass feel
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), // xl corner radius
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.card,
        selectedItemColor: primaryColor,
        unselectedItemColor: colors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), // xl radius
          textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 2,
          shadowColor: primaryDark.withValues(alpha: 0.4),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.card.withValues(alpha: 0.9), // Glassmorphism base
        elevation: 20,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), // xl radius
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
