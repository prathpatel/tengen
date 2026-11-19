import 'package:flutter_test/flutter_test.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/game.dart';
import 'package:tengen/src/model/go/rules.dart';
import 'package:tengen/src/model/go/scoring.dart';
import 'package:tengen/src/model/go/sgf.dart';

void main() {
  // Black owns the left side (columns 0-1 plus the wall), white the right side (columns 3-4).
  final board = Board.parse('''
    .XO..
    .XO..
    .XO.X
    .XO..
    .XO..
  ''');

  group('scoreGame', () {
    test('territory scoring counts territory, prisoners and komi', () {
      final game = GoGame.create(
        width: 5,
        ruleset: Ruleset.japanese,
        komi: 0.5,
        initialBoard: board,
      );
      // The black stone at (4,2) is dead in white's area.
      final score = scoreGame(game, {const Point(4, 2)});
      expect(score.blackTerritory.length, 5);
      // White: columns 3 and 4, including the point of the dead stone.
      expect(score.whiteTerritory, contains(const Point(4, 2)));
      expect(score.whiteTerritory.length, 10);
      expect(score.white.prisoners, 1);
      expect(score.black.total, 5);
      expect(score.white.total, 11.5);
      expect(score.resultString, 'W+6.5');
      expect(score.dame, isEmpty);
    });

    test('area scoring counts stones on the board', () {
      final game = GoGame.create(
        width: 5,
        ruleset: Ruleset.chinese,
        komi: 0.5,
        initialBoard: board,
      );
      final score = scoreGame(game, {const Point(4, 2)});
      expect(score.black.stones, 5);
      expect(score.white.stones, 5);
      expect(score.black.total, 10);
      expect(score.white.total, 15.5);
    });

    test('a region touching both colors is dame', () {
      final game = GoGame.create(width: 5, initialBoard: board);
      final score = scoreGame(game, {});
      // With the black stone at (4,2) alive, the right side touches both colors.
      expect(score.dame, contains(const Point(4, 0)));
    });

    test('handicap compensation under area scoring', () {
      expect(Ruleset.chinese.handicapCompensation(4), 4);
      expect(Ruleset.aga.handicapCompensation(4), 3);
      expect(Ruleset.japanese.handicapCompensation(4), 0);
    });
  });

  test('toggleDeadGroup toggles a whole chain', () {
    final dead = toggleDeadGroup(board, {}, const Point(1, 0));
    expect(dead.length, 5);
    expect(toggleDeadGroup(board, dead, const Point(1, 3)), isEmpty);
  });

  test('toSgf exports setup, rules and moves', () {
    final game = GoGame.create(width: 9, handicap: 2).play(const Point(4, 4)).play(null);
    final sgf = toSgf(game, blackName: 'B]lack', whiteName: 'White', result: 'W+R');
    expect(sgf, startsWith('(;FF[4]GM[1]CA[UTF-8]AP[Tengen]SZ[9]RU[Japanese]KM[0.5]HA[2]'));
    expect(sgf, contains(r'PB[B\]lack]'));
    expect(sgf, contains('AB[gc][cg]'));
    expect(sgf, contains('PL[W]'));
    expect(sgf, endsWith(';W[ee];B[])'));
  });
}
