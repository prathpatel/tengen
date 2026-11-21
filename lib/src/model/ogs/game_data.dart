import 'package:meta/meta.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/coordinates.dart';
import 'package:tengen/src/model/go/game.dart';
import 'package:tengen/src/model/go/rules.dart';
import 'package:tengen/src/model/ogs/clock.dart';
import 'package:tengen/src/model/ogs/user.dart';
import 'package:tengen/src/utils/json.dart';

enum GamePhase {
  play,
  stoneRemoval,
  finished;

  static GamePhase fromOgs(Object? value) => switch (value) {
    'stone removal' => stoneRemoval,
    'finished' => finished,
    _ => play,
  };
}

/// Decodes a move of the OGS `moves` array: `[x, y, timedelta, edited?, extra?]`. `x == -1` is a
/// pass.
Point? decodeOgsArrayMove(Object? move) {
  final list = asList(move);
  if (list.length < 2) return null;
  final x = asInt(list[0]) ?? -1;
  final y = asInt(list[1]) ?? -1;
  return x < 0 || y < 0 ? null : Point(x, y);
}

/// The data of an OGS game (`game/<id>/gamedata` event, or `gamedata` of `/api/v1/games/<id>`).
@immutable
class OgsGameData {
  const OgsGameData({
    required this.gameId,
    required this.name,
    required this.width,
    required this.height,
    required this.ruleset,
    required this.komi,
    required this.handicap,
    required this.freeHandicapPlacement,
    required this.initialPlayer,
    required this.initialBlack,
    required this.initialWhite,
    required this.moves,
    required this.phase,
    required this.black,
    required this.white,
    required this.ranked,
    this.timeControl,
    this.clock,
    this.removed = const {},
    this.outcome,
    this.winnerId,
    this.stallingScoreEstimate,
  });

  factory OgsGameData.fromJson(Map<String, dynamic> json) {
    final players = asMap(json['players']) ?? const {};
    final initialState = asMap(json['initial_state']) ?? const {};
    final width = asInt(json['width']) ?? 19;
    final tc = asMap(json['time_control']);
    final clock = asMap(json['clock']);
    final removed = json['removed'];
    return OgsGameData(
      gameId: asInt(json['game_id'] ?? json['id']) ?? 0,
      name: json['game_name'] as String? ?? json['name'] as String? ?? '',
      width: width,
      height: asInt(json['height']) ?? width,
      ruleset: Ruleset.fromOgs(json['rules'] as String?),
      komi: asDouble(json['komi']) ?? 0,
      handicap: asInt(json['handicap']) ?? 0,
      freeHandicapPlacement: json['free_handicap_placement'] == true,
      initialPlayer: json['initial_player'] == 'white' ? StoneColor.white : StoneColor.black,
      initialBlack: decodeOgsMoves(initialState['black'] as String? ?? '').nonNulls.toList(),
      initialWhite: decodeOgsMoves(initialState['white'] as String? ?? '').nonNulls.toList(),
      moves: [for (final m in asList(json['moves'])) decodeOgsArrayMove(m)],
      phase: GamePhase.fromOgs(json['phase']),
      black: OgsUser.fromJson(
        asMap(players['black']) ?? {'id': json['black_player_id'], 'username': 'Black'},
      ),
      white: OgsUser.fromJson(
        asMap(players['white']) ?? {'id': json['white_player_id'], 'username': 'White'},
      ),
      ranked: json['ranked'] == true,
      timeControl: tc == null ? null : OgsTimeControl.fromJson(tc),
      clock: clock == null || clock['black_time'] == null ? null : OgsClock.fromJson(clock),
      removed: removed is String ? decodeOgsMoves(removed).nonNulls.toSet() : const {},
      outcome: json['outcome'] as String?,
      winnerId: asInt(json['winner']),
      stallingScoreEstimate: asMap(json['stalling_score_estimate']),
    );
  }

  final int gameId;
  final String name;
  final int width;
  final int height;
  final Ruleset ruleset;
  final double komi;
  final int handicap;
  final bool freeHandicapPlacement;
  final StoneColor initialPlayer;
  final List<Point> initialBlack;
  final List<Point> initialWhite;

  /// Moves played so far; null entries are passes.
  final List<Point?> moves;
  final GamePhase phase;
  final OgsUser black;
  final OgsUser white;
  final bool ranked;
  final OgsTimeControl? timeControl;
  final OgsClock? clock;

  /// Stones marked dead (and dame) during or after stone removal.
  final Set<Point> removed;
  final String? outcome;
  final int? winnerId;

  /// The raw anti-stalling estimate, when OGS considers the game over.
  final Map<String, dynamic>? stallingScoreEstimate;

  StoneColor? get winner => winnerId == null
      ? null
      : (winnerId == black.id
            ? StoneColor.black
            : (winnerId == white.id ? StoneColor.white : null));

  OgsUser player(StoneColor color) => color == StoneColor.black ? black : white;

  /// The color played by [userId] in this game, if any.
  StoneColor? colorOf(int? userId) => userId == null
      ? null
      : (userId == black.id ? StoneColor.black : (userId == white.id ? StoneColor.white : null));

  /// Builds the game by replaying the server moves.
  ///
  /// Moves are not validated: the server is authoritative.
  static final _built = Expando<GoGame>();

  /// [buildGame], replayed once per game data: lists show many games and rebuild often.
  GoGame buildGameCached() => _built[this] ??= buildGame();

  GoGame buildGame() {
    final hasSetup = initialBlack.isNotEmpty || initialWhite.isNotEmpty;
    final placesFixedHandicap =
        !hasSetup && handicap > 1 && !freeHandicapPlacement && width == height;
    var game = GoGame.create(
      width: width,
      height: height,
      ruleset: ruleset,
      komi: komi,
      handicap: handicap,
      freeHandicapPlacement: freeHandicapPlacement,
      initialBoard: hasSetup
          ? Board.empty(
              width,
              height,
            ).withStones(initialBlack, StoneColor.black).withStones(initialWhite, StoneColor.white)
          : null,
      // When the fixed handicap stones are placed here, white plays first as on OGS.
      initialPlayer: placesFixedHandicap ? null : initialPlayer,
    );
    for (final m in moves) {
      game = game.playMove(GoMove(game.toMove, m), validate: false);
    }
    return game;
  }

  OgsGameData copyWith({
    List<Point?>? moves,
    GamePhase? phase,
    OgsClock? clock,
    Set<Point>? removed,
    String? outcome,
    int? winnerId,
  }) => OgsGameData(
    gameId: gameId,
    name: name,
    width: width,
    height: height,
    ruleset: ruleset,
    komi: komi,
    handicap: handicap,
    freeHandicapPlacement: freeHandicapPlacement,
    initialPlayer: initialPlayer,
    initialBlack: initialBlack,
    initialWhite: initialWhite,
    moves: moves ?? this.moves,
    phase: phase ?? this.phase,
    black: black,
    white: white,
    ranked: ranked,
    timeControl: timeControl,
    clock: clock ?? this.clock,
    removed: removed ?? this.removed,
    outcome: outcome ?? this.outcome,
    winnerId: winnerId ?? this.winnerId,
    stallingScoreEstimate: stallingScoreEstimate,
  );
}

/// An entry of the live / correspondence game lists (`gamelist/query`).
@immutable
class GameListEntry {
  const GameListEntry({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.moveNumber,
    required this.black,
    required this.white,
    required this.phase,
    this.handicap = 0,
    this.komi,
    this.ranked = false,
  });

  factory GameListEntry.fromJson(Map<String, dynamic> json) => GameListEntry(
    id: asInt(json['id']) ?? 0,
    name: json['name'] as String? ?? '',
    width: asInt(json['width']) ?? 19,
    height: asInt(json['height']) ?? 19,
    moveNumber: asInt(json['move_number']) ?? 0,
    black: OgsUser.fromJson(asMap(json['black']) ?? const {}),
    white: OgsUser.fromJson(asMap(json['white']) ?? const {}),
    phase: GamePhase.fromOgs(json['phase']),
    handicap: asInt(json['handicap']) ?? 0,
    komi: asDouble(json['komi']),
    ranked: json['ranked'] == true,
  );

  final int id;
  final String name;
  final int width;
  final int height;
  final int moveNumber;
  final OgsUser black;
  final OgsUser white;
  final GamePhase phase;
  final int handicap;
  final double? komi;
  final bool ranked;
}

/// A game of the signed in player (`active_games` of `ui/overview`, or a player's game history).
@immutable
class PlayerGame {
  const PlayerGame({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.black,
    required this.white,
    this.data,
    this.outcome,
    this.blackLost,
    this.whiteLost,
    this.ended,
  });

  factory PlayerGame.fromJson(Map<String, dynamic> json) {
    final players = asMap(json['players']) ?? const {};
    final gamedata = asMap(json['json'] ?? json['gamedata']);
    return PlayerGame(
      id: asInt(json['id']) ?? 0,
      name: json['name'] as String? ?? '',
      width: asInt(json['width']) ?? 19,
      height: asInt(json['height']) ?? 19,
      black: OgsUser.fromJson(asMap(players['black'] ?? json['black']) ?? const {}),
      white: OgsUser.fromJson(asMap(players['white'] ?? json['white']) ?? const {}),
      data: gamedata == null ? null : OgsGameData.fromJson({...gamedata, 'game_id': json['id']}),
      outcome: json['outcome'] as String?,
      blackLost: json['black_lost'] as bool?,
      whiteLost: json['white_lost'] as bool?,
      ended: json['ended'] is String ? DateTime.tryParse(json['ended'] as String) : null,
    );
  }

  final int id;
  final String name;
  final int width;
  final int height;
  final OgsUser black;
  final OgsUser white;

  /// The full game data, included for active games.
  final OgsGameData? data;
  final String? outcome;
  final bool? blackLost;
  final bool? whiteLost;
  final DateTime? ended;

  /// Whether it is [userId]'s turn, for active games.
  bool isTurnOf(int userId) => data?.clock?.currentPlayerId == userId;

  StoneColor? get winner => switch ((blackLost, whiteLost)) {
    (false, true) => StoneColor.black,
    (true, false) => StoneColor.white,
    _ => null,
  };
}
