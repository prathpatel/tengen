import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Must be overridden with the loaded instance (see `main.dart`).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

/// The board themes of online-go.com (goban `board_woods.ts` and `board_plain.ts`), with their
/// colors and, for the wood and stone ones, the OGS texture in `assets/goban/boards/`.
enum BoardTheme {
  kaya('Kaya', Color(0xFFDCB35C), Color(0xFF442211), Color(0xFF000000), Color(0xFF444444), 'kaya'),
  brightKaya(
    'Bright Kaya',
    Color(0xFFDBB25B),
    Color(0xFFFFFFFF),
    Color(0xFFFFFFFF),
    Color(0xFFFFFFFF),
    'kaya',
  ),
  redOak(
    'Red Oak',
    Color(0xFFDCB35C),
    Color(0xFF331800),
    Color(0xFF000000),
    Color(0xFF000000),
    'oak',
  ),
  persimmon(
    'Persimmon',
    Color(0xFFDCB35C),
    Color(0xFF331F00),
    Color(0xFF000000),
    Color(0xFF000000),
    'persimmon',
  ),
  blackWalnut(
    'Black Walnut',
    Color(0xFFDCB35C),
    Color(0xFF330000),
    Color(0xFF000000),
    Color(0xFF000000),
    'black_walnut',
  ),
  granite(
    'Granite',
    Color(0xFF8A8A8A),
    Color(0xFFCCCCCC),
    Color(0xFFCCCCCC),
    Color(0xFFCCCCCC),
    'granite',
  ),
  badukTV(
    'BadukTV',
    Color(0xFFDCB35C),
    Color(0xFF442211),
    Color(0xFF000000),
    Color(0xFF444444),
    'baduktv',
  ),
  communityFavorite(
    'Community Favorite',
    Color(0xFFDCB35C),
    Color(0xFF442211),
    Color(0xFF000000),
    Color(0xFF444444),
    'community_favorite',
  ),
  plain('Plain', Color(0xFFDCB35C), Color(0xFF000000), Color(0xFF000000), Color(0xFF404040)),
  nightPlay(
    'Night Play',
    Color(0xFF444444),
    Color(0xFF777777),
    Color(0xFF555555),
    Color(0xFF8A8A8A),
  ),
  hng('HNG', Color(0xFF00E7FC), Color(0xFF00193E), Color(0xFF00193E), Color(0xFF004C75)),
  hngNight('HNG Night', Color(0xFF090C1F), Color(0xFF007591), Color(0xFF007591), Color(0xFF4481B5)),
  book('Book', Color(0xFFFFFFFF), Color(0xFF777777), Color(0xFF555555), Color(0xFF555555));

  const BoardTheme(this.label, this.wood, this.lines, this.stars, this.labels, [this.texture]);

  final String label;

  /// The background color, under the texture when there is one.
  final Color wood;
  final Color lines;
  final Color stars;

  /// The color of the coordinates.
  final Color labels;

  /// The name of the OGS texture, if any.
  final String? texture;

  String? get textureAsset => texture == null ? null : 'assets/goban/boards/$texture.jpg';

  /// Themes of earlier versions of the app.
  static BoardTheme? fromOldName(String? name) => switch (name) {
    'bamboo' => kaya,
    'walnut' => blackWalnut,
    'slate' => nightPlay,
    'paper' => book,
    _ => null,
  };
}

/// The stone themes of online-go.com (goban `plain_stones.ts`, `rendered_stones.ts` and
/// `image_stones.ts`). As on OGS, black and white stones are chosen separately; some themes exist
/// only for one color.
enum StoneTheme {
  plain('Plain', black: true, white: true),
  slate('Slate', black: true, white: false),
  shell('Shell', black: false, white: true),
  glass('Glass', black: true, white: true),
  wornGlass('Worn Glass', black: true, white: true),
  night('Night', black: true, white: true),
  anime('Anime', black: true, white: true, image: 'anime'),
  badukTV('BadukTV', black: true, white: true, image: 'baduktv');

  const StoneTheme(this.label, {required this.black, required this.white, this.image});

  final String label;

  /// Whether the theme has black stones.
  final bool black;

  /// Whether the theme has white stones.
  final bool white;

  /// The name of the OGS stone images, for image themes.
  final String? image;

  String? imageAsset(bool forBlack) =>
      image == null ? null : 'assets/goban/stones/${image}_${forBlack ? 'black' : 'white'}.png';

  static List<StoneTheme> get forBlack => values.where((t) => t.black).toList();
  static List<StoneTheme> get forWhite => values.where((t) => t.white).toList();
}

enum AppThemeMode { system, light, dark }

@immutable
class Preferences {
  const Preferences({
    this.boardTheme = BoardTheme.kaya,
    this.blackStones = StoneTheme.slate,
    this.whiteStones = StoneTheme.shell,
    this.showCoordinates = true,
    this.confirmMoves = true,
    this.stoneSound = true,
    this.themeMode = AppThemeMode.system,
  });

  final BoardTheme boardTheme;

  /// The stones, as on OGS: Slate and Shell by default.
  final StoneTheme blackStones;
  final StoneTheme whiteStones;
  final bool showCoordinates;

  /// Requires a second tap on the same point to place a stone, to avoid misclicks on phones.
  final bool confirmMoves;

  /// The click of a stone on the board, with each move (the OGS stone sounds).
  final bool stoneSound;
  final AppThemeMode themeMode;

  Preferences copyWith({
    BoardTheme? boardTheme,
    StoneTheme? blackStones,
    StoneTheme? whiteStones,
    bool? showCoordinates,
    bool? confirmMoves,
    bool? stoneSound,
    AppThemeMode? themeMode,
  }) => Preferences(
    boardTheme: boardTheme ?? this.boardTheme,
    blackStones: blackStones ?? this.blackStones,
    whiteStones: whiteStones ?? this.whiteStones,
    showCoordinates: showCoordinates ?? this.showCoordinates,
    confirmMoves: confirmMoves ?? this.confirmMoves,
    stoneSound: stoneSound ?? this.stoneSound,
    themeMode: themeMode ?? this.themeMode,
  );
}

final preferencesProvider = NotifierProvider<PreferencesController, Preferences>(
  PreferencesController.new,
);

class PreferencesController extends Notifier<Preferences> {
  static const _boardTheme = 'prefs.boardTheme';
  static const _blackStones = 'prefs.blackStones';
  static const _whiteStones = 'prefs.whiteStones';
  static const _coordinates = 'prefs.showCoordinates';
  static const _confirmMoves = 'prefs.confirmMoves';
  static const _themeMode = 'prefs.themeMode';
  static const _stoneSound = 'prefs.stoneSound';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  Preferences build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    T byName<T extends Enum>(List<T> values, String? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    return Preferences(
      boardTheme: byName(
        BoardTheme.values,
        prefs.getString(_boardTheme),
        BoardTheme.fromOldName(prefs.getString(_boardTheme)) ?? BoardTheme.kaya,
      ),
      blackStones: byName(StoneTheme.forBlack, prefs.getString(_blackStones), StoneTheme.slate),
      whiteStones: byName(StoneTheme.forWhite, prefs.getString(_whiteStones), StoneTheme.shell),
      showCoordinates: prefs.getBool(_coordinates) ?? true,
      confirmMoves: prefs.getBool(_confirmMoves) ?? true,
      stoneSound: prefs.getBool(_stoneSound) ?? true,
      themeMode: byName(AppThemeMode.values, prefs.getString(_themeMode), AppThemeMode.system),
    );
  }

  Future<void> setBoardTheme(BoardTheme theme) async {
    state = state.copyWith(boardTheme: theme);
    await _prefs.setString(_boardTheme, theme.name);
  }

  Future<void> setBlackStones(StoneTheme theme) async {
    assert(theme.black);
    state = state.copyWith(blackStones: theme);
    await _prefs.setString(_blackStones, theme.name);
  }

  Future<void> setWhiteStones(StoneTheme theme) async {
    assert(theme.white);
    state = state.copyWith(whiteStones: theme);
    await _prefs.setString(_whiteStones, theme.name);
  }

  Future<void> setShowCoordinates(bool value) async {
    state = state.copyWith(showCoordinates: value);
    await _prefs.setBool(_coordinates, value);
  }

  Future<void> setConfirmMoves(bool value) async {
    state = state.copyWith(confirmMoves: value);
    await _prefs.setBool(_confirmMoves, value);
  }

  Future<void> setStoneSound(bool value) async {
    state = state.copyWith(stoneSound: value);
    await _prefs.setBool(_stoneSound, value);
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(_themeMode, mode.name);
  }
}
