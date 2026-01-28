import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

/// Liquid Vitality Design System for Sophis
/// A warm, organic aesthetic that celebrates nourishment
class AppTheme {
  // ═══════════════════════════════════════════════════════════════════════════
  // ORGANIC COLOR PALETTE - Food-inspired, warm and inviting
  // ═══════════════════════════════════════════════════════════════════════════

  // Primary Accent Colors (User-selectable)
  static const Color accent = Color(0xFF6366F1); // Indigo - default

  // Semantic Colors - Organic, food-inspired
  static const Color success = Color(0xFF059669); // Emerald green - fresh vegetables
  static const Color warning = Color(0xFFD97706); // Amber - honey, grains
  static const Color error = Color(0xFFDC2626); // Tomato red
  static const Color water = Color(0xFF0891B2); // Cyan - fresh water
  static const Color fire = Color(0xFFF97316); // Orange - energy, citrus

  // Macro Colors - Distinctive and memorable
  static const Color protein = Color(0xFF059669); // Emerald - lean, healthy
  static const Color carbs = Color(0xFFD97706); // Amber - energy, warmth
  static const Color fat = Color(0xFFE11D48); // Rose - rich, indulgent

  // Light Theme Palette
  static const Color _lightBg = Color(0xFFFFFBF7); // Warm cream
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightSurfaceAlt = Color(0xFFFFF8F0); // Soft peach tint
  static const Color _lightText = Color(0xFF1C1917); // Warm black
  static const Color _lightTextSecondary = Color(0xFF78716C); // Stone
  static const Color _lightBorder = Color(0xFFE7E5E4); // Stone border

  // Dark Theme Palette
  static const Color _darkBg = Color(0xFF0C0A09); // Rich black
  static const Color _darkSurface = Color(0xFF1C1917); // Warm dark
  static const Color _darkSurfaceAlt = Color(0xFF292524); // Stone dark
  static const Color _darkText = Color(0xFFFAFAF9); // Warm white
  static const Color _darkTextSecondary = Color(0xFFA8A29E); // Stone light
  static const Color _darkBorder = Color(0xFF44403C); // Stone border dark

  // Gradient Mesh Colors for backgrounds
  static const List<Color> lightMeshColors = [
    Color(0xFFFFF7ED), // Orange 50
    Color(0xFFFDF4FF), // Fuchsia 50
    Color(0xFFF0FDF4), // Green 50
    Color(0xFFFFFBEB), // Amber 50
  ];

  static const List<Color> darkMeshColors = [
    Color(0xFF1C1917), // Stone 900
    Color(0xFF1E1B4B), // Indigo 950
    Color(0xFF14532D), // Green 900
    Color(0xFF451A03), // Amber 950
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // ANIMATION SYSTEM - Fluid, springy, alive
  // ═══════════════════════════════════════════════════════════════════════════

  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 300);
  static const Duration animSlow = Duration(milliseconds: 500);
  static const Duration animSlower = Duration(milliseconds: 800);

  // Spring Curves for organic motion
  static const Curve springCurve = Curves.elasticOut;
  static const Curve bounceCurve = Curves.bounceOut;
  static const Curve fluidCurve = Curves.easeOutCubic;

  // ═══════════════════════════════════════════════════════════════════════════
  // SHAPE SYSTEM - Organic, fluid borders
  // ═══════════════════════════════════════════════════════════════════════════

  static const double radiusXS = 8;
  static const double radiusSM = 12;
  static const double radiusMD = 16;
  static const double radiusLG = 24;
  static const double radiusXL = 32;
  static const double radiusFull = 9999;

  // Organic blob-like border radius
  static BorderRadius get blobRadius => const BorderRadius.only(
        topLeft: Radius.circular(32),
        topRight: Radius.circular(24),
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(36),
      );

  static BorderRadius get blobRadiusAlt => const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(36),
        bottomLeft: Radius.circular(32),
        bottomRight: Radius.circular(20),
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // SPACING SYSTEM
  // ═══════════════════════════════════════════════════════════════════════════

  static const double spaceXS = 4;
  static const double spaceSM = 8;
  static const double spaceMD = 16;
  static const double spaceLG = 24;
  static const double spaceXL = 32;
  static const double space2XL = 48;

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGE TRANSITIONS - Smooth and fluid
  // ═══════════════════════════════════════════════════════════════════════════

  static Route<T> fadeRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: child,
        );
      },
      transitionDuration: animNormal,
    );
  }

  static Route<T> slideRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: fluidCurve));

        final scaleAnimation = Tween<double>(
          begin: 0.98,
          end: 1.0,
        ).animate(CurvedAnimation(parent: animation, curve: fluidCurve));

        return SlideTransition(
          position: offsetAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          ),
        );
      },
      transitionDuration: animNormal,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // THEME BUILDERS
  // ═══════════════════════════════════════════════════════════════════════════

  static ThemeData lightThemeWithAccent(Color accentColor) {
    return _buildLightTheme(accentColor);
  }

  static ThemeData darkThemeWithAccent(Color accentColor) {
    return _buildDarkTheme(accentColor);
  }

  static ThemeData get lightTheme => _buildLightTheme(accent);
  static ThemeData get darkTheme => _buildDarkTheme(accent);

  static ThemeData _buildLightTheme(Color accentColor) {
    final textTheme = _buildTextTheme(_lightText, _lightTextSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentColor,
        brightness: Brightness.light,
      ).copyWith(
        primary: accentColor,
        secondary: accentColor.withValues(alpha: 0.8),
        surface: _lightSurface,
        surfaceContainerHighest: _lightSurfaceAlt,
        error: error,
        onSurface: _lightText,
        onSurfaceVariant: _lightTextSecondary,
      ),
      scaffoldBackgroundColor: _lightBg,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: _lightText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.dmSerifDisplay(
          color: _lightText,
          fontSize: 24,
          fontWeight: FontWeight.w400,
        ),
        iconTheme: IconThemeData(color: _lightText.withValues(alpha: 0.8)),
      ),
      cardTheme: CardThemeData(
        color: _lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLG),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: _lightBorder.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightSurfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: BorderSide(color: accentColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: BorderSide(color: error, width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle:
            GoogleFonts.plusJakartaSans(color: _lightTextSecondary, fontSize: 15),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusFull),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentColor,
          side: BorderSide(color: accentColor.withValues(alpha: 0.3), width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusFull),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentColor,
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLG),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _lightSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        dragHandleColor: _lightBorder,
        dragHandleSize: const Size(40, 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXL),
        ),
        titleTextStyle: GoogleFonts.dmSerifDisplay(
          color: _lightText,
          fontSize: 22,
          fontWeight: FontWeight.w400,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _lightText,
        contentTextStyle: GoogleFonts.plusJakartaSans(color: _lightSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      iconTheme: IconThemeData(color: _lightTextSecondary, size: 22),
      textTheme: textTheme,
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _lightSurfaceAlt,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusFull),
        ),
        side: BorderSide.none,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accentColor,
        linearTrackColor: accentColor.withValues(alpha: 0.1),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accentColor;
          return _lightBorder;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accentColor.withValues(alpha: 0.3);
          }
          return _lightSurfaceAlt;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accentColor,
        inactiveTrackColor: accentColor.withValues(alpha: 0.1),
        thumbColor: accentColor,
        overlayColor: accentColor.withValues(alpha: 0.1),
        trackHeight: 6,
      ),
    );
  }

  static ThemeData _buildDarkTheme(Color accentColor) {
    final textTheme = _buildTextTheme(_darkText, _darkTextSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentColor,
        brightness: Brightness.dark,
      ).copyWith(
        primary: accentColor,
        secondary: accentColor.withValues(alpha: 0.8),
        surface: _darkSurface,
        surfaceContainerHighest: _darkSurfaceAlt,
        error: error,
        onSurface: _darkText,
        onSurfaceVariant: _darkTextSecondary,
      ),
      scaffoldBackgroundColor: _darkBg,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: _darkText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.dmSerifDisplay(
          color: _darkText,
          fontSize: 24,
          fontWeight: FontWeight.w400,
        ),
        iconTheme: IconThemeData(color: _darkText.withValues(alpha: 0.8)),
      ),
      cardTheme: CardThemeData(
        color: _darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLG),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: _darkBorder.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: BorderSide(color: accentColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: BorderSide(color: error, width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle:
            GoogleFonts.plusJakartaSans(color: _darkTextSecondary, fontSize: 15),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusFull),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentColor,
          side: BorderSide(color: accentColor.withValues(alpha: 0.3), width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusFull),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentColor,
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLG),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _darkSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        dragHandleColor: _darkBorder,
        dragHandleSize: const Size(40, 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXL),
        ),
        titleTextStyle: GoogleFonts.dmSerifDisplay(
          color: _darkText,
          fontSize: 22,
          fontWeight: FontWeight.w400,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _darkText,
        contentTextStyle: GoogleFonts.plusJakartaSans(color: _darkSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      iconTheme: IconThemeData(color: _darkTextSecondary, size: 22),
      textTheme: textTheme,
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _darkSurfaceAlt,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusFull),
        ),
        side: BorderSide.none,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accentColor,
        linearTrackColor: accentColor.withValues(alpha: 0.1),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accentColor;
          return _darkBorder;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accentColor.withValues(alpha: 0.3);
          }
          return _darkSurfaceAlt;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accentColor,
        inactiveTrackColor: accentColor.withValues(alpha: 0.1),
        thumbColor: accentColor,
        overlayColor: accentColor.withValues(alpha: 0.1),
        trackHeight: 6,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TYPOGRAPHY - DM Serif Display (headers) + Plus Jakarta Sans (body)
  // ═══════════════════════════════════════════════════════════════════════════

  static TextTheme _buildTextTheme(Color primaryColor, Color secondaryColor) {
    return TextTheme(
      // Display - Large hero text
      displayLarge: GoogleFonts.dmSerifDisplay(
        fontSize: 48,
        fontWeight: FontWeight.w400,
        color: primaryColor,
        letterSpacing: -1,
      ),
      displayMedium: GoogleFonts.dmSerifDisplay(
        fontSize: 40,
        fontWeight: FontWeight.w400,
        color: primaryColor,
        letterSpacing: -0.5,
      ),
      displaySmall: GoogleFonts.dmSerifDisplay(
        fontSize: 32,
        fontWeight: FontWeight.w400,
        color: primaryColor,
      ),
      // Headlines - Section titles
      headlineLarge: GoogleFonts.dmSerifDisplay(
        fontSize: 28,
        fontWeight: FontWeight.w400,
        color: primaryColor,
      ),
      headlineMedium: GoogleFonts.dmSerifDisplay(
        fontSize: 24,
        fontWeight: FontWeight.w400,
        color: primaryColor,
      ),
      headlineSmall: GoogleFonts.dmSerifDisplay(
        fontSize: 20,
        fontWeight: FontWeight.w400,
        color: primaryColor,
      ),
      // Titles - Card headers, list items
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: primaryColor,
        letterSpacing: -0.2,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primaryColor,
        letterSpacing: 0,
      ),
      titleSmall: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primaryColor,
        letterSpacing: 0.1,
      ),
      // Body - Paragraphs, descriptions
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: primaryColor,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: primaryColor,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: secondaryColor,
        height: 1.4,
      ),
      // Labels - Buttons, chips, captions
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primaryColor,
        letterSpacing: 0.5,
      ),
      labelMedium: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: primaryColor,
        letterSpacing: 0.5,
      ),
      labelSmall: GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: secondaryColor,
        letterSpacing: 0.5,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get gradient for macro type
  static LinearGradient getMacroGradient(String macro) {
    switch (macro.toLowerCase()) {
      case 'protein':
        return LinearGradient(
          colors: [protein, protein.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'carbs':
        return LinearGradient(
          colors: [carbs, carbs.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'fat':
        return LinearGradient(
          colors: [fat, fat.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return LinearGradient(
          colors: [accent, accent.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  /// Get color for macro type
  static Color getMacroColor(String macro) {
    switch (macro.toLowerCase()) {
      case 'protein':
        return protein;
      case 'carbs':
        return carbs;
      case 'fat':
        return fat;
      default:
        return accent;
    }
  }

  /// Soft gradient background
  static BoxDecoration softGradientDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? darkMeshColors : lightMeshColors;

    return BoxDecoration(
      gradient: LinearGradient(
        colors: [colors[0], colors[1].withValues(alpha: 0.5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }

  /// Glass card decoration
  static BoxDecoration glassDecoration(BuildContext context, {Color? tint}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = tint ?? (isDark ? _darkSurface : _lightSurface);

    return BoxDecoration(
      color: baseColor.withValues(alpha: isDark ? 0.8 : 0.9),
      borderRadius: BorderRadius.circular(radiusLG),
      border: Border.all(
        color: (isDark ? _darkBorder : _lightBorder).withValues(alpha: 0.3),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  /// Accent gradient decoration
  static BoxDecoration accentGradientDecoration(Color accentColor) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [accentColor, accentColor.withValues(alpha: 0.8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radiusLG),
      boxShadow: [
        BoxShadow(
          color: accentColor.withValues(alpha: 0.3),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CUSTOM PAINTERS - Organic shapes and effects
// ═══════════════════════════════════════════════════════════════════════════

/// Painter for organic blob shapes
class BlobPainter extends CustomPainter {
  final Color color;
  final double animationValue;

  BlobPainter({required this.color, this.animationValue = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Create organic blob shape with slight animation
    final offset = math.sin(animationValue * math.pi * 2) * 5;

    path.moveTo(w * 0.2, 0);
    path.quadraticBezierTo(w * 0.5, -10 + offset, w * 0.8, 0);
    path.quadraticBezierTo(w + 10, h * 0.3, w, h * 0.7);
    path.quadraticBezierTo(w * 0.7, h + 5 - offset, w * 0.3, h);
    path.quadraticBezierTo(-5, h * 0.6, 0, h * 0.3);
    path.quadraticBezierTo(w * 0.1, -5 + offset, w * 0.2, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(BlobPainter oldDelegate) =>
      color != oldDelegate.color ||
      animationValue != oldDelegate.animationValue;
}

/// Painter for gradient mesh background
class GradientMeshPainter extends CustomPainter {
  final List<Color> colors;
  final double animationValue;

  GradientMeshPainter({required this.colors, this.animationValue = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Create multiple overlapping radial gradients for mesh effect
    for (int i = 0; i < colors.length; i++) {
      final angle = (i / colors.length) * math.pi * 2 + animationValue;
      final centerX = size.width * (0.5 + 0.3 * math.cos(angle));
      final centerY = size.height * (0.5 + 0.3 * math.sin(angle));

      final gradient = RadialGradient(
        center: Alignment(
          (centerX / size.width) * 2 - 1,
          (centerY / size.height) * 2 - 1,
        ),
        radius: 1.2,
        colors: [
          colors[i].withValues(alpha: 0.4),
          colors[i].withValues(alpha: 0.0),
        ],
      );

      final paint = Paint()..shader = gradient.createShader(rect);
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(GradientMeshPainter oldDelegate) =>
      colors != oldDelegate.colors ||
      animationValue != oldDelegate.animationValue;
}
