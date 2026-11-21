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
import 'package:tengen/src/widgets/ui.dart';

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

  /// The move list shown under the board, with the move by move controls.
  bool _showMoves = false;

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
    final vsBot = setup.opponent == OfflineOpponent.bot;

    Widget pill(StoneColor color) {
      final captures = position.capturesOf(color);
      final toMove = live && state.phase == OfflinePhase.playing && game.toMove == color;
      return PlayerPill(
        color: color,
        name: _name(color),
        isBot: color == setup.botColor,
        end: color == bottomColor,
        active: toMove,
        thinking: color == setup.botColor && state.botThinking,
        detail: [
          if (toMove && color != setup.botColor && vsBot) 'Your move',
          if (toMove && !vsBot) 'To play',
          '$captures ${captures == 1 ? 'capture' : 'captures'}',
          if (color == StoneColor.white && game.komi != 0) 'komi ${_points(game.komi)}',
        ].join(' · '),
        note:
            live && game.position.lastMove?.isPass == true && game.position.lastMove!.color == color
            ? 'Passed'
            : null,
      );
    }

    final String title;
    if (finished) {
      title = 'Game over · ${state.result}';
    } else {
      title = [
        if (game.moveCount > 0) 'Move ${game.moveCount}',
        if (game.moveCount == 0 && vsBot) 'vs Computer',
        if (game.moveCount == 0 && !vsBot) 'Pass and play',
        '${setup.size}×${setup.size}',
        setup.ruleset.label,
        if (setup.handicap > 1) '${setup.handicap} handicap',
      ].join(' · ');
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

    Future<void> newGame() async {
      if (finished ||
          game.moveCount == 0 ||
          await confirm(context, title: 'Start a new game?', confirmLabel: 'New game')) {
        setState(() {
          _reviewPly = null;
          _showMoves = false;
        });
        controller.restart();
      }
    }

    Future<void> showMenu() => showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: const Text('New game'),
              onTap: () {
                Navigator.pop(sheetContext);
                newGame();
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

    final Widget above;
    final Widget below;
    final Widget actions;
    if (scoring && score != null) {
      above = const GamePrompt(
        icon: Icons.front_hand_outlined,
        text: 'Both passed. Tap the dead stones, then Accept.',
      );
      final mine = vsBot ? setup.humanColor : null;
      final winner = score.winner;
      below = ScoreCard(
        lines: [
          for (final c in [bottomColor, bottomColor.opposite])
            ScoreLine(
              color: c,
              name: vsBot ? (c == setup.botColor ? 'Bot' : 'You') : _name(c),
              detail: scoreDetail(c == StoneColor.black ? score.black : score.white),
              total: (c == StoneColor.black ? score.black : score.white).total,
            ),
        ],
        verdict: winner == null
            ? 'Jigo'
            : '${mine == null ? _name(winner) : (winner == mine ? 'You' : 'Bot')} '
                  '${mine == null || winner != mine ? 'wins' : 'win'} by ${_points(score.margin)}',
        result: score.resultString,
      );
      actions = GameButtons(
        secondary: FilledButton(
          style: softButtonStyle(context),
          onPressed: controller.resumePlay,
          child: const Text('Resume play'),
        ),
        primary: FilledButton(onPressed: controller.acceptScore, child: const Text('Accept')),
      );
    } else {
      above = pill(bottomColor.opposite);
      below = _showMoves
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: MoveList(
                moves: game.moves,
                boardHeight: game.height,
                selected: ply,
                onSelect: (p) => _showPly(p, game.moveCount),
              ),
            )
          : pill(bottomColor);
      actions = RoundActionBar(
        actions: _showMoves
            ? [
                RoundAction(
                  icon: Icons.chevron_left_rounded,
                  label: 'Previous',
                  onPressed: ply > 0 ? () => _showPly(ply - 1, game.moveCount) : null,
                ),
                RoundAction(
                  icon: Icons.chevron_right_rounded,
                  label: 'Next',
                  onPressed: live ? null : () => _showPly(ply + 1, game.moveCount),
                ),
                RoundAction(
                  icon: Icons.last_page_rounded,
                  label: 'Live',
                  onPressed: live ? null : () => _showPly(game.moveCount, game.moveCount),
                ),
                RoundAction(
                  icon: Icons.history_rounded,
                  label: 'Moves',
                  highlighted: true,
                  onPressed: () => setState(() {
                    _showMoves = false;
                    _reviewPly = null;
                  }),
                ),
              ]
            : finished
            ? [
                RoundAction(
                  icon: Icons.info_outline_rounded,
                  label: 'Result',
                  onPressed: _showResult,
                ),
                RoundAction(
                  icon: Icons.history_rounded,
                  label: 'Moves',
                  onPressed: () => setState(() => _showMoves = true),
                ),
                RoundAction(
                  icon: Icons.biotech_outlined,
                  label: 'Analysis',
                  onPressed: () => _openAnalysis(state),
                ),
                RoundAction(icon: Icons.refresh_rounded, label: 'New game', onPressed: newGame),
              ]
            : [
                RoundAction(
                  icon: Icons.undo_rounded,
                  label: 'Undo',
                  onPressed: live && game.moveCount > 0 && !state.botThinking
                      ? controller.undo
                      : null,
                ),
                RoundAction(
                  icon: Icons.arrow_forward_rounded,
                  label: 'Pass',
                  onPressed: live && state.canPlay ? controller.pass : null,
                ),
                RoundAction(
                  icon: Icons.history_rounded,
                  label: 'Moves',
                  onPressed: () => setState(() => _showMoves = true),
                ),
                RoundAction(
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
              ],
      );
    }

    return Scaffold(
      // A keyboard opened by a sheet over the game (the chat) must not squeeze the board.
      resizeToAvoidBottomInset: false,
      appBar: TopBar(
        title: title,
        muted: true,
        actions: [
          CircleIconButton(icon: Icons.more_horiz_rounded, tooltip: 'Menu', onPressed: showMenu),
        ],
      ),
      body: GameLayout(
        above: above,
        below: below,
        board: Goban(
          board: position.board,
          theme: prefs.boardTheme,
          blackStones: prefs.blackStones,
          whiteStones: prefs.whiteStones,
          showCoordinates: prefs.showCoordinates,
          confirmMoves: prefs.confirmMoves,
          sound: prefs.stoneSound,
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
        actions: actions,
      ),
    );
  }
}

String _points(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
