/// ClawCommander Material 3 themes.
///
/// Architecture: `PocketClawTheme` exposes a stable set of static color
/// getters (bronze, surface, lobsterRed, etc.) that all 86 widgets in
/// the app reference directly. Each getter resolves to the matching
/// field on a mutable `_active` palette. Swapping themes is a single
/// synchronous assignment at the top of `PocketClawApp.build()` — the
/// MaterialApp rebuild that follows picks up both the new `ThemeData`
/// and the new color values used by hand-painted widgets.
///
/// To add a new theme: implement `_Palette` and add it to the
/// `themeFor(ThemeId)` switch.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_flavor.dart';
import 'hermes_commander_theme.dart';

/// User-facing theme choices. Persist this enum's `.name` to
/// SharedPreferences so adding a new theme later doesn't shift indices.
enum ThemeId {
  dark('Dark — Bronze & Amber'),
  light('Light — Cream & Bronze'),
  oceanic('Oceanic — Cyan & Mint'),
  sunset('Sunset — Magenta & Gold');

  const ThemeId(this.displayName);
  final String displayName;
}

/// Concrete palette + ThemeData container for one theme.
abstract class _Palette {
  Brightness get brightness;

  // Backgrounds & surfaces
  Color get deepCharcoal; // scaffold background
  Color get surface;
  Color get surfaceContainerLow;
  Color get surfaceContainer;
  Color get surfaceContainerHigh;
  Color get surfaceBright;
  Color get surfaceDim;

  // Accents
  Color get bronze;
  Color get amber;
  Color get electricTeal; // backward-compat alias used widely

  // Text
  Color get onSurface;
  Color get onSurfaceMuted;

  // Status semantics — kept distinguishable across themes
  Color get lobsterRed;
  Color get success;
  Color get warning;

  // Borders
  Color get outline;
  Color get outlineVariant;

  ThemeData build();
}

class PocketClawTheme {
  PocketClawTheme._();

  static _Palette _active = _DarkPalette();

  /// Swap the active palette. Call at the top of `build()` *before*
  /// returning the MaterialApp so the new ThemeData and the new static
  /// color getters paint the same frame.
  static void setActive(ThemeId id) {
    if (kHermesOnlyMode) return;
    _active = _paletteFor(id);
  }

  static ThemeId get activeId {
    if (_active is _DarkPalette) return ThemeId.dark;
    if (_active is _LightPalette) return ThemeId.light;
    if (_active is _OceanicPalette) return ThemeId.oceanic;
    return ThemeId.sunset;
  }

  static _Palette _paletteFor(ThemeId id) {
    switch (id) {
      case ThemeId.dark:
        return _DarkPalette();
      case ThemeId.light:
        return _LightPalette();
      case ThemeId.oceanic:
        return _OceanicPalette();
      case ThemeId.sunset:
        return _SunsetPalette();
    }
  }

  static ThemeData themeFor(ThemeId id) =>
      kHermesOnlyMode ? HCTheme.theme : _paletteFor(id).build();
  static ThemeData get themeData =>
      kHermesOnlyMode ? HCTheme.theme : _active.build();

  /// Kept for backward compatibility — `MaterialApp.router(theme:
  /// PocketClawTheme.darkTheme)` still resolves. New code should use
  /// `themeData` (active) or `themeFor(id)`.
  static ThemeData get darkTheme =>
      kHermesOnlyMode ? HCTheme.theme : _DarkPalette().build();

  // ── delegating colour getters — all 86 referencing widgets read these
  static Color get deepCharcoal =>
      kHermesOnlyMode ? HCTheme.bgBase : _active.deepCharcoal;
  static Color get surface =>
      kHermesOnlyMode ? HCTheme.bgSurface : _active.surface;
  static Color get surfaceContainerLow =>
      kHermesOnlyMode ? HCTheme.bgBase : _active.surfaceContainerLow;
  static Color get surfaceContainer =>
      kHermesOnlyMode ? HCTheme.bgPanel : _active.surfaceContainer;
  static Color get surfaceContainerHigh =>
      kHermesOnlyMode ? HCTheme.bgSurface : _active.surfaceContainerHigh;
  static Color get surfaceBright =>
      kHermesOnlyMode ? HCTheme.bgActive : _active.surfaceBright;
  static Color get surfaceDim =>
      kHermesOnlyMode ? HCTheme.bgBase : _active.surfaceDim;

  static Color get bronze => kHermesOnlyMode ? HCTheme.gold : _active.bronze;
  static Color get amber => kHermesOnlyMode ? HCTheme.goldLight : _active.amber;
  static Color get electricTeal =>
      kHermesOnlyMode ? HCTheme.gold : _active.electricTeal;

  static Color get onSurface =>
      kHermesOnlyMode ? HCTheme.textPrimary : _active.onSurface;
  static Color get onSurfaceMuted =>
      kHermesOnlyMode ? HCTheme.textSecondary : _active.onSurfaceMuted;

  static Color get lobsterRed =>
      kHermesOnlyMode ? HCTheme.statusRed : _active.lobsterRed;
  static Color get success =>
      kHermesOnlyMode ? HCTheme.statusGreen : _active.success;
  static Color get warning =>
      kHermesOnlyMode ? HCTheme.statusAmber : _active.warning;
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared text scale — identical across all themes (JetBrainsMono).
// ═══════════════════════════════════════════════════════════════════════════

TextTheme _baseTextTheme() => TextTheme(
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

ThemeData _buildThemeData(_Palette p) {
  final textTheme = _baseTextTheme().apply(
    bodyColor: p.onSurface,
    displayColor: p.onSurface,
  );

  final colorScheme = ColorScheme(
    brightness: p.brightness,
    primary: p.bronze,
    onPrimary: p.brightness == Brightness.dark ? Colors.white : Colors.white,
    primaryContainer: p.bronze.withAlpha(50),
    onPrimaryContainer: p.bronze.withAlpha(230),
    secondary: p.amber,
    onSecondary: p.brightness == Brightness.dark ? Colors.black : Colors.white,
    secondaryContainer: p.amber.withAlpha(50),
    onSecondaryContainer: p.amber.withAlpha(230),
    tertiary: p.warning,
    onTertiary: Colors.black,
    error: p.lobsterRed,
    onError: Colors.white,
    surface: p.surface,
    onSurface: p.onSurface,
    onSurfaceVariant: p.onSurfaceMuted,
    outline: p.outline,
    outlineVariant: p.outlineVariant,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: p.onSurface,
    onInverseSurface: p.deepCharcoal,
    inversePrimary: p.bronze,
    surfaceContainerHighest: p.surfaceContainerHigh,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: p.brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: p.deepCharcoal,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: p.deepCharcoal,
      foregroundColor: p.onSurface,
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
      titleTextStyle: GoogleFonts.jetBrainsMono(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: p.onSurface,
        letterSpacing: 0.4,
      ),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p.outline.withAlpha(80)),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: p.deepCharcoal,
      selectedItemColor: p.bronze,
      unselectedItemColor: p.onSurfaceMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: GoogleFonts.jetBrainsMono(
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: GoogleFonts.jetBrainsMono(fontSize: 10),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.deepCharcoal,
      indicatorColor: p.bronze.withAlpha(40),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: p.bronze);
        }
        return IconThemeData(color: p.onSurfaceMuted);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: p.bronze,
          );
        }
        return GoogleFonts.jetBrainsMono(fontSize: 10, color: p.onSurfaceMuted);
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.outline.withAlpha(120)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.bronze, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.lobsterRed),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: p.onSurface.withAlpha(100)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.bronze,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.bronze,
        side: BorderSide(color: p.bronze),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.amber,
        textStyle: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.bronze,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surfaceContainerLow,
      selectedColor: p.bronze.withAlpha(40),
      side: BorderSide(color: p.outline.withAlpha(80)),
      labelStyle: GoogleFonts.jetBrainsMono(fontSize: 11),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dividerTheme: DividerThemeData(
      color: p.outline.withAlpha(80),
      thickness: 1,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.bronze,
      unselectedLabelColor: p.onSurfaceMuted,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: p.bronze, width: 2),
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
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return p.bronze;
        return p.onSurfaceMuted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return p.bronze.withAlpha(80);
        }
        return p.surfaceContainerLow;
      }),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.bronze,
      linearTrackColor: p.surfaceContainerLow,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.surfaceContainerHigh,
      contentTextStyle: TextStyle(color: p.onSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Theme 1 — Dark (Bronze + Amber on warm near-black). Original v1.0 palette.
// ═══════════════════════════════════════════════════════════════════════════
class _DarkPalette implements _Palette {
  @override
  Brightness get brightness => Brightness.dark;
  @override
  Color get deepCharcoal => const Color(0xFF0A0805);
  @override
  Color get surface => const Color(0xFF181410);
  @override
  Color get surfaceContainerLow => const Color(0xFF241D17);
  @override
  Color get surfaceContainer => const Color(0xFF181410);
  @override
  Color get surfaceContainerHigh => const Color(0xFF2A221B);
  @override
  Color get surfaceBright => const Color(0xFF2E251D);
  @override
  Color get surfaceDim => const Color(0xFF0A0805);
  @override
  Color get bronze => const Color(0xFFC76A2E);
  @override
  Color get amber => const Color(0xFFFF8B47);
  @override
  Color get electricTeal => amber;
  @override
  Color get onSurface => const Color(0xFFEDE6DD);
  @override
  Color get onSurfaceMuted => const Color(0xFF7A6E62);
  @override
  Color get lobsterRed => const Color(0xFFD33B1A);
  @override
  Color get success => const Color(0xFF6FAE5C);
  @override
  Color get warning => const Color(0xFFE0A02E);
  @override
  Color get outline => const Color(0xFF3A2F26);
  @override
  Color get outlineVariant => const Color(0xFF2A2018);
  @override
  ThemeData build() => _buildThemeData(this);
}

// ═══════════════════════════════════════════════════════════════════════════
// Theme 2 — Light/Cream. Warm ivory background, deep-bronze primaries.
// Keeps the JetBrainsMono identity but flips into daylight territory for
// outdoor / bright-room usability. Status reds and greens go slightly
// darker to stay visible against the lighter surfaces.
// ═══════════════════════════════════════════════════════════════════════════
class _LightPalette implements _Palette {
  @override
  Brightness get brightness => Brightness.light;
  @override
  Color get deepCharcoal => const Color(0xFFFAF5EE); // app scaffold (ivory)
  @override
  Color get surface => const Color(0xFFFFFFFF);
  @override
  Color get surfaceContainerLow => const Color(0xFFF0E8DC);
  @override
  Color get surfaceContainer => const Color(0xFFF7F0E5);
  @override
  Color get surfaceContainerHigh => const Color(0xFFEAE0CF);
  @override
  Color get surfaceBright => const Color(0xFFFFFAF1);
  @override
  Color get surfaceDim => const Color(0xFFE8DECD);
  @override
  Color get bronze => const Color(0xFFB85A1E);
  @override
  Color get amber => const Color(0xFFE07B2F);
  @override
  Color get electricTeal => amber;
  @override
  Color get onSurface => const Color(0xFF2A1F15);
  @override
  Color get onSurfaceMuted => const Color(0xFF6F5F50);
  @override
  Color get lobsterRed => const Color(0xFFC2381F);
  @override
  Color get success => const Color(0xFF4F8F3E);
  @override
  Color get warning => const Color(0xFFC68A1E);
  @override
  Color get outline => const Color(0xFFD2C3AC);
  @override
  Color get outlineVariant => const Color(0xFFE6DCC9);
  @override
  ThemeData build() => _buildThemeData(this);
}

// ═══════════════════════════════════════════════════════════════════════════
// Theme 3 — Oceanic. Deep midnight-navy with electric cyan and mint
// accents. Inspired by Tron / synthwave UIs; status colours stay vivid
// to read against the saturated surfaces.
// ═══════════════════════════════════════════════════════════════════════════
class _OceanicPalette implements _Palette {
  @override
  Brightness get brightness => Brightness.dark;
  @override
  Color get deepCharcoal => const Color(0xFF0A1929);
  @override
  Color get surface => const Color(0xFF102844);
  @override
  Color get surfaceContainerLow => const Color(0xFF15355C);
  @override
  Color get surfaceContainer => const Color(0xFF12304F);
  @override
  Color get surfaceContainerHigh => const Color(0xFF1B406B);
  @override
  Color get surfaceBright => const Color(0xFF1F4773);
  @override
  Color get surfaceDim => const Color(0xFF0A1929);
  @override
  Color get bronze => const Color(0xFF00B8D4); // electric cyan as "primary"
  @override
  Color get amber => const Color(0xFF56F7D9); // mint accent
  @override
  Color get electricTeal => amber;
  @override
  Color get onSurface => const Color(0xFFDCEEF6);
  @override
  Color get onSurfaceMuted => const Color(0xFF6B8AA0);
  @override
  Color get lobsterRed => const Color(0xFFFF5471);
  @override
  Color get success => const Color(0xFF56F7D9);
  @override
  Color get warning => const Color(0xFFFFB547);
  @override
  Color get outline => const Color(0xFF1E4670);
  @override
  Color get outlineVariant => const Color(0xFF143153);
  @override
  ThemeData build() => _buildThemeData(this);
}

// ═══════════════════════════════════════════════════════════════════════════
// Theme 4 — Sunset (vaporwave). Deep violet base with hot magenta and
// golden coral accents. The most visually loud of the four; best for
// late-night creative sessions.
// ═══════════════════════════════════════════════════════════════════════════
class _SunsetPalette implements _Palette {
  @override
  Brightness get brightness => Brightness.dark;
  @override
  Color get deepCharcoal => const Color(0xFF1A0628);
  @override
  Color get surface => const Color(0xFF2B0F3D);
  @override
  Color get surfaceContainerLow => const Color(0xFF3D1A55);
  @override
  Color get surfaceContainer => const Color(0xFF341448);
  @override
  Color get surfaceContainerHigh => const Color(0xFF4A2266);
  @override
  Color get surfaceBright => const Color(0xFF552973);
  @override
  Color get surfaceDim => const Color(0xFF1A0628);
  @override
  Color get bronze => const Color(0xFFFF3DA0); // hot magenta primary
  @override
  Color get amber => const Color(0xFFFFB347); // golden coral secondary
  @override
  Color get electricTeal => amber;
  @override
  Color get onSurface => const Color(0xFFF3E5F5);
  @override
  Color get onSurfaceMuted => const Color(0xFF8E6CA8);
  @override
  Color get lobsterRed => const Color(0xFFFF477E);
  @override
  Color get success => const Color(0xFF80E0A7);
  @override
  Color get warning => const Color(0xFFFFD23F);
  @override
  Color get outline => const Color(0xFF552973);
  @override
  Color get outlineVariant => const Color(0xFF3D1A55);
  @override
  ThemeData build() => _buildThemeData(this);
}
