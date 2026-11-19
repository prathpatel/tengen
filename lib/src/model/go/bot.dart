import 'dart:math' as math;

import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/game.dart';

/// A small heuristic opponent for offline practice games.
///
/// It is not a strong player: it captures, saves its stones in atari, avoids self-atari and
/// filling its own eyes, and otherwise plays near the action. It passes when the opponent passed
/// and nothing valuable is left, or when it has no sensible move.
class SimpleBot {
  SimpleBot({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;

  /// Chooses a move for the player to move in [game]. Returns null to pass.
  Point? chooseMove(GoGame game) {
    final color = game.toMove;
    final board = game.board;
    final opponentPassed = game.position.lastMove?.isPass ?? false;

    if (board.isEmpty || (board.count(color) == 0 && board.width >= 9)) {
      final opening = _openingMove(game);
      if (opening != null) return opening;
    }

    Point? best;
    var bestScore = double.negativeInfinity;
    for (final p in board.points) {
      if (board[p] != null || _isOwnEye(board, p, color)) continue;
      final GoGame next;
      try {
        next = game.play(p);
      } on IllegalMoveException {
        continue;
      }
      final score = _evaluate(game, next, p, color) + _random.nextDouble() * 0.5;
      if (score > bestScore) {
        bestScore = score;
        best = p;
      }
    }
    if (best == null) return null;
    if (opponentPassed && bestScore < 3) return null;
    return best;
  }

  Point? _openingMove(GoGame game) {
    final w = game.width;
    final h = game.height;
    final line = w >= 13 ? 3 : 2;
    final candidates = [
      Point(w - 1 - line, line),
      Point(line, h - 1 - line),
      Point(w - 1 - line, h - 1 - line),
      Point(line, line),
    ].where((p) => game.board[p] == null && game.isLegal(p)).toList();
    if (candidates.isEmpty) return null;
    return candidates[_random.nextInt(candidates.length)];
  }

  /// An empty point surrounded by own stones whose groups have other liberties.
  bool _isOwnEye(Board board, Point p, StoneColor color) {
    for (final n in board.neighbors(p)) {
      if (board[n] != color) return false;
      if (board.groupAt(n)!.liberties.length <= 1) return false;
    }
    // A false eye has opponents on too many diagonals; treat it as a real eye only if the
    // diagonals are mostly ours.
    var badDiagonals = 0;
    var diagonals = 0;
    for (final d in [(-1, -1), (1, -1), (-1, 1), (1, 1)]) {
      final q = Point(p.x + d.$1, p.y + d.$2);
      if (!board.contains(q)) continue;
      diagonals++;
      if (board[q] == color.opposite) badDiagonals++;
    }
    final onEdge = diagonals < 4;
    return onEdge ? badDiagonals == 0 : badDiagonals <= 1;
  }

  double _evaluate(GoGame before, GoGame after, Point p, StoneColor color) {
    final board = before.board;
    var score = 0.0;

    final captured = after.position.capturesOf(color) - before.position.capturesOf(color);
    score += captured * 10;

    final own = after.board.groupAt(p)!;
    final libs = own.liberties.length;
    if (libs == 1) {
      score -= 12 + own.stones.length * 2; // self-atari
    } else {
      score += math.min(libs, 4).toDouble();
    }

    for (final n in board.neighbors(p)) {
      final c = board[n];
      if (c == color) {
        final g = board.groupAt(n)!;
        if (g.liberties.length == 1 && libs > 1) score += 8 + g.stones.length * 2; // saved
      } else if (c == color.opposite) {
        final g = after.board.groupAt(n);
        if (g != null && g.liberties.length == 1) score += 3 + g.stones.length; // atari
        score += 0.5; // contact
      }
    }

    // Filling a region only we border wastes a move (and a point under territory scoring).
    final region = board.emptyRegionAt(p);
    if (region.borders.length == 1 && region.borders.first == color && region.points.length < 30) {
      score -= 6;
    }

    // Stay away from the first line, and prefer points near existing stones.
    final edge = [p.x, p.y, board.width - 1 - p.x, board.height - 1 - p.y].reduce(math.min);
    if (edge == 0) score -= 2;
    if (edge == 1) score -= 0.5;
    var nearby = 0;
    for (var dx = -2; dx <= 2; dx++) {
      for (var dy = -2; dy <= 2; dy++) {
        final q = Point(p.x + dx, p.y + dy);
        if (board.contains(q) && board[q] != null) nearby++;
      }
    }
    return score + math.min(nearby, 3) * 0.4;
  }
}
