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
import 'package:tengen/src/widgets/move_list.dart';
import 'package:tengen/src/widgets/player_bar.dart';

/// A game played on the device, against the computer or pass and play.
class OfflineGameScreen extends ConsumerStatefulWidget {
  const OfflineGameScreen({required this.setup, super.key});

  final OfflineGameSetup setup;

  @override
  ConsumerState<OfflineGameScreen> createState() => _OfflineGameScreenState();
}

class _OfflineGameScreenState extends ConsumerState<OfflineGameScreen> {
  /// The number of moves shown on the board when looking at an earlier position; null follows
  /// the game.
  int? _reviewPly;

  OfflineGameSetup get setup => widget.setup;

  String _name(StoneColor color) {
    if (setup.opponent == OfflineOpponent.human) {
      return color == StoneColor.black ? 'Black' : 'White';
    }
    return color == setup.botColor ? 'Computer' : 'You';
  }

  void _showPly(int ply, int moveCount) =>
      setState(() => _reviewPly = ply >= moveCount ? null : ply.clamp(0, moveCount));

  @override
  Widget build(BuildContext context) {
    final provider = offlineGameProvider(setup);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final prefs = ref.watch(preferencesProvider);
    final game = state.game;
    final ply = (_reviewPly ?? game.moveCount).clamp(0, game.moveCount);
    final live = ply == game.moveCount;
    final position = game.positions[ply];
    final scoring = state.phase == OfflinePhase.scoring;
    final finished = state.phase == OfflinePhase.finished;
    final score = live && (scoring || (finished && state.result?.endsWith('R') == false))
        ? state.score
        : null;

    // Against the computer, the user is at the bottom; in pass and play black is.
    final bottomColor = setup.opponent == OfflineOpponent.bot ? setup.humanColor : StoneColor.black;

    Widget bar(StoneColor color) => PlayerBar(
      color: color,
      name: _name(color),
      isBot: color == setup.botColor,
      captures: position.capturesOf(color),
      komi: color == StoneColor.white ? game.komi : null,
      active: live && state.phase == OfflinePhase.playing && game.toMove == color,
      thinking: color == setup.botColor && state.botThinking,
    );

    // No banner while looking at an earlier position.
    Widget? banner;
    if (live && scoring && score != null) {
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
    } else if (live && finished) {
      banner = GameBanner(
        title: 'Game over: ${state.result}',
        message: score == null
            ? null
            : 'Black ${score.black.total} · White ${score.white.total} '
                  '(${game.ruleset.areaScoring ? 'area' : 'territory'} scoring)',
        actions: [FilledButton(onPressed: controller.restart, child: const Text('New game'))],
      );
    } else if (live && (game.position.lastMove?.isPass ?? false)) {
      banner = GameBanner(
        title: '${_name(game.position.lastMove!.color)} passed',
        message: 'Pass too to end the game and count.',
      );
    }

    void copySgf() {
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
    }

    Future<void> showMenu() => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.phase == OfflinePhase.playing)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Resign'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  if (await confirm(context, title: 'Resign?', confirmLabel: 'Resign')) {
                    controller.resign();
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('New game'),
              onTap: () async {
                Navigator.pop(sheetContext);
                if (finished ||
                    game.moveCount == 0 ||
                    await confirm(context, title: 'Start a new game?', confirmLabel: 'New game')) {
                  setState(() => _reviewPly = null);
                  controller.restart();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: const Text('Copy SGF'),
              onTap: () {
                Navigator.pop(sheetContext);
                copySgf();
              },
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: GameTitle(
          icon: setup.botColor != null ? Icons.smart_toy_outlined : Icons.people_outline,
          title: setup.botColor != null ? 'vs Computer' : 'Pass and play',
          subtitle:
              '${setup.size}×${setup.size} · ${setup.ruleset.label}'
              '${setup.handicap > 1 ? ' · ${setup.handicap} handicap' : ''}',
        ),
      ),
      body: GameLayout(
        moveList: MoveList(
          moves: game.moves,
          boardHeight: game.height,
          selected: ply,
          onSelect: (p) => _showPly(p, game.moveCount),
        ),
        topPlayer: bar(bottomColor.opposite),
        bottomPlayer: bar(bottomColor),
        banner: banner,
        board: Goban(
          board: position.board,
          theme: prefs.boardTheme,
          showCoordinates: prefs.showCoordinates,
          confirmMoves: prefs.confirmMoves,
          lastMove: position.lastMove?.point,
          toPlay: live && state.canPlay ? game.toMove : null,
          onPlay: (p) {
            final error = controller.play(p);
            if (error != null) showSnack(context, error.message);
          },
          onTapStone: live && scoring ? controller.toggleDead : null,
          deadStones: live ? state.deadStones : const {},
          territory: score == null
              ? null
              : GobanTerritory(black: score.blackTerritory, white: score.whiteTerritory),
        ),
        actions: [
          GameAction(icon: Icons.menu, tooltip: 'Menu', onPressed: showMenu),
          GameAction(
            icon: Icons.undo,
            tooltip: 'Undo',
            onPressed: live && game.moveCount > 0 && !state.botThinking ? controller.undo : null,
          ),
          GameAction(
            icon: Icons.front_hand_outlined,
            tooltip: 'Pass',
            onPressed: live && state.canPlay ? controller.pass : null,
          ),
          GameAction(
            icon: Icons.chevron_left,
            tooltip: 'Previous move',
            large: true,
            onPressed: ply > 0 ? () => _showPly(ply - 1, game.moveCount) : null,
          ),
          GameAction(
            icon: Icons.chevron_right,
            tooltip: 'Next move',
            large: true,
            onPressed: live ? null : () => _showPly(ply + 1, game.moveCount),
          ),
        ],
      ),
    );
  }
}
