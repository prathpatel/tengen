import 'package:meta/meta.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/game.dart';

/// Score details for one side.
@immutable
class SideScore {
  const SideScore({
    required this.territory,
    required this.stones,
    required this.prisoners,
    required this.komi,
    required this.handicap,
  });

  final int territory;
  final int stones;
  final int prisoners;
  final double komi;
  final int handicap;

  double get total => territory + stones + prisoners + komi + handicap;
}

/// The result of counting a finished game.
@immutable
class GameScore {
  const GameScore({
    required this.black,
    required this.white,
    required this.blackTerritory,
    required this.whiteTerritory,
    required this.dame,
  });

  final SideScore black;
  final SideScore white;

  /// Intersections counted as territory for each side, for display on the board.
  final Set<Point> blackTerritory;
  final Set<Point> whiteTerritory;

  /// Empty intersections that belong to no one.
  final Set<Point> dame;

  StoneColor? get winner => black.total == white.total
      ? null
      : (black.total > white.total ? StoneColor.black : StoneColor.white);

  double get margin => (black.total - white.total).abs();

  /// Result in the usual notation, e.g. `B+3.5`, `W+0.5` or `Jigo`.
  String get resultString {
    final w = winner;
    if (w == null) return 'Jigo';
    final m = margin;
    return '${w.code}+${m == m.roundToDouble() ? m.toInt() : m}';
  }
}

/// Counts [game], with [deadStones] removed from the board.
///
/// Empty regions bordered by a single color are that color's territory. Under territory scoring
/// (Japanese, Korean) each side scores territory + prisoners, dead stones counting as prisoners.
/// Under area scoring each side scores territory + stones on the board.
GameScore scoreGame(GoGame game, Set<Point> deadStones) {
  final board = game.board;
  final dead = {
    for (final p in deadStones)
      if (board[p] != null) p,
  };
  final blackTerritory = <Point>{};
  final whiteTerritory = <Point>{};
  final dame = <Point>{};
  final visited = <Point>{};

  bool isOpen(Point p) => board[p] == null || dead.contains(p);

  for (final p in board.points) {
    if (!isOpen(p) || visited.contains(p)) continue;
    final region = board.emptyRegionAt(p, treatAsEmpty: dead);
    visited.addAll(region.points);
    // Dead stones are not borders: emptyRegionAt treated them as empty, so the borders only
    // contain living stones.
    if (region.borders.length == 1) {
      (region.borders.first == StoneColor.black ? blackTerritory : whiteTerritory).addAll(
        region.points,
      );
    } else {
      dame.addAll(region.points.where((q) => board[q] == null));
    }
  }

  final deadBlack = dead.where((p) => board[p] == StoneColor.black).length;
  final deadWhite = dead.where((p) => board[p] == StoneColor.white).length;
  final area = game.ruleset.areaScoring;

  final blackScore = SideScore(
    territory: blackTerritory.length,
    stones: area ? board.count(StoneColor.black) - deadBlack : 0,
    prisoners: area ? 0 : game.position.blackCaptures + deadWhite,
    komi: 0,
    handicap: 0,
  );
  final whiteScore = SideScore(
    territory: whiteTerritory.length,
    stones: area ? board.count(StoneColor.white) - deadWhite : 0,
    prisoners: area ? 0 : game.position.whiteCaptures + deadBlack,
    komi: game.komi,
    handicap: area ? game.ruleset.handicapCompensation(game.handicap) : 0,
  );
  return GameScore(
    black: blackScore,
    white: whiteScore,
    blackTerritory: blackTerritory,
    whiteTerritory: whiteTerritory,
    dame: dame,
  );
}

/// Toggles the dead status of the chain of stones at [p] in [deadStones].
Set<Point> toggleDeadGroup(Board board, Set<Point> deadStones, Point p) {
  final group = board.groupAt(p);
  if (group == null) return deadStones;
  return deadStones.contains(p)
      ? deadStones.difference(group.stones)
      : {...deadStones, ...group.stones};
}
