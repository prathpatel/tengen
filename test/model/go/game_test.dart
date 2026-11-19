import 'package:flutter_test/flutter_test.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/coordinates.dart';
import 'package:tengen/src/model/go/game.dart';
import 'package:tengen/src/model/go/rules.dart';

GoGame playAll(GoGame game, List<Point?> points) => points.fold(game, (g, p) => g.play(p));

void main() {
  group('Board', () {
    test('parse and print round trip', () {
      const ascii = 'X.O\n...\nOOX';
      expect(Board.parse(ascii).toString(), ascii);
    });

    test('group and liberties', () {
      final board = Board.parse('''
        XX.
        X.O
        ...
      ''');
      final group = board.groupAt(const Point(0, 0))!;
      expect(group.stones, {const Point(0, 0), const Point(1, 0), const Point(0, 1)});
      expect(group.liberties, {const Point(2, 0), const Point(1, 1), const Point(0, 2)});
    });
  });

  group('GoGame', () {
    test('black plays first and colors alternate', () {
      var game = GoGame.create(width: 9);
      expect(game.toMove, StoneColor.black);
      game = game.play(const Point(4, 4));
      expect(game.toMove, StoneColor.white);
      expect(game.board[const Point(4, 4)], StoneColor.black);
      game = game.play(null);
      expect(game.toMove, StoneColor.black);
    });

    test('captures a single stone in the corner', () {
      final game = playAll(GoGame.create(width: 9), const [
        Point(1, 0), // B
        Point(0, 0), // W
        Point(0, 1), // B captures
      ]);
      expect(game.board[const Point(0, 0)], isNull);
      expect(game.position.blackCaptures, 1);
      expect(game.position.whiteCaptures, 0);
    });

    test('captures a group', () {
      final board = Board.parse('''
        OX...
        OX...
        .....
        .....
        .....
      ''');
      final game = GoGame.create(width: 5, initialBoard: board).play(const Point(0, 2));
      expect(game.board[const Point(0, 0)], isNull);
      expect(game.board[const Point(0, 1)], isNull);
      expect(game.position.blackCaptures, 2);
    });

    test('rejects occupied points', () {
      final game = GoGame.create(width: 9).play(const Point(2, 2));
      expect(
        () => game.play(const Point(2, 2)),
        throwsA(
          isA<IllegalMoveException>().having((e) => e.reason, 'reason', IllegalMoveReason.occupied),
        ),
      );
    });

    test('rejects single stone suicide', () {
      final board = Board.parse('''
        .X.
        X..
        ...
      ''');
      final game = GoGame.create(width: 3, initialBoard: board, initialPlayer: StoneColor.white);
      expect(game.isLegal(const Point(0, 0)), isFalse);
      expect(game.isLegal(const Point(2, 2)), isTrue);
    });

    test('multi stone suicide is legal only where the rules allow it', () {
      final board = Board.parse('''
        O.X..
        XX...
        .....
        .....
        .....
      ''');
      for (final (ruleset, legal) in [(Ruleset.japanese, false), (Ruleset.nz, true)]) {
        final game = GoGame.create(
          width: 5,
          ruleset: ruleset,
          initialBoard: board,
          initialPlayer: StoneColor.white,
        );
        expect(game.isLegal(const Point(1, 0)), legal, reason: ruleset.name);
        if (legal) {
          final after = game.play(const Point(1, 0));
          expect(after.board[const Point(0, 0)], isNull);
          expect(after.board[const Point(1, 0)], isNull);
          expect(after.position.blackCaptures, 2);
        }
      }
    });

    test('simple ko forbids the immediate recapture', () {
      final board = Board.parse('''
        .XO..
        X.XO.
        .XO..
        .....
        .....
      ''');
      var game = GoGame.create(width: 5, initialBoard: board, initialPlayer: StoneColor.white);
      // White captures the black stone at (2,1) by playing (1,1).
      game = game.play(const Point(1, 1));
      expect(game.board[const Point(2, 1)], isNull);
      expect(game.position.whiteCaptures, 1);
      // Black cannot retake immediately.
      expect(
        () => game.play(const Point(2, 1)),
        throwsA(
          isA<IllegalMoveException>().having((e) => e.reason, 'reason', IllegalMoveReason.ko),
        ),
      );
      // After a ko threat exchange, the recapture is legal.
      game = game.play(const Point(4, 4)).play(const Point(4, 3));
      expect(game.isLegal(const Point(2, 1)), isTrue);
    });

    test('undo restores the previous position', () {
      final game = GoGame.create(width: 9).play(const Point(1, 1)).play(const Point(2, 2));
      final undone = game.undo();
      expect(undone.moveCount, 1);
      expect(undone.board[const Point(2, 2)], isNull);
      expect(undone.toMove, StoneColor.white);
    });

    test('two passes end the game', () {
      final game = GoGame.create(width: 9).play(null).play(null);
      expect(game.bothPassed, isTrue);
    });

    test('fixed handicap places stones and white starts', () {
      final game = GoGame.create(width: 19, handicap: 4);
      expect(game.freeHandicapPlacement, isFalse);
      expect(game.board.count(StoneColor.black), 4);
      expect(game.toMove, StoneColor.white);
      expect(game.komi, 0.5);
      for (final p in const [Point(3, 3), Point(15, 3), Point(3, 15), Point(15, 15)]) {
        expect(game.board[p], StoneColor.black);
      }
    });

    test('fixed handicap layouts match the expected stone counts', () {
      for (final size in [9, 13, 19]) {
        for (var h = 2; h <= 9; h++) {
          final stones = fixedHandicapStones(size, h);
          expect(stones.toSet().length, h, reason: '$size x $size, $h stones');
        }
      }
    });

    test('free handicap: black places all stones, then white plays', () {
      var game = GoGame.create(width: 19, handicap: 3, freeHandicapPlacement: true);
      expect(game.handicapStonesLeft, 3);
      game = game.play(const Point(3, 3));
      expect(game.toMove, StoneColor.black);
      game = game.play(const Point(15, 15));
      expect(game.toMove, StoneColor.black);
      game = game.play(const Point(3, 15));
      expect(game.handicapStonesLeft, 0);
      expect(game.toMove, StoneColor.white);
      game = game.play(const Point(15, 3));
      expect(game.toMove, StoneColor.black);
    });

    test('server moves skip validation', () {
      final game = GoGame.create(width: 9).play(const Point(0, 0));
      final next = game.playMove(const GoMove(StoneColor.black, Point(1, 1)), validate: false);
      expect(next.board[const Point(1, 1)], StoneColor.black);
    });
  });

  group('coordinates', () {
    test('OGS encoding round trip', () {
      const points = [Point(3, 15), null, Point(0, 0), Point(18, 18)];
      final encoded = points.map(encodeOgsMove).join();
      expect(encoded, 'dp..aass');
      expect(decodeOgsMoves(encoded), points);
    });

    test('pretty coordinates skip I', () {
      expect(prettyCoordinate(const Point(3, 15), 19), 'D4');
      expect(prettyCoordinate(const Point(8, 0), 19), 'J19');
      expect(prettyCoordinate(null, 19), 'Pass');
    });
  });
}
