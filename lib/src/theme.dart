import 'package:material_ui/material_ui.dart';

/// A warm, wood-like seed color for the app theme.
const _seed = Color(0xFF8A5A2B);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  return ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    appBarTheme: const AppBarTheme(centerTitle: false),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
    cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6)),
  );
}
