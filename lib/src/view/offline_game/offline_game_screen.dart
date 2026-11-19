import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/result.dart';
import 'package:tengen/src/model/go/sgf.dart';
import 'package:tengen/src/model/offline_game/offline_game_controller.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/analysis/analysis_screen.dart';
import 'package:tengen/src/widgets/game_layout.dart';
import 'package:tengen/src/widgets/goban.dart';
import 'package:tengen/src/widgets/move_list.dart';
import 'package:tengen/src/widgets/player_bar.dart';
import 'package:tengen/src/widgets/result_dialog.dart';

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

  void _openAnalysis(OfflineGameState s) => pushFullScreen<void>(
    context,
    AnalysisScreen(
      game: s.game,
      blackName: _name(StoneColor.black),
      whiteName: _name(StoneColor.white),
    ),
  );

  /// Announces the result, when the game ends and from the info button afterwards.
  void _showResult() {
    final provider = offlineGameProvider(setup);
    final s = ref.read(provider);
    final result = describeResult(outcome: s.result, winner: null);
    final bot = setup.botColor;
    final won = bot != null && s.result != null && !s.result!.startsWith(bot.code);
    showResultDialog(
      context,
      result: GameResultText(
        result.short,
        bot == null
            ? result.description
            : '${won ? 'You won! ' : 'The computer won. '}${result.description}',
      ),
      actions: [
        (
          label: 'New game',
          primary: true,
          onPressed: () {
            setState(() => _reviewPly = null);
            ref.read(provider.notifier).restart();
          },
        ),
        (label: 'Analysis board', primary: false, onPressed: () => _openAnalysis(s)),
      ],
    );
  }

  void _showPly(int ply, int moveCount) =>
      setState(() => _reviewPly = ply >= moveCount ? null : ply.clamp(0, moveCount));

  @override
  Widget build(BuildContext context) {
    final provider = offlineGameProvider(setup);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final prefs = ref.watch(preferencesProvider);
    ref.listen(provider.select((s) => s.phase), (previous, phase) {
      if (phase == OfflinePhase.scoring && previous == OfflinePhase.playing) {
        showSnack(context, 'Both passed: tap the dead stones, then Accept.');
      }
      if (previous != OfflinePhase.finished && phase == OfflinePhase.finished) _showResult();
    });

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
      note: live && game.position.lastMove?.isPass == true && game.position.lastMove!.color == color
          ? 'Passed'
          : null,
    );

    // The phase is told in the title, not in a banner, so that the board keeps its size.
    final String subtitle;
    if (scoring && score != null) {
      subtitle =
          'Counting · ${score.resultString} '
          '(B ${_points(score.black.total)} · W ${_points(score.white.total)})';
    } else if (finished) {
      subtitle = 'Game over · ${state.result}';
    } else {
      subtitle =
          '${setup.size}×${setup.size} · ${setup.ruleset.label}'
          '${setup.handicap > 1 ? ' · ${setup.handicap} handicap' : ''}';
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
              leading: const Icon(Icons.biotech_outlined),
              title: const Text('Analysis board'),
              onTap: () {
                Navigator.pop(sheetContext);
                _openAnalysis(state);
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
          subtitle: subtitle,
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
          if (scoring) ...[
            GameTextAction(
              label: 'Resume',
              icon: Icons.play_arrow_outlined,
              onPressed: controller.resumePlay,
            ),
            GameTextAction(
              label: 'Accept',
              icon: Icons.check,
              primary: true,
              onPressed: controller.acceptScore,
            ),
          ] else ...[
            if (finished)
              GameAction(icon: Icons.info_outline, tooltip: 'Result', onPressed: _showResult)
            else ...[
              GameAction(
                icon: Icons.undo,
                tooltip: 'Undo',
                onPressed: live && game.moveCount > 0 && !state.botThinking
                    ? controller.undo
                    : null,
              ),
              GameAction(
                icon: Icons.front_hand_outlined,
                tooltip: 'Pass',
                onPressed: live && state.canPlay ? controller.pass : null,
              ),
            ],
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
        ],
      ),
    );
  }
}

String _points(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
