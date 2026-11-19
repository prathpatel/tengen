import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/game.dart';
import 'package:tengen/src/model/puzzle/puzzle.dart';

/// The rules of OGS puzzles (goban `InteractiveBase`, puzzle mode), shared by the OGS puzzles and
/// the Learning Hub:
///
/// - a move found in the tree is played; a branch marked correct solves the puzzle, one marked
///   wrong fails it;
/// - when the branch continues, the opponent answers with one of its replies, chosen at random;
/// - a move outside the tree, or a line ending without a correct mark, fails.
@immutable
class TreeSolver {
  const TreeSolver({required this.game, required this.node, this.status = PuzzleStatus.solving});

  factory TreeSolver.start(Board board, StoneColor toPlay, PuzzleNode root) => TreeSolver(
    game: GoGame.create(
      width: board.width,
      height: board.height,
      initialBoard: board,
      initialPlayer: toPlay,
    ),
    node: root,
  );

  final GoGame game;

  /// The node of the tree reached by the moves played.
  final PuzzleNode node;
  final PuzzleStatus status;

  /// Plays the solver's move. Throws [IllegalMoveException] for an illegal move.
  TreeSolver play(Point p) {
    final next = game.play(p);
    final branch = node.branchAt(p);
    if (branch == null) return TreeSolver(game: next, node: node, status: PuzzleStatus.wrong);
    if (branch.correct) return TreeSolver(game: next, node: branch, status: PuzzleStatus.correct);
    if (branch.wrong || branch.branches.isEmpty) {
      return TreeSolver(game: next, node: branch, status: PuzzleStatus.wrong);
    }
    return TreeSolver(game: next, node: branch);
  }

  /// The opponent's answer, one of the branch's replies chosen at random as OGS does.
  TreeSolver reply([math.Random? random]) {
    if (node.branches.isEmpty) {
      return TreeSolver(game: game, node: node, status: PuzzleStatus.wrong);
    }
    final replies = node.branches;
    final answer = replies[(random ?? math.Random()).nextInt(replies.length)];
    final next = game.playMove(GoMove(game.toMove, answer.point), validate: false);
    final status = answer.correct
        ? PuzzleStatus.correct
        : (answer.wrong || answer.branches.isEmpty ? PuzzleStatus.wrong : PuzzleStatus.solving);
    return TreeSolver(game: next, node: answer, status: status);
  }

  /// The moves from here that lead to a correct answer.
  Set<Point> hint() {
    bool leadsToCorrect(PuzzleNode n) => n.correct || n.branches.any(leadsToCorrect);
    return {
      for (final b in node.branches)
        if (b.point != null && leadsToCorrect(b)) b.point!,
    };
  }
}
