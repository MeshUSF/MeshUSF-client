import 'package:flutter/material.dart';

/// MeshUSF brand colors, surfaces, and fixed indicator colors.
class MeshPalette {
  MeshPalette._();

  static const usfGreen = Color(0xFF006747);
  static const usfGold = Color(0xFFCFC493);
  static const darkPrimary = Color(0xFF86D3AB);
  static const darkOnPrimary = Color(0xFF10251A);
  static const darkAction = Color(0xFF47E98D);

  // Surfaces shared with the map overlays and navigation.
  static const bg = Color(0xFF111214);
  static const bg1 = Color(0xFF222327);
  static const bg2 = Color(0xFF2B2D31);
  static const bg3 = Color(0xFF34363C);
  static const bg4 = Color(0xFF42454B);

  static const line = Color(0xFF45484F);
  static const line2 = Color(0xFF888C96);
  static const line3 = Color(0xFF626671);

  static const ink = Color(0xFFEFF0F3);
  static const ink2 = Color(0xFFC5C8CF);
  static const ink3 = Color(0xFFADB1BA);
  static const ink4 = Color(0xFF969CA7);

  // Signal-quality green (used only for SNR coloring, not UI chrome)
  static const signal = Color(0xFF22C55E);
  static const signalDim = Color(0xFF16A34A);

  // Warn
  static const warn = Color(0xFFF59E0B);
  static const warnDim = Color(0xFFD97706);
  static const warnBg = Color(0x1FF59E0B);
  static const warnLine = Color(0x66F59E0B);

  // Alert
  static const alert = Color(0xFFEF4444);
  static const alertBg = Color(0x1FEF4444);
  static const alertLine = Color(0x66EF4444);

  // Blue for map data and identity colors.
  static const blue = Color(0xFF0EA5E9);

  // Magenta
  static const magenta = Color(0xFFDE7FDB);

  static const lightBg = Color(0xFFF7F8F3);
  static const lightBg1 = Color(0xFFEFF3EC);
  static const lightBg2 = Color(0xFFE2EAE2);
  static const lightLine = Color(0xFFCDD8CF);
  static const lightInk = Color(0xFF172820);
  static const lightInk2 = Color(0xFF43584B);

  static final darkListCard = Color.alphaBlend(
    darkAction.withValues(alpha: 0.26),
    bg,
  );
  static final darkListCardBorder = Color.alphaBlend(
    darkAction.withValues(alpha: 0.48),
    bg,
  );
  static final lightListCard = Color.alphaBlend(
    usfGreen.withValues(alpha: 0.12),
    lightBg,
  );
  static final lightListCardBorder = Color.alphaBlend(
    usfGreen.withValues(alpha: 0.30),
    lightBg,
  );
}

/// High-contrast semantic colors for UI rendered over variable map tiles.
class MapPalette {
  MapPalette._();

  static const online = Color(0xFF22C55E);
  static const offline = Color(0xFF6B7280);
  static const stale = Color(0xFFF59E0B);
  static const repeater = Color(0xFF2563EB);
  static const router = Color(0xFF7C3AED);
  static const batteryLow = Color(0xFFEF4444);
  static const cluster = Color(0xFFF97316);
  static const chat = MeshPalette.blue;
  static const selected = MeshPalette.darkPrimary;
  static const onSelected = MeshPalette.darkOnPrimary;
  static const sensor = Color(0xFF0F766E);
  static const shared = Color(0xFF0369A1);
  static const pinLightRed = Color(0xFFEF5350);
  static const pinRichRed = Color(0xFFB71C1C);

  static const panelLight = Color(0xF0F7F8F3);
  static const panelDark = Color(0xF5111214);
  static const textPrimary = MeshPalette.ink;
  static const textSecondary = MeshPalette.ink2;
  static const textMuted = MeshPalette.ink3;
  static const border = Color(0x52888C96);
  static const markerOutline = Colors.white;
  static const markerShadow = Color(0xB3000000);
}

/// High-contrast colors for line-of-sight maps and elevation profiles.
class LosPalette {
  LosPalette._();

  static const terrain = Color(0xFFA3E635);
  static const beam = Color(0xFF38BDF8);
  static const horizon = Color(0xFFFBBF24);
  static const blocked = Color(0xFFEF4444);
  static const marginal = Color(0xFFF59E0B);
  static const clear = Color(0xFF22C55E);
  static const selected = MapPalette.selected;
  static const chartBackground = MeshPalette.bg;
  static const panelDark = Color(0xF0222327);
  static const panelLight = Color(0xF5F7F8F3);
  static const text = MeshPalette.ink;
  static const textMuted = MeshPalette.ink2;
  static const border = MapPalette.border;
  static const shadow = Color(0x99000000);
}

/// Named font stacks — Flutter falls back to system fonts when the named
/// family isn't installed, keeping things working without bundled assets.
class MeshFonts {
  MeshFonts._();

  static const sans = 'Inter';
  static const mono = 'JetBrains Mono';
  static const display = 'Instrument Serif';
  static const emoji = 'Noto Color Emoji';

  static const List<String> sansFallback = [
    'system-ui',
    '-apple-system',
    'Roboto',
    'Noto Sans',
    'sans-serif',
  ];
  static const List<String> monoFallback = [
    'SF Mono',
    'Menlo',
    'Consolas',
    'Roboto Mono',
    'monospace',
  ];
  static const List<String> displayFallback = [
    'Cormorant Garamond',
    'Georgia',
    'Times New Roman',
    'serif',
  ];
  static const List<String> emojiFallback = [
    'Apple Color Emoji',
    'Segoe UI Emoji',
    'Noto Emoji',
  ];
}

/// Radii used consistently across the app.
class MeshRadii {
  MeshRadii._();
  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 24.0;
  static const pill = 999.0;
}

/// Material themes and shared text styles.
class MeshTheme {
  MeshTheme._();

  static ({
    Color background,
    Color foreground,
    Color mutedForeground,
    Color border,
  })
  sentMessageColors(ColorScheme scheme) {
    if (scheme.brightness == Brightness.dark) {
      return (
        background: MeshPalette.usfGreen,
        foreground: Colors.white,
        mutedForeground: const Color(0xFFD3F0E2),
        border: const Color(0xFF429A7B),
      );
    }
    return (
      background: const Color(0xFFB0E4C9),
      foreground: const Color(0xFF15382A),
      mutedForeground: const Color(0xFF2D5947),
      border: const Color(0xFF71AE93),
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: MeshPalette.darkPrimary,
      onPrimary: MeshPalette.darkOnPrimary,
      primaryContainer: Color(0xFF33423A),
      onPrimaryContainer: Color(0xFFE1EEE5),
      secondary: Color(0xFFBCC2CA),
      onSecondary: Color(0xFF282D33),
      secondaryContainer: MeshPalette.bg3,
      onSecondaryContainer: MeshPalette.ink,
      tertiary: Color(0xFFADC1CF),
      onTertiary: Color(0xFF24333E),
      tertiaryContainer: Color(0xFF334550),
      onTertiaryContainer: Color(0xFFD8E7F0),
      error: Color(0xFFFFB4AA),
      onError: Color(0xFF52170F),
      errorContainer: Color(0xFF7F1D1D),
      onErrorContainer: Colors.white,
      surface: MeshPalette.bg,
      onSurface: MeshPalette.ink,
      surfaceContainerLowest: MeshPalette.bg,
      surfaceContainerLow: MeshPalette.bg1,
      surfaceContainer: MeshPalette.bg1,
      surfaceContainerHigh: MeshPalette.bg2,
      surfaceContainerHighest: MeshPalette.bg3,
      onSurfaceVariant: MeshPalette.ink2,
      outline: MeshPalette.line2,
      outlineVariant: MeshPalette.line,
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: MeshPalette.ink,
      onInverseSurface: MeshPalette.bg,
      inversePrimary: MeshPalette.usfGreen,
    );
    return _build(scheme, Brightness.dark);
  }

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: MeshPalette.usfGreen,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFD2EADC),
      onPrimaryContainer: Color(0xFF163B2A),
      secondary: Color(0xFF46634F),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFDDE9DF),
      onSecondaryContainer: Color(0xFF263E2F),
      tertiary: Color(0xFF37635A),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFD5EBE6),
      onTertiaryContainer: Color(0xFF203D37),
      error: Color(0xFFB53D2F),
      onError: Colors.white,
      errorContainer: Color(0xFFF6D9D4),
      onErrorContainer: Color(0xFF5C1A12),
      surface: MeshPalette.lightBg,
      onSurface: MeshPalette.lightInk,
      surfaceContainerLowest: MeshPalette.lightBg,
      surfaceContainerLow: MeshPalette.lightBg1,
      surfaceContainer: MeshPalette.lightBg1,
      surfaceContainerHigh: MeshPalette.lightBg2,
      surfaceContainerHighest: Color(0xFFD8E2D9),
      onSurfaceVariant: MeshPalette.lightInk2,
      outline: Color(0xFF687C6E),
      outlineVariant: MeshPalette.lightLine,
      inverseSurface: MeshPalette.bg3,
      onInverseSurface: MeshPalette.ink,
      inversePrimary: MeshPalette.darkPrimary,
    );
    return _build(scheme, Brightness.light);
  }

  static ThemeData _build(ColorScheme scheme, Brightness brightness) {
    final actionColor = brightness == Brightness.dark
        ? MeshPalette.darkAction
        : scheme.primary;
    final baseText =
        Typography.material2021(
          platform: TargetPlatform.android,
          colorScheme: scheme,
        ).black.apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
          fontFamily: MeshFonts.sans,
          fontFamilyFallback: MeshFonts.sansFallback,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      fontFamily: MeshFonts.sans,
      fontFamilyFallback: MeshFonts.sansFallback,
      textTheme: baseText,
      dividerColor: scheme.outlineVariant,
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: MeshFonts.sans,
          fontFamilyFallback: MeshFonts.sansFallback,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
        shape: Border(
          bottom: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MeshRadii.md),
          side: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MeshRadii.md),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: actionColor,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MeshRadii.pill),
        ),
        extendedTextStyle: const TextStyle(
          fontFamily: MeshFonts.sans,
          fontFamilyFallback: MeshFonts.sansFallback,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: actionColor,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MeshRadii.pill),
          ),
          textStyle: const TextStyle(
            fontFamily: MeshFonts.sans,
            fontFamilyFallback: MeshFonts.sansFallback,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MeshRadii.pill),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MeshRadii.pill),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MeshRadii.md),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MeshRadii.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MeshRadii.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: TextStyle(
          fontFamily: MeshFonts.sans,
          fontFamilyFallback: MeshFonts.sansFallback,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MeshRadii.pill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MeshRadii.md),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: MeshFonts.sans,
            fontFamilyFallback: MeshFonts.sansFallback,
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.1,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            size: 22,
          );
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: scheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(MeshRadii.lg),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MeshRadii.lg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        contentTextStyle: TextStyle(color: scheme.onSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MeshRadii.md),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MeshRadii.md),
        ),
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.primary.withValues(alpha: 0.16),
          selectedForegroundColor: scheme.primary,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: const TextStyle(
            fontFamily: MeshFonts.sans,
            fontFamilyFallback: MeshFonts.sansFallback,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : scheme.outline,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        valueIndicatorColor: scheme.surfaceContainerHighest,
        valueIndicatorTextStyle: TextStyle(
          fontFamily: MeshFonts.mono,
          fontFamilyFallback: MeshFonts.monoFallback,
          color: scheme.onSurface,
          fontSize: 12,
        ),
        trackHeight: 3,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        dividerColor: scheme.outlineVariant,
        labelStyle: const TextStyle(
          fontFamily: MeshFonts.sans,
          fontFamilyFallback: MeshFonts.sansFallback,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: MeshFonts.sans,
          fontFamilyFallback: MeshFonts.sansFallback,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
        circularTrackColor: Colors.transparent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(MeshRadii.sm),
          border: Border.all(color: scheme.outline),
        ),
        textStyle: TextStyle(color: scheme.onSurface, fontSize: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: actionColor,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MeshRadii.pill),
          ),
          textStyle: const TextStyle(
            fontFamily: MeshFonts.sans,
            fontFamilyFallback: MeshFonts.sansFallback,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  /// Mono text style — sizes default to the body size Inter is using.
  static TextStyle mono({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: MeshFonts.mono,
      fontFamilyFallback: MeshFonts.monoFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing ?? 0.2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Serif display style.
  static TextStyle display({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: MeshFonts.display,
      fontFamilyFallback: MeshFonts.displayFallback,
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color,
      letterSpacing: letterSpacing ?? -0.2,
    );
  }

  /// Section-accent / chip label — sans for legibility, with light tracking
  /// to keep the "label" feel that section headers rely on.
  static TextStyle accentLabel({Color? color, double? fontSize}) {
    return TextStyle(
      fontFamily: MeshFonts.sans,
      fontFamilyFallback: MeshFonts.sansFallback,
      fontSize: fontSize ?? 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: color,
    );
  }

  /// Color-emoji style with platform fallbacks and stable vertical metrics.
  static TextStyle emoji({double fontSize = 28}) {
    return TextStyle(
      fontFamily: MeshFonts.emoji,
      fontFamilyFallback: MeshFonts.emojiFallback,
      fontSize: fontSize,
      height: 1,
    );
  }

  /// Color-code an SNR value for consistency across the app.
  static Color snrColor(num? snr, {required bool blocked}) {
    if (blocked) return MeshPalette.alert;
    if (snr == null) return MeshPalette.ink3;
    if (snr > -5) return MeshPalette.signal;
    if (snr > -12) return MeshPalette.warn;
    return MeshPalette.alert;
  }
}
