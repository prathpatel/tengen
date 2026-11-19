import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/bot.dart';
import 'package:tengen/src/model/go/game.dart';
import 'package:tengen/src/model/offline_game/offline_game_controller.dart';

import '../../fakes.dart';

void main() {
  Future<OfflineGameController> start(OfflineGameSetup setup) async {
    final (:container, sockets: _) = await makeContainer();
    addTearDown(container.dispose);
    final sub = container.listen(offlineGameProvider(setup), (_, _) {});
    addTearDown(sub.close);
    final OfflineGameController controller = container.read(offlineGameProvider(setup).notifier);
    return controller;
  }

  test('pass and play: moves alternate, two passes start counting', () async {
    const setup = OfflineGameSetup(opponent: OfflineOpponent.human);
    final controller = await start(setup);
    expect(controller.play(const Point(4, 4)), isNull);
    expect(controller.state.game.toMove, StoneColor.white);
    controller
      ..pass()
      ..pass();
    expect(controller.state.phase, OfflinePhase.scoring);
    controller.toggleDead(const Point(4, 4));
    expect(controller.state.deadStones, {const Point(4, 4)});
    controller.acceptScore();
    expect(controller.state.phase, OfflinePhase.finished);
    // Black's only stone is dead, and no white stone borders the board: komi + 1 prisoner.
    expect(controller.state.result, 'W+7.5');
  });

  test('the bot replies, and undo takes back both moves', () async {
    const setup = OfflineGameSetup();
    final controller = await start(setup);
    expect(controller.play(const Point(2, 2)), isNull);
    expect(controller.state.botThinking, isTrue);
    expect(controller.play(const Point(3, 3))?.reason, IllegalMoveReason.wrongTurn);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(controller.state.game.moveCount, 2);
    expect(controller.state.game.toMove, StoneColor.black);
    expect(controller.state.botThinking, isFalse);
    controller.undo();
    expect(controller.state.game.moveCount, 0);
  });

  test('the bot opens when the user plays white', () async {
    const setup = OfflineGameSetup(humanColor: StoneColor.white);
    final controller = await start(setup);
    expect(controller.state.botThinking, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(controller.state.game.board.count(StoneColor.black), 1);
  });

  test('resigning against the bot gives the bot the win', () async {
    final controller = await start(const OfflineGameSetup());
    controller.resign();
    expect(controller.state.result, 'W+R');
  });

  test('the bot finishes a whole game against itself with only legal moves', () {
    final bot = SimpleBot(random: math.Random(1));
    var game = GoGame.create(width: 9);
    var moves = 0;
    while (!game.bothPassed && moves < 300) {
      game = game.play(bot.chooseMove(game));
      moves++;
    }
    expect(game.bothPassed, isTrue, reason: 'the bot should pass when nothing is left');
    expect(
      game.board.count(StoneColor.black) + game.board.count(StoneColor.white),
      greaterThan(20),
    );
  });
}
