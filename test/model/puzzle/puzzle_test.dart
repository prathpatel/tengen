import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/game.dart';
import 'package:tengen/src/model/puzzle/puzzle.dart';

import '../../fakes.dart';

/// A small life and death problem in the OGS format: black kills at (2,2); after (1,2) white
/// answers (2,2) and it is wrong.
const puzzleJson = {
  'id': 1,
  'name': 'Kill',
  'collection': 9,
  'puzzle': {
    'puzzle_type': 'life_and_death',
    'width': 9,
    'height': 9,
    'initial_player': 'black',
    'initial_state': {'black': 'adbdcdddde', 'white': 'acbcccdc'},
    'move_tree': {
      'x': -1,
      'y': -1,
      'text': 'Black to kill.',
      'branches': [
        {
          'x': 4,
          'y': 2,
          'branches': [
            {
              'x': 4,
              'y': 1,
              'branches': [
                {'x': 4, 'y': 3, 'correct_answer': true, 'text': 'Well done!'},
              ],
            },
          ],
        },
        {
          'x': 1,
          'y': 1,
          'branches': [
            {'x': 2, 'y': 1, 'wrong_answer': true},
          ],
        },
      ],
    },
  },
};

void main() {
  Future<({ProviderContainer container, PuzzleController controller})> load() async {
    final (:container, sockets: _) = await makeContainer(
      http: (r) => switch (r.url.path) {
        '/api/v1/ui/config' => guestConfig,
        '/api/v1/puzzles/1' => puzzleJson,
        _ => null,
      },
    );
    addTearDown(container.dispose);
    final sub = container.listen(puzzleProvider(1), (_, _) {});
    addTearDown(sub.close);
    await container.read(puzzleProvider(1).future);
    return (container: container, controller: container.read(puzzleProvider(1).notifier));
  }

  test('parses the OGS puzzle format', () {
    final puzzle = Puzzle.fromJson(puzzleJson);
    expect(puzzle.toPlay, StoneColor.black);
    expect(puzzle.board[const Point(0, 3)], StoneColor.black);
    expect(puzzle.board[const Point(0, 2)], StoneColor.white);
    expect(puzzle.root.text, 'Black to kill.');
    expect(puzzle.root.branches, hasLength(2));
    expect(puzzle.hasSolution, isTrue);
    expect(puzzle.typeLabel, 'Life and death');
  });

  test('a move outside the tree is wrong, and retry starts over', () async {
    final (:container, :controller) = await load();
    expect(controller.play(const Point(8, 8)), isNull);
    var state = container.read(puzzleProvider(1)).value!;
    expect(state.status, PuzzleStatus.wrong);
    expect(state.canPlay, isFalse);
    controller.retry();
    state = container.read(puzzleProvider(1)).value!;
    expect(state.status, PuzzleStatus.solving);
    expect(state.game.moveCount, 0);
    expect(state.message, 'Black to kill.');
  });

  test('the opponent answers, and the correct branch solves the puzzle', () async {
    final (:container, :controller) = await load();
    expect(controller.hint(), {const Point(4, 2)});
    controller.play(const Point(4, 2));
    expect(container.read(puzzleProvider(1)).value!.opponentThinking, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    var state = container.read(puzzleProvider(1)).value!;
    expect(state.game.board[const Point(4, 1)], StoneColor.white);
    expect(state.status, PuzzleStatus.solving);
    controller.play(const Point(4, 3));
    state = container.read(puzzleProvider(1)).value!;
    expect(state.status, PuzzleStatus.correct);
    expect(state.message, 'Well done!');
  });

  test('a branch leading to a wrong answer fails after the reply', () async {
    final (:container, :controller) = await load();
    controller.play(const Point(1, 1));
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(container.read(puzzleProvider(1)).value!.status, PuzzleStatus.wrong);
  });

  test('illegal moves are refused without failing the puzzle', () async {
    final (:container, :controller) = await load();
    expect(controller.play(const Point(0, 3))?.reason, IllegalMoveReason.occupied);
    expect(container.read(puzzleProvider(1)).value!.status, PuzzleStatus.solving);
  });
}
