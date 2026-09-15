import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  static const EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  static const EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);
}

class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
}

extension TextStyleContext on BuildContext {
  TextTheme get textStyles => Theme.of(this).textTheme;
}

extension TextStyleExtensions on TextStyle {
  TextStyle get bold => copyWith(fontWeight: FontWeight.bold);
  TextStyle get extraBold => copyWith(fontWeight: FontWeight.w800);
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);
  TextStyle get normal => copyWith(fontWeight: FontWeight.w400);
  TextStyle get light => copyWith(fontWeight: FontWeight.w300);
  TextStyle withColor(Color color) => copyWith(color: color);
  TextStyle withSize(double size) => copyWith(fontSize: size);
}

// CRED-style colors
class AppColors {
  // Dark Mode (Default)
  static const darkBackground = Color(0xFF000000); // Pure black
  static const darkCard = Color(0xFF1A1A1A);
  static const darkSurface = Color(0xFF2C2C2E);
  static const credTeal = Color(0xFF00D09C); // CRED accent
  static const profitGreen = Color(0xFF00C853);
  static const lossRed = Color(0xFFFF3B30);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF8E8E93);
  
  // Light Mode
  static const lightBackground = Color(0xFFF8F9FA);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFF0F0F0);
  static const lightTextPrimary = Color(0xFF000000);
  static const lightTextSecondary = Color(0xFF666666);
}

class FontSizes {
  static const double display = 40.0; // For amount display
  static const double headingXL = 32.0;
  static const double headingLarge = 28.0;
  static const double headingMedium = 22.0;
  static const double titleLarge = 18.0;
  static const double bodyMedium = 14.0;
  static const double caption = 12.0;
}

ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.dark(
    primary: AppColors.credTeal,
    onPrimary: AppColors.darkBackground,
    surface: AppColors.darkCard,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.darkSurface,
    error: AppColors.lossRed,
    onError: AppColors.textPrimary,
  ),
  scaffoldBackgroundColor: AppColors.darkBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: AppColors.textPrimary,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
  ),
  cardTheme: CardThemeData(
    color: AppColors.darkCard,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      side: BorderSide(
        color: Colors.white.withValues(alpha: 0.1),
        width: 1,
      ),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.credTeal,
      foregroundColor: AppColors.darkBackground,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      textStyle: GoogleFonts.manrope(fontSize: FontSizes.bodyMedium, fontWeight: FontWeight.w600),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.textPrimary,
      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      textStyle: GoogleFonts.manrope(fontSize: FontSizes.bodyMedium, fontWeight: FontWeight.w600),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.credTeal,
      textStyle: GoogleFonts.manrope(fontSize: FontSizes.bodyMedium, fontWeight: FontWeight.w600),
    ),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: AppColors.credTeal,
    foregroundColor: AppColors.darkBackground,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.darkSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: const BorderSide(color: AppColors.credTeal, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: const BorderSide(color: AppColors.lossRed),
    ),
    contentPadding: AppSpacing.paddingMd,
    hintStyle: GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: FontSizes.bodyMedium),
    labelStyle: GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: FontSizes.bodyMedium),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: AppColors.darkCard,
    selectedItemColor: AppColors.credTeal,
    unselectedItemColor: AppColors.textSecondary,
    type: BottomNavigationBarType.fixed,
    elevation: 0,
    selectedLabelStyle: GoogleFonts.manrope(fontSize: FontSizes.caption, fontWeight: FontWeight.w600),
    unselectedLabelStyle: GoogleFonts.manrope(fontSize: FontSizes.caption, fontWeight: FontWeight.w500),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.darkSurface,
    labelStyle: GoogleFonts.manrope(color: AppColors.textPrimary, fontSize: FontSizes.caption),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
  ),
  textTheme: _buildTextTheme(Brightness.dark),
  iconTheme: const IconThemeData(color: AppColors.textPrimary),
);

ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.light(
    primary: AppColors.credTeal,
    onPrimary: AppColors.lightBackground,
    surface: AppColors.lightCard,
    onSurface: AppColors.lightTextPrimary,
    surfaceContainerHighest: AppColors.lightSurface,
    error: AppColors.lossRed,
    onError: AppColors.textPrimary,
  ),
  scaffoldBackgroundColor: AppColors.lightBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: AppColors.lightTextPrimary,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
  ),
  cardTheme: CardThemeData(
    color: AppColors.lightCard,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      side: BorderSide(color: Colors.black.withValues(alpha: 0.05), width: 1),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.credTeal,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      textStyle: GoogleFonts.manrope(fontSize: FontSizes.bodyMedium, fontWeight: FontWeight.w600),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.lightTextPrimary,
      side: BorderSide(color: Colors.black.withValues(alpha: 0.2)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      textStyle: GoogleFonts.manrope(fontSize: FontSizes.bodyMedium, fontWeight: FontWeight.w600),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.credTeal,
      textStyle: GoogleFonts.manrope(fontSize: FontSizes.bodyMedium, fontWeight: FontWeight.w600),
    ),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: AppColors.credTeal,
    foregroundColor: Colors.white,
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.lightSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: const BorderSide(color: AppColors.credTeal, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: const BorderSide(color: AppColors.lossRed),
    ),
    contentPadding: AppSpacing.paddingMd,
    hintStyle: GoogleFonts.manrope(color: AppColors.lightTextSecondary, fontSize: FontSizes.bodyMedium),
    labelStyle: GoogleFonts.manrope(color: AppColors.lightTextSecondary, fontSize: FontSizes.bodyMedium),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: AppColors.lightCard,
    selectedItemColor: AppColors.credTeal,
    unselectedItemColor: AppColors.lightTextSecondary,
    type: BottomNavigationBarType.fixed,
    elevation: 8,
    selectedLabelStyle: GoogleFonts.manrope(fontSize: FontSizes.caption, fontWeight: FontWeight.w600),
    unselectedLabelStyle: GoogleFonts.manrope(fontSize: FontSizes.caption, fontWeight: FontWeight.w500),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.lightSurface,
    labelStyle: GoogleFonts.manrope(color: AppColors.lightTextPrimary, fontSize: FontSizes.caption),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
  ),
  textTheme: _buildTextTheme(Brightness.light),
  iconTheme: const IconThemeData(color: AppColors.lightTextPrimary),
);

TextTheme _buildTextTheme(Brightness brightness) {
  final color = brightness == Brightness.dark ? AppColors.textPrimary : AppColors.lightTextPrimary;
  return TextTheme(
    displayLarge: GoogleFonts.manrope(fontSize: FontSizes.display, fontWeight: FontWeight.bold, color: color, fontFeatures: [const FontFeature.tabularFigures()]),
    displayMedium: GoogleFonts.manrope(fontSize: FontSizes.headingXL, fontWeight: FontWeight.w800, color: color),
    displaySmall: GoogleFonts.manrope(fontSize: FontSizes.headingLarge, fontWeight: FontWeight.w800, color: color),
    headlineLarge: GoogleFonts.manrope(fontSize: FontSizes.headingLarge, fontWeight: FontWeight.w800, color: color),
    headlineMedium: GoogleFonts.manrope(fontSize: FontSizes.headingMedium, fontWeight: FontWeight.w700, color: color),
    headlineSmall: GoogleFonts.manrope(fontSize: FontSizes.titleLarge, fontWeight: FontWeight.w700, color: color),
    titleLarge: GoogleFonts.manrope(fontSize: FontSizes.titleLarge, fontWeight: FontWeight.w600, color: color),
    titleMedium: GoogleFonts.manrope(fontSize: FontSizes.bodyMedium, fontWeight: FontWeight.w600, color: color),
    titleSmall: GoogleFonts.manrope(fontSize: FontSizes.caption, fontWeight: FontWeight.w600, color: color),
    bodyLarge: GoogleFonts.manrope(fontSize: FontSizes.bodyMedium, fontWeight: FontWeight.w500, color: color),
    bodyMedium: GoogleFonts.manrope(fontSize: FontSizes.bodyMedium, fontWeight: FontWeight.w400, color: color),
    bodySmall: GoogleFonts.manrope(fontSize: FontSizes.caption, fontWeight: FontWeight.w400, color: color),
    labelLarge: GoogleFonts.manrope(fontSize: FontSizes.bodyMedium, fontWeight: FontWeight.w600, color: color),
    labelMedium: GoogleFonts.manrope(fontSize: FontSizes.caption, fontWeight: FontWeight.w500, color: color),
    labelSmall: GoogleFonts.manrope(fontSize: FontSizes.caption, fontWeight: FontWeight.w400, color: color),
  );
}
