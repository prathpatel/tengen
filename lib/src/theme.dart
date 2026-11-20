import 'package:material_ui/material_ui.dart';

/// The app colors: neutral greys, as in the lichess app, so that the board is the only warm
/// thing on screen, with one blue accent. Hand tuned rather than generated from a seed, which
/// tints every surface.
ColorScheme _scheme(Brightness brightness) => brightness == Brightness.dark
    ? const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFF5AA2F0),
        onPrimary: Color(0xFF06192E),
        primaryContainer: Color(0xFF1D3757),
        onPrimaryContainer: Color(0xFFD3E6FF),
        secondary: Color(0xFF86BB4F),
        onSecondary: Color(0xFF0F1D04),
        secondaryContainer: Color(0xFF2B3B1E),
        onSecondaryContainer: Color(0xFFD6EFC0),
        tertiary: Color(0xFFE5B160),
        onTertiary: Color(0xFF2D1D02),
        tertiaryContainer: Color(0xFF4B3814),
        onTertiaryContainer: Color(0xFFFFE1AE),
        error: Color(0xFFF2766E),
        onError: Color(0xFF3A0805),
        errorContainer: Color(0xFF5C211D),
        onErrorContainer: Color(0xFFFFDAD5),
        surface: Color(0xFF161512),
        onSurface: Color(0xFFE9E7E4),
        onSurfaceVariant: Color(0xFFA9A59F),
        surfaceContainerLowest: Color(0xFF100F0D),
        surfaceContainerLow: Color(0xFF1C1B18),
        surfaceContainer: Color(0xFF242320),
        surfaceContainerHigh: Color(0xFF2D2C29),
        surfaceContainerHighest: Color(0xFF373532),
        outline: Color(0xFF55524D),
        outlineVariant: Color(0xFF34322F),
        inverseSurface: Color(0xFFE9E7E4),
        onInverseSurface: Color(0xFF1D1C1A),
        inversePrimary: Color(0xFF1C6FD1),
        shadow: Colors.black,
        scrim: Colors.black,
        surfaceTint: Colors.transparent,
      )
    : const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF1B6AC9),
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFD8E7FA),
        onPrimaryContainer: Color(0xFF0A2A52),
        secondary: Color(0xFF4A841C),
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFDDEFCF),
        onSecondaryContainer: Color(0xFF15290A),
        tertiary: Color(0xFF9E6410),
        onTertiary: Colors.white,
        tertiaryContainer: Color(0xFFFBE7C6),
        onTertiaryContainer: Color(0xFF452A03),
        error: Color(0xFFC0362C),
        onError: Colors.white,
        errorContainer: Color(0xFFFCDCD8),
        onErrorContainer: Color(0xFF410A06),
        surface: Color(0xFFF2F1EF),
        onSurface: Color(0xFF1C1B19),
        onSurfaceVariant: Color(0xFF66625C),
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: Color(0xFFF8F7F6),
        surfaceContainer: Colors.white,
        surfaceContainerHigh: Color(0xFFEAE8E5),
        surfaceContainerHighest: Color(0xFFE1DFDB),
        outline: Color(0xFFA19D97),
        outlineVariant: Color(0xFFDEDBD7),
        inverseSurface: Color(0xFF2F2E2B),
        onInverseSurface: Color(0xFFF2F1EF),
        inversePrimary: Color(0xFF5AA2F0),
        shadow: Colors.black,
        scrim: Colors.black,
        surfaceTint: Colors.transparent,
      );

ThemeData buildTheme(Brightness brightness) {
  final scheme = _scheme(brightness);
  final base = ThemeData(colorScheme: scheme, brightness: brightness);
  // With sizes: the styles below are also used as they are by components (list tiles, snack
  // bars), which do not get the geometry that Theme.of adds to the text theme.
  final sized = Typography.material2021().englishLike.merge(base.textTheme);
  final text = sized.copyWith(
    headlineMedium: sized.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
    headlineSmall: sized.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
    titleLarge: sized.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 21),
    titleMedium: sized.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    titleSmall: sized.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    labelLarge: sized.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  );
  const buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12)));
  const buttonSize = Size(64, 46);
  const buttonText = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1);
  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleSpacing: 20,
      titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface, fontSize: 22),
    ),
    // A quiet tab bar: flat, a pill behind the selected icon, small labels (as in lichess).
    navigationBarTheme: NavigationBarThemeData(
      height: 66,
      elevation: 0,
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: const StadiumBorder(),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          letterSpacing: 0.2,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? scheme.onSurface : scheme.onSurfaceVariant,
        ),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.onSurface,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorColor: scheme.primary,
      dividerColor: scheme.outlineVariant,
      labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      iconColor: scheme.onSurfaceVariant,
      titleTextStyle: text.bodyLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
      subtitleTextStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
    ),
    cardTheme: CardThemeData(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: scheme.surfaceContainer,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: buttonShape,
        minimumSize: buttonSize,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: buttonShape,
        minimumSize: buttonSize,
        textStyle: buttonText,
        side: BorderSide(color: scheme.outline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: buttonShape, textStyle: buttonText),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      highlightElevation: 4,
      shape: const StadiumBorder(),
      extendedTextStyle: buttonText.copyWith(fontSize: 16),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
      actionTextColor: scheme.inversePrimary,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Colors.transparent : scheme.outline,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      circularTrackColor: scheme.surfaceContainerHighest,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      textStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 12),
    ),
  );
}
