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

  // ── Dark palette (warm gray, high contrast) ──
  static const dark = AppThemeColors(
    bg: Color(0xFF111827),       // deep charcoal
    surface: Color(0xFF1F2937),   // elevated surface
    card: Color(0xFF1F2937),      // same as surface for consistency
    cardAlt: Color(0xFF273549),   // slightly lighter alt
    textPrimary: Color(0xFFF9FAFB),  // near-white for max readability
    textSecondary: Color(0xFFD1D5DB), // light gray — much more readable
    textMuted: Color(0xFF9CA3AF),     // medium gray — still visible
    divider: Color(0xFF374151),
    inputFill: Color(0xFF1F2937),
    inputBorder: Color(0xFF4B5563),   // visible border
  );

  // ── Light palette (clean, warm) ──
  static const light = AppThemeColors(
    bg: Color(0xFFF9FAFB),       // warm off-white
    surface: Colors.white,
    card: Colors.white,
    cardAlt: Color(0xFFF3F4F6),
    textPrimary: Color(0xFF111827),   // near-black for crisp text
    textSecondary: Color(0xFF4B5563), // dark gray
    textMuted: Color(0xFF9CA3AF),     // medium gray
    divider: Color(0xFFE5E7EB),
    inputFill: Color(0xFFF3F4F6),
    inputBorder: Color(0xFFD1D5DB),
  );

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
// Legacy static colors (semantic colors stay, dark-specific removed gradually)
// ─────────────────────────────────────────────

class AppColors {
  // Primary brand — vibrant blue
  static const primary = Color(0xFF3B82F6);
  static const primaryLight = Color(0xFF60A5FA);
  static const primaryDark = Color(0xFF2563EB);

  // Semantic — slightly adjusted for both modes
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const info = Color(0xFF06B6D4);

  // ── LEGACY dark-only references (kept for backward compat during migration) ──
  static const darkBg = Color(0xFF0F172A);
  static const darkSurface = Color(0xFF1E293B);
  static const darkCard = Color(0xFF16213E);
  static const darkCardAlt = Color(0xFF1A1A2E);
  static const lightBg = Color(0xFFF8FAFC);
  static const lightSurface = Colors.white;
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);
  static const textDark = Color(0xFF0F172A);

  // Gradients
  static const primaryGradient = LinearGradient(
    colors: [Color(0xFF1E3A5F), Color(0xFF2D8C8C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ─────────────────────────────────────────────
// ThemeData builders
// ─────────────────────────────────────────────

class AppTheme {
  static ThemeData get darkTheme => _buildTheme(Brightness.dark, AppThemeColors.dark);
  static ThemeData get lightTheme => _buildTheme(Brightness.light, AppThemeColors.light);

  static ThemeData _buildTheme(Brightness brightness, AppThemeColors colors) {
    final isDark = brightness == Brightness.dark;
    final base = isDark ? ThemeData.dark() : ThemeData.light();

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      extensions: [colors],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.primaryLight,
        onSecondary: Colors.white,
        surface: colors.surface,
        onSurface: colors.textPrimary,
        error: AppColors.danger,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: colors.bg,
      cardColor: colors.card,
      dividerColor: colors.divider,
      textTheme: GoogleFonts.beVietnamProTextTheme(base.textTheme).apply(
        bodyColor: colors.textPrimary,
        displayColor: colors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20, fontWeight: FontWeight.bold, color: colors.textPrimary,
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: colors.card,
        elevation: isDark ? 0 : 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: colors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        hintStyle: TextStyle(color: colors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.card,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.card,
      ),
    );
  }
}
