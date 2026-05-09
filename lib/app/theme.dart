/// Pocket Claw Material 3 Dark Theme
///
/// Bronze + Amber on warm near-black palette (AGENTIC OS-inspired refresh).
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PocketClawTheme {
  PocketClawTheme._();

  // Backgrounds — warm near-black, no blue tint.
  static const Color deepCharcoal = Color(0xFF0A0805); // app scaffold
  static const Color surface = Color(0xFF181410); // cards, modals
  static const Color surfaceContainerLow = Color(0xFF241D17); // stat cards, inputs

  // Accents.
  static const Color bronze = Color(0xFFC76A2E); // primary action, progress fill
  static const Color amber = Color(0xFFFF8B47); // highlights, hot states

  // Backward-compat alias — many screens reference `electricTeal`. Same name,
  // new colour. Kept rather than renamed to avoid sweep churn.
  static const Color electricTeal = amber;

  // Text.
  static const Color onSurface = Color(0xFFEDE6DD); // body white
  static const Color onSurfaceMuted = Color(0xFF7A6E62); // labels, helpers

  // Status semantics — keep these distinguishable.
  static const Color lobsterRed = Color(0xFFD33B1A); // destructive / errors only
  static const Color success = Color(0xFF6FAE5C); // success indicators
  static const Color warning = Color(0xFFE0A02E); // warnings (paired with bronze)

  // Surface variants — derived from the new neutral ramp.
  static const Color surfaceDim = deepCharcoal;
  static const Color surfaceBright = Color(0xFF2E251D);
  static const Color surfaceContainer = surface;
  static const Color surfaceContainerHigh = Color(0xFF2A221B);

  static final ColorScheme colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: bronze,
    onPrimary: Colors.white,
    primaryContainer: bronze.withAlpha(50),
    onPrimaryContainer: bronze.withAlpha(230),
    secondary: amber,
    onSecondary: Colors.black,
    secondaryContainer: amber.withAlpha(50),
    onSecondaryContainer: amber.withAlpha(230),
    tertiary: warning,
    onTertiary: Colors.black,
    error: lobsterRed,
    onError: Colors.white,
    surface: surface,
    onSurface: onSurface,
    onSurfaceVariant: onSurfaceMuted,
    outline: const Color(0xFF3A2F26),
    outlineVariant: const Color(0xFF2A2018),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: onSurface,
    onInverseSurface: deepCharcoal,
    inversePrimary: bronze,
    surfaceContainerHighest: surfaceContainerHigh,
  );

  static TextTheme get _baseTextTheme {
    return TextTheme(
      displayLarge: GoogleFonts.jetBrainsMono(
        fontSize: 32,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: GoogleFonts.jetBrainsMono(
        fontSize: 28,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: GoogleFonts.jetBrainsMono(
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
      headlineLarge: GoogleFonts.jetBrainsMono(
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: GoogleFonts.jetBrainsMono(
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: GoogleFonts.jetBrainsMono(
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
      titleLarge: GoogleFonts.jetBrainsMono(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.jetBrainsMono(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
      ),
      bodyLarge: const TextStyle(fontSize: 16),
      bodyMedium: const TextStyle(fontSize: 14),
      bodySmall: const TextStyle(fontSize: 12),
      labelLarge: GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
      labelMedium: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.6,
      ),
      labelSmall: GoogleFonts.jetBrainsMono(
        fontSize: 10,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.8,
      ),
    );
  }

  static ThemeData get darkTheme {
    final textTheme = _baseTextTheme.apply(
      bodyColor: onSurface,
      displayColor: onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: deepCharcoal,
      textTheme: textTheme,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: deepCharcoal,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: GoogleFonts.jetBrainsMono(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: onSurface,
          letterSpacing: 0.4,
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outline.withAlpha(80)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: deepCharcoal,
        selectedItemColor: bronze,
        unselectedItemColor: onSurfaceMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.jetBrainsMono(
          fontSize: 10,
        ),
      ),

      // Navigation Bar (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: deepCharcoal,
        indicatorColor: bronze.withAlpha(40),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: bronze);
          }
          return const IconThemeData(color: onSurfaceMuted);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: bronze,
            );
          }
          return GoogleFonts.jetBrainsMono(
            fontSize: 10,
            color: onSurfaceMuted,
          );
        }),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline.withAlpha(120)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: bronze, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: onSurface.withAlpha(100)),
      ),

      // Elevated button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: bronze,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.jetBrainsMono(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ),

      // Outlined button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: bronze,
          side: const BorderSide(color: bronze),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.jetBrainsMono(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ),

      // Text button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: amber,
          textStyle: GoogleFonts.jetBrainsMono(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Floating action button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: bronze,
        foregroundColor: Colors.white,
        elevation: 4,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: surfaceContainerLow,
        selectedColor: bronze.withAlpha(40),
        side: BorderSide(color: colorScheme.outline.withAlpha(80)),
        labelStyle: GoogleFonts.jetBrainsMono(fontSize: 11),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: colorScheme.outline.withAlpha(80),
        thickness: 1,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Tabs
      tabBarTheme: TabBarThemeData(
        labelColor: bronze,
        unselectedLabelColor: onSurfaceMuted,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: bronze, width: 2),
        ),
        labelStyle: GoogleFonts.jetBrainsMono(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
        unselectedLabelStyle: GoogleFonts.jetBrainsMono(
          fontSize: 13,
          letterSpacing: 0.4,
        ),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return bronze;
          return onSurfaceMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return bronze.withAlpha(80);
          }
          return surfaceContainerLow;
        }),
      ),

      // Progress indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: bronze,
        linearTrackColor: surfaceContainerLow,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceContainerHigh,
        contentTextStyle: TextStyle(color: onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
