library;

import 'package:flutter/material.dart';

class HCTheme {
  HCTheme._();

  static const bgBase = Color(0xFF0D1117);
  static const bgPanel = Color(0xFF161B22);
  static const bgSurface = Color(0xFF1C2128);
  static const bgActive = Color(0xFF21262D);
  static const bgInput = Color(0xFF0D1117);

  static const border = Color(0xFF30363D);
  static const borderMuted = Color(0xFF21262D);

  static const textPrimary = Color(0xFFE6EDF3);
  static const textSecondary = Color(0xFF8B949E);
  static const textMuted = Color(0xFF484F58);
  static const textLink = Color(0xFF58A6FF);

  static const gold = Color(0xFFC9A227);
  static const goldLight = Color(0xFFD4A017);
  static const goldMuted = Color(0xFF8B6914);
  static const goldBg = Color(0xFF1A1509);

  static const statusGreen = Color(0xFF3FB950);
  static const statusAmber = Color(0xFFF0883E);
  static const statusBlue = Color(0xFF58A6FF);
  static const statusRed = Color(0xFFF85149);
  static const statusMuted = Color(0xFF6E7681);

  static ThemeData get theme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgBase,
    colorScheme: const ColorScheme.dark(
      surface: bgPanel,
      surfaceContainerHighest: bgSurface,
      primary: gold,
      secondary: goldLight,
      onPrimary: bgBase,
      onSurface: textPrimary,
      outline: border,
      error: statusRed,
    ),
    fontFamily: 'GeistSans',
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 18,
        color: textPrimary,
      ),
      titleMedium: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: textPrimary,
      ),
      titleSmall: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 12,
        color: textSecondary,
      ),
      bodyLarge: TextStyle(fontSize: 14, color: textPrimary, height: 1.6),
      bodyMedium: TextStyle(fontSize: 13, color: textPrimary, height: 1.5),
      bodySmall: TextStyle(fontSize: 11, color: textSecondary, height: 1.4),
      labelLarge: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 12,
        color: textPrimary,
      ),
      labelSmall: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 10,
        color: textSecondary,
      ),
    ),
    cardTheme: CardThemeData(
      color: bgSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: border),
      ),
    ),
    dividerColor: border,
    appBarTheme: const AppBarTheme(
      backgroundColor: bgPanel,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 14,
        fontFamily: 'GeistSans',
      ),
      iconTheme: IconThemeData(color: textSecondary, size: 18),
      actionsIconTheme: IconThemeData(color: textSecondary, size: 18),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: bgPanel,
      indicatorColor: bgActive,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: states.contains(WidgetState.selected) ? gold : textSecondary,
          fontFamily: 'GeistSans',
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected) ? gold : textSecondary,
          size: 20,
        );
      }),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: bgInput,
      border: OutlineInputBorder(
        borderSide: BorderSide(color: border),
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: border),
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: gold, width: 1),
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      hintStyle: TextStyle(
        color: textMuted,
        fontSize: 14,
        fontFamily: 'GeistSans',
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
  );
}
