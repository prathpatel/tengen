import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/settings/preferences.dart';

/// The colors the app takes from the board, as the lichess app does: a tint for the surfaces and
/// an accent. Kaya and the light woods keep near neutral surfaces with a gold accent; Black
/// Walnut gives warm browns with a terracotta accent; Granite slate greys with a teal accent.
@immutable
class BoardPalette {
  const BoardPalette(this.hue, this.saturation, this.accent);

  /// Hue (degrees) and saturation (0 to 1) of the surface tint.
  final double hue;
  final double saturation;

  /// The accent on dark surfaces; a darker one is made for light surfaces.
  final Color accent;

  factory BoardPalette.of(BoardTheme board) => switch (board) {
    BoardTheme.kaya || BoardTheme.plain => const BoardPalette(40, 0.04, Color(0xFFE8B96F)),
    BoardTheme.brightKaya => const BoardPalette(40, 0.05, Color(0xFFEBC27A)),
    BoardTheme.persimmon => const BoardPalette(45, 0.06, Color(0xFFE6C47A)),
    BoardTheme.badukTV => const BoardPalette(42, 0.06, Color(0xFFE9BE5B)),
    BoardTheme.redOak => const BoardPalette(24, 0.24, Color(0xFFE9A066)),
    BoardTheme.blackWalnut => const BoardPalette(20, 0.33, Color(0xFFE3A27F)),
    BoardTheme.communityFavorite => const BoardPalette(30, 0.18, Color(0xFFE2AE73)),
    BoardTheme.granite => const BoardPalette(205, 0.15, Color(0xFF8FC9C9)),
    BoardTheme.nightPlay => const BoardPalette(220, 0.07, Color(0xFFAAB6C6)),
    BoardTheme.hng => const BoardPalette(188, 0.32, Color(0xFF4FD8E6)),
    BoardTheme.hngNight => const BoardPalette(230, 0.34, Color(0xFF6CA8EA)),
    BoardTheme.book => const BoardPalette(40, 0.02, Color(0xFFD9D4CA)),
  };

  Color _tint(double lightness, [double satFactor = 1]) =>
      HSLColor.fromAHSL(1, hue, (saturation * satFactor).clamp(0.0, 1.0), lightness).toColor();

  ColorScheme scheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final accentHsl = HSLColor.fromColor(accent);
    final primary = dark
        ? accent
        : accentHsl
              .withLightness(0.38)
              .withSaturation((accentHsl.saturation * 0.9).clamp(0.35, 0.8))
              .toColor();
    final onPrimary = dark
        ? accentHsl.withLightness(0.1).withSaturation(accentHsl.saturation * 0.6).toColor()
        : Colors.white;
    final card = dark ? _tint(0.135) : Colors.white;
    return ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: Color.alphaBlend(primary.withValues(alpha: dark ? 0.16 : 0.14), card),
      onPrimaryContainer: dark
          ? accentHsl.withLightness(0.82).toColor()
          : accentHsl.withLightness(0.24).toColor(),
      secondary: dark ? const Color(0xFF7CC47F) : const Color(0xFF3E8C42),
      onSecondary: dark ? const Color(0xFF0D1F0E) : Colors.white,
      secondaryContainer: dark ? const Color(0xFF1A281B) : const Color(0xFFDDF0DA),
      onSecondaryContainer: dark ? const Color(0xFFBFE6C0) : const Color(0xFF173A19),
      tertiary: primary,
      onTertiary: onPrimary,
      tertiaryContainer: Color.alphaBlend(primary.withValues(alpha: dark ? 0.2 : 0.16), card),
      onTertiaryContainer: dark
          ? accentHsl.withLightness(0.85).toColor()
          : accentHsl.withLightness(0.22).toColor(),
      error: dark ? const Color(0xFFF08A84) : const Color(0xFFC0362C),
      onError: dark ? const Color(0xFF3A0805) : Colors.white,
      errorContainer: dark ? const Color(0xFF341817) : const Color(0xFFFCDCD8),
      onErrorContainer: dark ? const Color(0xFFFFC9C3) : const Color(0xFF410A06),
      surface: dark ? _tint(0.055) : _tint(0.95, 0.6),
      onSurface: dark ? _tint(0.93, 0.25) : _tint(0.1, 0.4),
      onSurfaceVariant: dark ? _tint(0.6, 0.35) : _tint(0.4, 0.4),
      surfaceContainerLowest: dark ? _tint(0.035) : Colors.white,
      surfaceContainerLow: dark ? _tint(0.095) : _tint(0.985, 0.5),
      surfaceContainer: card,
      surfaceContainerHigh: dark ? _tint(0.175) : _tint(0.91, 0.5),
      surfaceContainerHighest: dark ? _tint(0.235) : _tint(0.86, 0.5),
      outline: dark ? _tint(0.33, 0.5) : _tint(0.68, 0.4),
      outlineVariant: dark ? _tint(0.2, 0.6) : _tint(0.88, 0.4),
      inverseSurface: dark ? _tint(0.93, 0.25) : _tint(0.15, 0.5),
      onInverseSurface: dark ? _tint(0.1) : _tint(0.95, 0.3),
      inversePrimary: dark
          ? accentHsl.withLightness(0.38).toColor()
          : accentHsl.withLightness(0.75).toColor(),
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
    );
  }
}

const _font = 'Inter';

ThemeData buildTheme(Brightness brightness, BoardTheme board) {
  final scheme = BoardPalette.of(board).scheme(brightness);
  final base = ThemeData(colorScheme: scheme, brightness: brightness, fontFamily: _font);
  // With sizes: the styles below are also used as they are by components (list tiles, snack
  // bars), which do not get the geometry that Theme.of adds to the text theme.
  final sized = Typography.material2021().englishLike
      .merge(base.textTheme)
      .apply(fontFamily: _font);
  final text = sized.copyWith(
    headlineLarge: sized.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
    headlineMedium: sized.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
    ),
    headlineSmall: sized.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
    titleLarge: sized.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 21),
    titleMedium: sized.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 17),
    titleSmall: sized.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    labelLarge: sized.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  );
  const radius = BorderRadius.all(Radius.circular(18));
  const buttonShape = RoundedRectangleBorder(borderRadius: radius);
  const buttonSize = Size(64, 56);
  const buttonText = TextStyle(
    fontFamily: _font,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );
  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleMedium?.copyWith(color: scheme.onSurface, fontSize: 18),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.onSurface,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorColor: scheme.primary,
      indicatorSize: TabBarIndicatorSize.label,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: scheme.primary, width: 3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
      dividerColor: scheme.outlineVariant,
      tabAlignment: TabAlignment.start,
      labelPadding: const EdgeInsets.only(right: 24),
      labelStyle: const TextStyle(fontFamily: _font, fontSize: 17, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(
        fontFamily: _font,
        fontSize: 17,
        fontWeight: FontWeight.w500,
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      iconColor: scheme.onSurfaceVariant,
      titleTextStyle: text.bodyLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
        fontSize: 17,
      ),
      subtitleTextStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
    ),
    cardTheme: CardThemeData(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: scheme.surfaceContainer,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: buttonShape,
        minimumSize: buttonSize,
        textStyle: buttonText,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: scheme.surfaceContainerHigh,
        disabledForegroundColor: scheme.onSurfaceVariant,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: buttonShape,
        minimumSize: buttonSize,
        textStyle: buttonText,
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: buttonShape,
        foregroundColor: scheme.primary,
        textStyle: buttonText.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: scheme.onSurface),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      modalBackgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: scheme.outline,
      dragHandleSize: const Size(44, 5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.surfaceContainerHighest,
      contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onSurface),
      actionTextColor: scheme.primary,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainer,
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      border: const OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? scheme.onPrimary : Colors.white,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? scheme.primary : scheme.surfaceContainerHighest,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      thumbIcon: const WidgetStatePropertyAll(null),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.surfaceContainerHighest,
      thumbColor: Colors.white,
      overlayColor: scheme.primary.withValues(alpha: 0.12),
      trackHeight: 4,
      rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 13, elevation: 2),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 13, elevation: 2),
      showValueIndicator: ShowValueIndicator.never,
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
      textStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 12, fontFamily: _font),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
    ),
  );
}
