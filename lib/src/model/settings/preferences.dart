import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Must be overridden with the loaded instance (see `main.dart`).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

enum BoardTheme {
  kaya('Kaya', Color(0xFFE3B66B), Color(0xFF3A2A12)),
  bamboo('Bamboo', Color(0xFFD9C27E), Color(0xFF3C3220)),
  walnut('Walnut', Color(0xFFB5835A), Color(0xFF26180C)),
  slate('Slate', Color(0xFF6E7B85), Color(0xFF1C2329)),
  paper('Paper', Color(0xFFF2F0E6), Color(0xFF424242));

  const BoardTheme(this.label, this.wood, this.lines);

  final String label;
  final Color wood;
  final Color lines;
}

enum AppThemeMode { system, light, dark }

@immutable
class Preferences {
  const Preferences({
    this.boardTheme = BoardTheme.kaya,
    this.showCoordinates = true,
    this.confirmMoves = true,
    this.themeMode = AppThemeMode.system,
  });

  final BoardTheme boardTheme;
  final bool showCoordinates;

  /// Requires a second tap on the same point to place a stone, to avoid misclicks on phones.
  final bool confirmMoves;
  final AppThemeMode themeMode;

  Preferences copyWith({
    BoardTheme? boardTheme,
    bool? showCoordinates,
    bool? confirmMoves,
    AppThemeMode? themeMode,
  }) => Preferences(
    boardTheme: boardTheme ?? this.boardTheme,
    showCoordinates: showCoordinates ?? this.showCoordinates,
    confirmMoves: confirmMoves ?? this.confirmMoves,
    themeMode: themeMode ?? this.themeMode,
  );
}

final preferencesProvider = NotifierProvider<PreferencesController, Preferences>(
  PreferencesController.new,
);

class PreferencesController extends Notifier<Preferences> {
  static const _boardTheme = 'prefs.boardTheme';
  static const _coordinates = 'prefs.showCoordinates';
  static const _confirmMoves = 'prefs.confirmMoves';
  static const _themeMode = 'prefs.themeMode';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  Preferences build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    T byName<T extends Enum>(List<T> values, String? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    return Preferences(
      boardTheme: byName(BoardTheme.values, prefs.getString(_boardTheme), BoardTheme.kaya),
      showCoordinates: prefs.getBool(_coordinates) ?? true,
      confirmMoves: prefs.getBool(_confirmMoves) ?? true,
      themeMode: byName(AppThemeMode.values, prefs.getString(_themeMode), AppThemeMode.system),
    );
  }

  Future<void> setBoardTheme(BoardTheme theme) async {
    state = state.copyWith(boardTheme: theme);
    await _prefs.setString(_boardTheme, theme.name);
  }

  Future<void> setShowCoordinates(bool value) async {
    state = state.copyWith(showCoordinates: value);
    await _prefs.setBool(_coordinates, value);
  }

  Future<void> setConfirmMoves(bool value) async {
    state = state.copyWith(confirmMoves: value);
    await _prefs.setBool(_confirmMoves, value);
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(_themeMode, mode.name);
  }
}
