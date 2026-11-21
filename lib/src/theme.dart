import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/settings/preferences.dart';

/// The Tengen colors: near black (or white) surfaces, flat cards, and one gold accent, as in the
/// chosen design. The board keeps its own wood; the app around it stays neutral.
@immutable
class TengenColors {
  const TengenColors({
    required this.background,
    required this.card,
    required this.bar,
    required this.line,
    required this.selected,
    required this.text,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.win,
    required this.loss,
  });

  static const dark = TengenColors(
    background: Color(0xFF111214),
    card: Color(0xFF1B1C1F),
    bar: Color(0xFF151619),
    line: Color(0xFF2A2B2F),
    selected: Color(0xFF2C2D31),
    text: Color(0xFFF3F4F6),
    muted: Color(0xFF9A9CA3),
    accent: Color(0xFFE9B764),
    onAccent: Color(0xFF231804),
    win: Color(0xFF8FD49A),
    loss: Color(0xFFF2998E),
  );

  static const light = TengenColors(
    background: Color(0xFFF2F2F5),
    card: Color(0xFFFFFFFF),
    bar: Color(0xFFFFFFFF),
    line: Color(0xFFE4E4E8),
    selected: Color(0xFFE4E4E9),
    text: Color(0xFF111214),
    muted: Color(0xFF6B6E76),
    accent: Color(0xFF9A6412),
    onAccent: Color(0xFFFFFFFF),
    win: Color(0xFF2F7A34),
    loss: Color(0xFFB4382B),
  );

  /// The page.
  final Color background;

  /// Cards, grouped lists, unselected options.
  final Color card;

  /// The bottom bar.
  final Color bar;

  /// Separators inside grouped lists.
  final Color line;

  /// The selected segment of a segmented control.
  final Color selected;
  final Color text;
  final Color muted;
  final Color accent;
  final Color onAccent;
  final Color win;
  final Color loss;

  ColorScheme scheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    Color mix(Color c, double a) => Color.alphaBlend(c.withValues(alpha: a), card);
    return ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: onAccent,
      primaryContainer: mix(accent, dark ? 0.16 : 0.12),
      onPrimaryContainer: dark ? const Color(0xFFF6DDB0) : const Color(0xFF4A2F06),
      secondary: win,
      onSecondary: dark ? const Color(0xFF0D1F0E) : Colors.white,
      secondaryContainer: mix(win, dark ? 0.16 : 0.14),
      onSecondaryContainer: dark ? const Color(0xFFBFE6C0) : const Color(0xFF173A19),
      tertiary: accent,
      onTertiary: onAccent,
      tertiaryContainer: mix(accent, dark ? 0.2 : 0.16),
      onTertiaryContainer: dark ? const Color(0xFFF6DDB0) : const Color(0xFF4A2F06),
      error: loss,
      onError: dark ? const Color(0xFF3A0805) : Colors.white,
      errorContainer: mix(loss, dark ? 0.16 : 0.14),
      onErrorContainer: dark ? const Color(0xFFFFC9C3) : const Color(0xFF410A06),
      surface: background,
      onSurface: text,
      onSurfaceVariant: muted,
      surfaceContainerLowest: background,
      surfaceContainerLow: bar,
      surfaceContainer: card,
      surfaceContainerHigh: selected,
      surfaceContainerHighest: dark ? const Color(0xFF35363B) : const Color(0xFFDADADF),
      outline: dark ? const Color(0xFF45464C) : const Color(0xFFC4C5CB),
      outlineVariant: line,
      inverseSurface: text,
      onInverseSurface: background,
      inversePrimary: dark ? const Color(0xFF9A6412) : const Color(0xFFE9B764),
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
    );
  }
}

/// The sizes of the design, in logical pixels, used by the theme and the custom widgets alike:
/// the app must look like the mockup, not like Material's larger defaults.
abstract final class TengenSizes {
  static const pageTitle = 26.0;
  static const rowTitle = 16.0;
  static const rowSubtitle = 13.5;
  static const sectionLabel = 13.0;
  static const navLabel = 11.5;
  static const button = 17.0;
  static const buttonHeight = 52.0;
  static const cardRadius = 14.0;
  static const tileRadius = 10.0;
  static const gutter = 16.0;
}

const _font = 'Inter';

/// The theme. [board] is kept for callers; the colors no longer follow the board.
ThemeData buildTheme(Brightness brightness, BoardTheme board) {
  final colors = brightness == Brightness.dark ? TengenColors.dark : TengenColors.light;
  final scheme = colors.scheme(brightness);
  final base = ThemeData(colorScheme: scheme, brightness: brightness, fontFamily: _font);
  // With sizes: the styles below are also used as they are by components (list tiles, snack
  // bars), which do not get the geometry that Theme.of adds to the text theme.
  final sized = Typography.material2021().englishLike
      .merge(base.textTheme)
      .apply(fontFamily: _font, bodyColor: colors.text, displayColor: colors.text);
  TextStyle? s(TextStyle? t, double size, FontWeight weight, {double spacing = 0, double? h}) =>
      t?.copyWith(fontSize: size, fontWeight: weight, letterSpacing: spacing, height: h);
  final text = sized.copyWith(
    displayLarge: s(sized.displayLarge, 44, FontWeight.w700, spacing: -1),
    displayMedium: s(sized.displayMedium, 36, FontWeight.w700, spacing: -0.8),
    displaySmall: s(sized.displaySmall, 30, FontWeight.w700, spacing: -0.6),
    headlineLarge: s(sized.headlineLarge, 28, FontWeight.w700, spacing: -0.4),
    headlineMedium: s(sized.headlineMedium, TengenSizes.pageTitle, FontWeight.w700, spacing: -0.3),
    headlineSmall: s(sized.headlineSmall, 21, FontWeight.w700, spacing: -0.2),
    titleLarge: s(sized.titleLarge, 19, FontWeight.w600),
    titleMedium: s(sized.titleMedium, TengenSizes.rowTitle, FontWeight.w500, h: 1.3),
    titleSmall: s(sized.titleSmall, 14.5, FontWeight.w600, h: 1.25),
    bodyLarge: s(sized.bodyLarge, 16, FontWeight.w400, h: 1.35),
    bodyMedium: s(sized.bodyMedium, TengenSizes.rowSubtitle, FontWeight.w400, h: 1.35),
    bodySmall: s(sized.bodySmall, 12.5, FontWeight.w400, h: 1.3),
    labelLarge: s(sized.labelLarge, 15, FontWeight.w600),
    labelMedium: s(sized.labelMedium, TengenSizes.sectionLabel, FontWeight.w600, spacing: 0.5),
    labelSmall: s(sized.labelSmall, TengenSizes.navLabel, FontWeight.w500),
  );
  const radius = BorderRadius.all(Radius.circular(12));
  const buttonShape = RoundedRectangleBorder(borderRadius: radius);
  const buttonSize = Size(64, TengenSizes.buttonHeight);
  const buttonText = TextStyle(
    fontFamily: _font,
    fontSize: TengenSizes.button,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: colors.background,
    canvasColor: colors.background,
    splashFactory: InkRipple.splashFactory,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: const FadeForwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: colors.background,
      foregroundColor: colors.text,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge?.copyWith(color: colors.text, fontSize: 17),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: colors.text,
      unselectedLabelColor: colors.muted,
      indicatorColor: colors.accent,
      indicatorSize: TabBarIndicatorSize.label,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: colors.accent, width: 3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
      dividerColor: colors.line,
      tabAlignment: TabAlignment.start,
      labelPadding: const EdgeInsets.only(right: 22),
      labelStyle: const TextStyle(fontFamily: _font, fontSize: 15, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(
        fontFamily: _font,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      iconColor: colors.muted,
      minVerticalPadding: 10,
      titleTextStyle: text.titleMedium?.copyWith(color: colors.text),
      subtitleTextStyle: text.bodyMedium?.copyWith(color: colors.muted),
    ),
    cardTheme: CardThemeData(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: colors.card,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(TengenSizes.cardRadius)),
      ),
    ),
    dividerTheme: DividerThemeData(color: colors.line, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: buttonShape,
        minimumSize: buttonSize,
        textStyle: buttonText,
        backgroundColor: colors.accent,
        foregroundColor: colors.onAccent,
        disabledBackgroundColor: colors.selected,
        disabledForegroundColor: colors.muted,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: buttonShape,
        minimumSize: buttonSize,
        textStyle: buttonText.copyWith(fontSize: 15),
        foregroundColor: colors.text,
        side: BorderSide(color: colors.line),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.accent,
        textStyle: buttonText.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: colors.text)),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.background,
      modalBackgroundColor: colors.background,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: colors.line,
      dragHandleSize: const Size(36, 4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colors.selected,
      contentTextStyle: text.bodyMedium?.copyWith(color: colors.text),
      actionTextColor: colors.accent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.card,
      hintStyle: TextStyle(color: colors.muted),
      border: const OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: colors.accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? colors.onAccent : Colors.white,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? colors.accent : colors.selected,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      thumbIcon: const WidgetStatePropertyAll(null),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? colors.accent : colors.line,
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: colors.accent,
      inactiveTrackColor: colors.selected,
      thumbColor: Colors.white,
      overlayColor: colors.accent.withValues(alpha: 0.12),
      trackHeight: 4,
      rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 11, elevation: 2),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11, elevation: 2),
      showValueIndicator: ShowValueIndicator.never,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.accent,
      linearTrackColor: colors.selected,
      circularTrackColor: colors.selected,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: colors.text,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      textStyle: TextStyle(color: colors.background, fontSize: 12, fontFamily: _font),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
  );
}
