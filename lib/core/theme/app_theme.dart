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

  // Deep navy palette for long operational sessions.
  static const dark = AppThemeColors(
    bg: Color(0xFF0B1420),
    surface: Color(0xFF111D2B),
    card: Color(0xFF172536),
    cardAlt: Color(0xFF1E3044),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFFD0DAE6),
    textMuted: Color(0xFF91A3B8),
    divider: Color(0xFF2A3C50),
    inputFill: Color(0xFF101C29),
    inputBorder: Color(0xFF3B5067),
  );

  // Cool neutral palette used by established retail and finance products.
  static const light = AppThemeColors(
    bg: Color(0xFFEEF3F7),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    cardAlt: Color(0xFFF3F7FA),
    textPrimary: Color(0xFF10283A),
    textSecondary: Color(0xFF3F5668),
    textMuted: Color(0xFF687F93),
    divider: Color(0xFFD3DEE8),
    inputFill: Color(0xFFFFFFFF),
    inputBorder: Color(0xFFBFCEDB),
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
  static Color primary = const Color(0xFF1769AA);
  static Color primaryLight = const Color(0xFF2E83C4);
  static Color primaryDark = const Color(0xFF0D4F82);

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
  static const double card = 12;
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
    color: Color(0x1A17324D),
    blurRadius: 20,
    offset: Offset(0, 8),
    spreadRadius: -12,
  );

  static TextStyle tabularStyle(
    BuildContext context, {
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
  }) {
    return GoogleFonts.inter(
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
    final headingTextTheme = GoogleFonts.manropeTextTheme(base.textTheme);
    final bodyTextTheme = GoogleFonts.interTextTheme(base.textTheme);

    final textTheme = base.textTheme
        .copyWith(
          displayLarge: headingTextTheme.displayLarge?.copyWith(
            letterSpacing: -1.5,
            height: 1.1,
            fontWeight: FontWeight.w800,
          ),
          displayMedium: headingTextTheme.displayMedium?.copyWith(
            letterSpacing: -1.0,
            height: 1.1,
            fontWeight: FontWeight.w800,
          ),
          displaySmall: headingTextTheme.displaySmall?.copyWith(
            letterSpacing: -0.5,
            height: 1.1,
            fontWeight: FontWeight.w700,
          ),
          headlineLarge: headingTextTheme.headlineLarge?.copyWith(
            letterSpacing: -0.5,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
          headlineMedium: headingTextTheme.headlineMedium?.copyWith(
            letterSpacing: -0.25,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
          headlineSmall: headingTextTheme.headlineSmall?.copyWith(
            letterSpacing: 0,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
          titleLarge: headingTextTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          titleMedium: headingTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          titleSmall: headingTextTheme.titleSmall?.copyWith(
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
        titleTextStyle: GoogleFonts.manrope(
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
        shadowColor: const Color(0x2417324D),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
          side: BorderSide(color: colors.divider.withValues(alpha: 0.9)),
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
        height: 68,
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
        labelStyle: TextStyle(
          color: colors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
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
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.textSecondary,
          backgroundColor: colors.cardAlt,
          minimumSize: const Size(40, 40),
          side: BorderSide(color: colors.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_inputRadius),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.card,
        selectedColor: primaryColor.withValues(alpha: 0.1),
        disabledColor: colors.cardAlt,
        side: BorderSide(color: colors.divider),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        labelStyle: bodyTextTheme.labelMedium?.copyWith(
          color: colors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: bodyTextTheme.labelMedium?.copyWith(
          color: primaryColor,
          fontWeight: FontWeight.w700,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(44, 40)),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? primaryColor.withValues(alpha: 0.1)
                : colors.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? primaryColor
                : colors.textSecondary;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: colors.divider)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_inputRadius),
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            bodyTextTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: primaryColor,
        textColor: colors.textPrimary,
        subtitleTextStyle: bodyTextTheme.bodySmall?.copyWith(
          color: colors.textSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
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
        elevation: 8,
        shadowColor: const Color(0x2617324D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
          side: BorderSide(color: colors.divider, width: 1),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(
          Color.alphaBlend(primaryColor.withValues(alpha: 0.055), colors.cardAlt),
        ),
        headingTextStyle: bodyTextTheme.labelSmall?.copyWith(
          color: colors.textSecondary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.35,
        ),
        dataTextStyle: bodyTextTheme.bodyMedium?.copyWith(
          color: colors.textPrimary,
        ),
        dividerThickness: 1,
        horizontalMargin: 18,
        columnSpacing: 24,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(6),
        thumbColor: WidgetStatePropertyAll(
          colors.textMuted.withValues(alpha: 0.35),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.textPrimary,
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        textStyle: bodyTextTheme.bodySmall?.copyWith(color: colors.bg),
        waitDuration: const Duration(milliseconds: 450),
      ),
    );
  }
}
