import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/app_shell.dart';
import 'package:tengen/src/constants.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/theme.dart';

class TengenApp extends ConsumerWidget {
  const TengenApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(preferencesProvider.select((p) => p.themeMode));
    // The app's colors follow the board, as in the lichess app.
    final board = ref.watch(preferencesProvider.select((p) => p.boardTheme));
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light, board),
      darkTheme: buildTheme(Brightness.dark, board),
      themeMode: switch (mode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      home: const AppShell(),
    );
  }
}
