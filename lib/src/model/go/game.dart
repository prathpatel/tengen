import 'package:meta/meta.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/coordinates.dart';
import 'package:tengen/src/model/go/rules.dart';

/// A move: a stone placement, or a pass when [point] is null.
@immutable
class GoMove {
  const GoMove(this.color, this.point);
  const GoMove.pass(this.color) : point = null;

  final StoneColor color;
  final Point? point;

  bool get isPass => point == null;

  @override
  bool operator ==(Object other) => other is GoMove && other.color == color && other.point == point;

  @override
  int get hashCode => Object.hash(color, point);

  @override
  String toString() => 'GoMove(${color.code}, ${point ?? 'pass'})';
}

enum IllegalMoveReason { occupied, outOfBounds, suicide, ko, superko, wrongTurn, gameOver }

class IllegalMoveException implements Exception {
  const IllegalMoveException(this.reason);

  final IllegalMoveReason reason;

  String get message => switch (reason) {
    IllegalMoveReason.occupied => 'There is already a stone there.',
    IllegalMoveReason.outOfBounds => 'That point is not on the board.',
    IllegalMoveReason.suicide => 'Suicide is not allowed.',
    IllegalMoveReason.ko => 'Ko: you must play elsewhere first.',
    IllegalMoveReason.superko => 'This move would repeat an earlier position.',
    IllegalMoveReason.wrongTurn => 'It is not your turn.',
    IllegalMoveReason.gameOver => 'The game is over.',
  };

  @override
  String toString() => 'IllegalMoveException($reason)';
}

/// A board position in a game, after a given number of moves.
@immutable
class GoPosition {
  const GoPosition({
    required this.board,
    required this.toMove,
    required this.blackCaptures,
    required this.whiteCaptures,
    this.lastMove,
    this.consecutivePasses = 0,
  });

  final Board board;
  final StoneColor toMove;

  /// Stones captured by black (white prisoners).
  final int blackCaptures;

  /// Stones captured by white (black prisoners).
  final int whiteCaptures;
  final GoMove? lastMove;
  final int consecutivePasses;

  int capturesOf(StoneColor color) => color == StoneColor.black ? blackCaptures : whiteCaptures;
}

/// Immutable game record: setup, rules, and the sequence of positions reached by the moves.
///
/// The engine validates moves according to [ruleset]. When replaying moves coming from a server
/// that already validated them (OGS), use [GoGame.play] with `validate: false` so that a rules
/// subtlety implemented differently here never desynchronises the board.
@immutable
class GoGame {
  const GoGame._({
    required this.width,
    required this.height,
    required this.ruleset,
    required this.komi,
    required this.handicap,
    required this.freeHandicapPlacement,
    required this.moves,
    required this.positions,
    required this._seenPositions,
  });

  /// A new game. With fixed handicap placement, the handicap stones are put on the board and white
  /// moves first. With free placement black places the [handicap] stones as its first moves.
  factory GoGame.create({
    int width = 19,
    int? height,
    Ruleset ruleset = Ruleset.japanese,
    double? komi,
    int handicap = 0,
    bool? freeHandicapPlacement,
    Board? initialBoard,
    StoneColor? initialPlayer,
  }) {
    final h = height ?? width;
    var board = initialBoard ?? Board.empty(width, h);
    final fixedStones = width == h ? fixedHandicapStones(width, handicap) : const <Point>[];
    // Sizes without a fixed layout always use free placement, as on OGS.
    final free = handicap > 1 && ((freeHandicapPlacement ?? false) || fixedStones.isEmpty);
    var first = initialPlayer ?? StoneColor.black;
    if (handicap > 1 && !free && initialBoard == null) {
      board = board.withStones(fixedStones, StoneColor.black);
      first = initialPlayer ?? StoneColor.white;
    }
    final start = GoPosition(board: board, toMove: first, blackCaptures: 0, whiteCaptures: 0);
    return GoGame._(
      width: width,
      height: h,
      ruleset: ruleset,
      komi: komi ?? ruleset.defaultKomi(handicap),
      handicap: handicap,
      freeHandicapPlacement: free,
      moves: const [],
      positions: [start],
      seenPositions: {board.positionKey},
    );
  }

  final int width;
  final int height;
  final Ruleset ruleset;
  final double komi;
  final int handicap;
  final bool freeHandicapPlacement;
  final List<GoMove> moves;

  /// `positions[i]` is the position after `i` moves; `positions.first` is the initial setup.
  final List<GoPosition> positions;
  final Set<String> _seenPositions;

  GoPosition get position => positions.last;
  Board get board => position.board;
  StoneColor get toMove => position.toMove;
  int get moveCount => moves.length;

  /// Whether both players passed in a row: the game proceeds to counting.
  bool get bothPassed => position.consecutivePasses >= 2;

  /// Number of free handicap stones black still has to place.
  int get handicapStonesLeft =>
      freeHandicapPlacement && handicap > 1 ? (handicap - moves.length).clamp(0, handicap) : 0;

  /// The color to move once [n] moves have been played, given the [first] player.
  StoneColor _playerFor(int n, StoneColor first) {
    if (freeHandicapPlacement && handicap > 1) {
      // Black places all its handicap stones, then white plays and the colors alternate.
      if (n < handicap) return StoneColor.black;
      return (n - handicap).isEven ? StoneColor.white : StoneColor.black;
    }
    return n.isEven ? first : first.opposite;
  }

  /// Whether a stone of the player to move may be placed at [p].
  bool isLegal(Point p) {
    try {
      _computeNext(GoMove(toMove, p), validate: true);
      return true;
    } on IllegalMoveException {
      return false;
    }
  }

  /// Returns the game after [point] (null for a pass) is played by the player to move.
  GoGame play(Point? point, {bool validate = true}) =>
      playMove(GoMove(toMove, point), validate: validate);

  /// Returns the game after [move]. The move's color may differ from [toMove] only when
  /// [validate] is false (setup or server-provided moves).
  GoGame playMove(GoMove move, {bool validate = true}) {
    final next = _computeNext(move, validate: validate);
    return GoGame._(
      width: width,
      height: height,
      ruleset: ruleset,
      komi: komi,
      handicap: handicap,
      freeHandicapPlacement: freeHandicapPlacement,
      moves: List.unmodifiable([...moves, move]),
      positions: List.unmodifiable([...positions, next]),
      seenPositions: {..._seenPositions, next.board.positionKey},
    );
  }

  GoPosition _computeNext(GoMove move, {required bool validate}) {
    final current = position;
    if (validate && move.color != current.toMove) {
      throw const IllegalMoveException(IllegalMoveReason.wrongTurn);
    }
    final nextToMove = _playerFor(moves.length + 1, positions.first.toMove);
    final point = move.point;
    if (point == null) {
      return GoPosition(
        board: current.board,
        toMove: nextToMove,
        blackCaptures: current.blackCaptures,
        whiteCaptures: current.whiteCaptures,
        lastMove: move,
        consecutivePasses: current.consecutivePasses + 1,
      );
    }
    if (!current.board.contains(point)) {
      throw const IllegalMoveException(IllegalMoveReason.outOfBounds);
    }
    if (current.board[point] != null) {
      if (validate) throw const IllegalMoveException(IllegalMoveReason.occupied);
      // A server move on an occupied point: the server state wins, overwrite the stone.
      final board = current.board.withStones([point], move.color);
      return GoPosition(
        board: board,
        toMove: nextToMove,
        blackCaptures: current.blackCaptures,
        whiteCaptures: current.whiteCaptures,
        lastMove: move,
      );
    }
    final result = current.board.place(move.color, point);
    if (validate) {
      if (result.suicided.isNotEmpty) {
        // Single stone suicide is never legal; multi stone suicide depends on the rule set.
        if (!ruleset.allowSuicide || result.suicided.length == 1) {
          throw const IllegalMoveException(IllegalMoveReason.suicide);
        }
      }
      final key = result.board.positionKey;
      if (positions.length >= 2 && positions[positions.length - 2].board.positionKey == key) {
        throw const IllegalMoveException(IllegalMoveReason.ko);
      }
      if (ruleset.superko && _seenPositions.contains(key)) {
        throw const IllegalMoveException(IllegalMoveReason.superko);
      }
    }
    final capturedByMover = result.captured.length;
    final suicided = result.suicided.length;
    final isBlack = move.color == StoneColor.black;
    return GoPosition(
      board: result.board,
      toMove: nextToMove,
      blackCaptures: current.blackCaptures + (isBlack ? capturedByMover : suicided),
      whiteCaptures: current.whiteCaptures + (isBlack ? suicided : capturedByMover),
      lastMove: move,
    );
  }

  /// The game without its last move.
  GoGame undo() {
    if (moves.isEmpty) return this;
    return GoGame._(
      width: width,
      height: height,
      ruleset: ruleset,
      komi: komi,
      handicap: handicap,
      freeHandicapPlacement: freeHandicapPlacement,
      moves: List.unmodifiable(moves.sublist(0, moves.length - 1)),
      positions: List.unmodifiable(positions.sublist(0, positions.length - 1)),
      seenPositions: {for (final p in positions.take(positions.length - 1)) p.board.positionKey},
    );
  }
}
