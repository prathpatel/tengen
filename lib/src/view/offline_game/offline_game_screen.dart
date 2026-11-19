import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/sgf.dart';
import 'package:tengen/src/model/offline_game/offline_game_controller.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/widgets/game_layout.dart';
import 'package:tengen/src/widgets/goban.dart';
import 'package:tengen/src/widgets/player_bar.dart';

/// A game played on the device, against the computer or pass and play.
class OfflineGameScreen extends ConsumerWidget {
  const OfflineGameScreen({required this.setup, super.key});

  final OfflineGameSetup setup;

  String _name(StoneColor color) {
    if (setup.opponent == OfflineOpponent.human) {
      return color == StoneColor.black ? 'Black' : 'White';
    }
    return color == setup.botColor ? 'Computer' : 'You';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = offlineGameProvider(setup);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final prefs = ref.watch(preferencesProvider);
    final game = state.game;
    final scoring = state.phase == OfflinePhase.scoring;
    final finished = state.phase == OfflinePhase.finished;
    final score = scoring || (finished && state.result?.endsWith('R') == false)
        ? state.score
        : null;

    // Against the computer, the user is at the bottom; in pass and play black is.
    final bottomColor = setup.opponent == OfflineOpponent.bot ? setup.humanColor : StoneColor.black;

    Widget bar(StoneColor color) => PlayerBar(
      color: color,
      name: _name(color),
      subtitle: color == StoneColor.white ? 'komi ${game.komi}' : null,
      captures: game.position.capturesOf(color),
      active: state.phase == OfflinePhase.playing && game.toMove == color,
      clock: color == setup.botColor && state.botThinking
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : null,
    );

    Widget? banner;
    if (scoring && score != null) {
      banner = GameBanner(
        title: 'Counting: ${score.resultString}',
        message:
            'Tap the dead stones to remove them. Black ${score.black.total} · '
            'White ${score.white.total}',
        actions: [
          FilledButton(onPressed: controller.acceptScore, child: const Text('Accept')),
          OutlinedButton(onPressed: controller.resumePlay, child: const Text('Resume play')),
        ],
      );
    } else if (finished) {
      banner = GameBanner(
        title: 'Game over: ${state.result}',
        message: score == null
            ? null
            : 'Black ${score.black.total} · White ${score.white.total} '
                  '(${game.ruleset.areaScoring ? 'area' : 'territory'} scoring)',
        actions: [FilledButton(onPressed: controller.restart, child: const Text('New game'))],
      );
    } else if (game.position.lastMove?.isPass ?? false) {
      banner = GameBanner(
        title: '${_name(game.position.lastMove!.color)} passed',
        message: 'Pass too to end the game and count.',
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${setup.size}×${setup.size} · ${setup.ruleset.label}'
          '${setup.handicap > 1 ? ' · H${setup.handicap}' : ''}',
        ),
        actions: [
          IconButton(
            tooltip: 'Copy SGF',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () {
              Clipboard.setData(
                ClipboardData(
                  text: toSgf(
                    game,
                    blackName: _name(StoneColor.black),
                    whiteName: _name(StoneColor.white),
                    result: state.result,
                    date: DateTime.now(),
                  ),
                ),
              );
              showSnack(context, 'SGF copied to the clipboard');
            },
          ),
        ],
      ),
      body: GameLayout(
        topPlayer: bar(bottomColor.opposite),
        bottomPlayer: bar(bottomColor),
        banner: banner,
        board: Goban(
          board: game.board,
          theme: prefs.boardTheme,
          showCoordinates: prefs.showCoordinates,
          confirmMoves: prefs.confirmMoves,
          lastMove: game.position.lastMove?.point,
          toPlay: state.canPlay ? game.toMove : null,
          onPlay: (p) {
            final error = controller.play(p);
            if (error != null) showSnack(context, error.message);
          },
          onTapStone: scoring ? controller.toggleDead : null,
          deadStones: state.deadStones,
          territory: score == null
              ? null
              : GobanTerritory(black: score.blackTerritory, white: score.whiteTerritory),
        ),
        actions: [
          GameAction(
            icon: Icons.undo,
            label: 'Undo',
            onPressed: game.moveCount > 0 && !state.botThinking ? controller.undo : null,
          ),
          GameAction(
            icon: Icons.front_hand_outlined,
            label: 'Pass',
            onPressed: state.canPlay ? controller.pass : null,
          ),
          GameAction(
            icon: Icons.flag_outlined,
            label: 'Resign',
            onPressed: state.phase == OfflinePhase.playing
                ? () async {
                    if (await confirm(context, title: 'Resign?', confirmLabel: 'Resign')) {
                      controller.resign();
                    }
                  }
                : null,
          ),
          GameAction(
            icon: Icons.refresh,
            label: 'Restart',
            onPressed: game.moveCount > 0
                ? () async {
                    if (finished ||
                        await confirm(
                          context,
                          title: 'Start a new game?',
                          confirmLabel: 'Restart',
                        )) {
                      controller.restart();
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
