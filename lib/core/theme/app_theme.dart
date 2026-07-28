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

  // ── High Contrast Dark Palette (Deep Midnight FinTech) ──
  static const dark = AppThemeColors(
    bg: Color(0xFF0E1420),
    surface: Color(0xFF141C29),
    card: Color(0xFF182230),
    cardAlt: Color(0xFF202B3B),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFFCBD5E1),
    textMuted: Color(0xFF94A3B8),
    divider: Color(0xFF2C394B),
    inputFill: Color(0xFF141C29),
    inputBorder: Color(0xFF3A485B),
  );

  // ── High Contrast Light Palette (Crisp Porcelain FinTech) ──
  static const light = AppThemeColors(
    bg: Color(0xFFF6F8FB),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    cardAlt: Color(0xFFF1F4F8),
    textPrimary: Color(0xFF101828),
    textSecondary: Color(0xFF475467),
    textMuted: Color(0xFF667085),
    divider: Color(0xFFDDE2EA),
    inputFill: Color(0xFFFFFFFF),
    inputBorder: Color(0xFFD0D5DD),
  );

  static AppThemeColors createLight(Color primary) => light;

  @override
  AppThemeColors copyWith({
    Color? bg,
    Color? surface,
    Color? card,
    Color? cardAlt,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? divider,
    Color? inputFill,
    Color? inputBorder,
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
  static Color primary = const Color(0xFF155EEF);
  static Color primaryLight = const Color(0xFF2970FF);
  static Color primaryDark = const Color(0xFF004EEB);

  // Semantic
  static const success = Color(0xFF10B981); // Emerald 500
  static const warning = Color(0xFFF59E0B); // Amber 500
  static const danger = Color(0xFFEF4444); // Red 500
  static const info = Color(0xFF0EA5E9); // Sky 500

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
      primaryLight = Color.alphaBlend(
        Colors.white.withValues(alpha: 0.2),
        brandColor,
      );
      primaryDark = Color.alphaBlend(
        Colors.black.withValues(alpha: 0.2),
        brandColor,
      );
    }
  }
}

// ─────────────────────────────────────────────
// ThemeData builders
// ─────────────────────────────────────────────

abstract final class AppBreakpoints {
  static const double compactNavigation = 800;
  static const double expandedNavigation = 1100;
}

abstract final class AppRadius {
  static const double control = 8;
  static const double card = 10;
  static const double dialog = 16;
}

abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;
  static const double xxxl = 48;
}

class AppTheme {
  static const double _cardRadius = AppRadius.card;
  static const double _inputRadius = AppRadius.control;

  static const diffusionShadow = BoxShadow(
    color: Color(0x0F101828),
    blurRadius: 12,
    offset: Offset(0, 4),
    spreadRadius: -4,
  );

  static TextStyle tabularStyle(
    BuildContext context, {
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? AppThemeColors.of(context).textPrimary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static ThemeData darkTheme(Color primaryColor) =>
      _buildTheme(Brightness.dark, AppThemeColors.dark, primaryColor);
  static ThemeData lightTheme(Color primaryColor) =>
      _buildTheme(Brightness.light, AppThemeColors.light, primaryColor);

  static ThemeData _buildTheme(
    Brightness brightness,
    AppThemeColors colors,
    Color primaryColor,
  ) {
    final isDark = brightness == Brightness.dark;
    final base = isDark ? ThemeData.dark() : ThemeData.light();

    // Primary colors
    final primaryLight = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.2),
      primaryColor,
    );
    final outfitTextTheme = GoogleFonts.outfitTextTheme(base.textTheme);
    final bodyTextTheme = GoogleFonts.interTextTheme(base.textTheme);

    final textTheme = base.textTheme
        .copyWith(
          displayLarge: outfitTextTheme.displayLarge?.copyWith(
            letterSpacing: -1.5,
            height: 1.1,
            fontWeight: FontWeight.w800,
          ),
          displayMedium: outfitTextTheme.displayMedium?.copyWith(
            letterSpacing: -1.0,
            height: 1.1,
            fontWeight: FontWeight.w800,
          ),
          displaySmall: outfitTextTheme.displaySmall?.copyWith(
            letterSpacing: -0.5,
            height: 1.1,
            fontWeight: FontWeight.w700,
          ),
          headlineLarge: outfitTextTheme.headlineLarge?.copyWith(
            letterSpacing: -0.5,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
          headlineMedium: outfitTextTheme.headlineMedium?.copyWith(
            letterSpacing: -0.25,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
          headlineSmall: outfitTextTheme.headlineSmall?.copyWith(
            letterSpacing: 0,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
          titleLarge: outfitTextTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          titleMedium: outfitTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          titleSmall: outfitTextTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: bodyTextTheme.bodyLarge?.copyWith(letterSpacing: -0.01),
          bodyMedium: bodyTextTheme.bodyMedium?.copyWith(letterSpacing: -0.01),
          bodySmall: bodyTextTheme.bodySmall?.copyWith(letterSpacing: 0),
          labelLarge: bodyTextTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          labelMedium: bodyTextTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          labelSmall: bodyTextTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        )
        .apply(bodyColor: colors.textPrimary, displayColor: colors.textPrimary);

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
        backgroundColor: colors.surface,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: Border(bottom: BorderSide(color: colors.divider, width: 1)),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: colors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
          side: BorderSide(color: colors.divider, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.card,
        selectedItemColor: primaryColor,
        unselectedItemColor: colors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0, // No shadow
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        elevation: 0,
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primaryColor.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return bodyTextTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? primaryColor
                : colors.textMuted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        elevation: 0,
        backgroundColor: colors.surface,
        indicatorColor: primaryColor.withValues(alpha: 0.12),
        selectedLabelTextStyle: bodyTextTheme.labelSmall?.copyWith(
          color: primaryColor,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: bodyTextTheme.labelSmall?.copyWith(
          color: colors.textMuted,
          fontWeight: FontWeight.w500,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
          borderSide: BorderSide(color: primaryLight, width: 2),
        ),
        hintStyle: TextStyle(color: colors.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_inputRadius),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_inputRadius),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          side: BorderSide(color: colors.inputBorder),
          foregroundColor: colors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_inputRadius),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_inputRadius),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
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
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.dialog),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
          side: BorderSide(color: colors.divider, width: 1),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
          side: BorderSide(color: colors.divider, width: 1),
        ),
      ),
    );
  }
}
