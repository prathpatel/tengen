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
      // Very large system font sizes would break the layout of the design; they are kept up to
      // a point.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.2,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const AppShell(),
    );
  }
}
