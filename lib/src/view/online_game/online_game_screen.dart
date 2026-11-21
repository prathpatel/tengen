import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/constants.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/result.dart';
import 'package:tengen/src/model/go/scoring.dart';
import 'package:tengen/src/model/go/sgf.dart';
import 'package:tengen/src/model/ogs/game_data.dart';
import 'package:tengen/src/model/ogs/ogs_socket_provider.dart';
import 'package:tengen/src/model/online_game/automatch_controller.dart';
import 'package:tengen/src/model/online_game/online_game_controller.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/network/socket.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/analysis/analysis_screen.dart';
import 'package:tengen/src/view/online_game/game_chat_sheet.dart';
import 'package:tengen/src/view/user/player_screen.dart';
import 'package:tengen/src/widgets/game_layout.dart';
import 'package:tengen/src/widgets/goban.dart';
import 'package:tengen/src/widgets/move_list.dart';
import 'package:tengen/src/widgets/player_bar.dart';
import 'package:tengen/src/widgets/result_dialog.dart';
import 'package:tengen/src/widgets/ui.dart';

/// Plays or watches a game on online-go.com.
class OnlineGameScreen extends ConsumerStatefulWidget {
  const OnlineGameScreen({required this.gameId, super.key});

  final int gameId;

  @override
  ConsumerState<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends ConsumerState<OnlineGameScreen> {
  /// The number of moves shown when looking at an earlier position; null follows the game.
  int? _reviewPly;

  /// Chat messages already seen; the history present when the game opens counts as seen.
  int? _seenChat;

  /// The move list shown under the board.
  bool _showMoves = false;

  int get gameId => widget.gameId;

  void _openAnalysis(OnlineGameState s) => pushFullScreen<void>(
    context,
    AnalysisScreen(
      game: s.game,
      blackName: s.data.black.username,
      whiteName: s.data.white.username,
    ),
  );

  /// Shows the result: when the game ends while it is open, and from the info button.
  void _announceResult() {
    final s = ref.read(onlineGameProvider(gameId)).value;
    if (s == null || !mounted) return;
    final winner = s.data.winner;
    final result = describeResult(outcome: s.data.outcome, winner: winner);
    final tc = s.data.timeControl;
    final again = ref
        .read(automatchSettingsProvider)
        .sameAs(width: s.data.width, height: s.data.height, speed: tc?.speed, system: tc?.system);
    showResultDialog(
      context,
      result: GameResultText(
        result.short,
        winner == null
            ? result.description
            : '${s.myColor == null ? '' : (winner == s.myColor ? 'You won! ' : 'You lost. ')}'
                  '${result.description}',
      ),
      actions: [
        if (s.isPlayer && again != null)
          (
            label: 'New opponent',
            primary: true,
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(automatchProvider.notifier).find(again);
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
    final provider = onlineGameProvider(gameId);
    final async = ref.watch(provider);
    final connected = ref.watch(socketStatusProvider).value == SocketStatus.connected;

    ref.listen(provider.select((s) => s.value?.phase), (previous, phase) {
      if (previous != null && previous != GamePhase.finished && phase == GamePhase.finished) {
        _announceResult();
      }
    });

    ref.listen(provider.select((s) => s.value?.undoRequestedAt), (_, at) {
      final s = ref.read(provider).value;
      if (at != null && s != null && s.isPlayer) {
        showSnackAction(
          context,
          'Your opponent asks to undo their last move',
          action: 'Accept',
          onAction: ref.read(provider.notifier).acceptUndo,
        );
      }
    });

    ref.listen(provider.select((s) => s.value?.stallingEstimate), (_, estimate) {
      final s = ref.read(provider).value;
      if (estimate == null || s == null) return;
      final message =
          'OGS thinks the game is over: ${s.data.player(estimate.winner).username} wins '
          '(${(estimate.winRate * 100).toStringAsFixed(0)}%).';
      if (s.isPlayer) {
        showSnackAction(
          context,
          message,
          action: 'End game',
          onAction: () => ref.read(provider.notifier).preventStalling(estimate.winner),
          duration: const Duration(seconds: 30),
        );
      } else {
        showSnack(context, message);
      }
    });

    ref.listen(provider.select((s) => s.value?.phase), (previous, phase) {
      final s = ref.read(provider).value;
      if (phase == GamePhase.stoneRemoval && previous == GamePhase.play && (s?.isPlayer ?? false)) {
        showSnack(context, 'Tap the dead groups, then Accept. Both players must agree.');
      }
    });

    ref.listen(provider.select((s) => s.value?.game.moveCount), (_, _) {
      final s = ref.read(provider).value;
      final last = s?.game.position.lastMove;
      if (s != null &&
          s.isPlayer &&
          s.phase == GamePhase.play &&
          last != null &&
          last.isPass &&
          last.color != s.myColor) {
        showSnack(
          context,
          '${s.data.player(last.color).username} passed. Pass too if nothing useful is left.',
        );
      }
    });

    ref.listen(provider.select((s) => s.value?.error), (_, error) {
      if (error != null) {
        showSnack(context, error);
        ref.read(provider.notifier).clearError();
      }
    });

    final value = async.value;
    return Scaffold(
      // A keyboard opened by a sheet over the game (the chat) must not squeeze the board.
      resizeToAvoidBottomInset: false,
      appBar: TopBar(
        title: value == null ? 'Game $gameId' : _title(value),
        subtitle: !connected ? 'Reconnecting…' : (value == null ? null : _subtitle(value)),
        muted: true,
        actions: [
          if (value != null) ...[
            CircleIconButton(
              icon: Icons.chat_bubble_outline_rounded,
              tooltip: 'Chat',
              badge: value.chat.length - (_seenChat ??= value.chat.length),
              onPressed: () async {
                await showGameChat(context, gameId);
                if (mounted) {
                  setState(
                    () => _seenChat = ref.read(onlineGameProvider(gameId)).value?.chat.length,
                  );
                }
              },
            ),
          ],
        ],
      ),
      body: switch (async) {
        AsyncData(:final value) => _OnlineGameBody(
          gameId: gameId,
          state: value,
          ply: (_reviewPly ?? value.game.moveCount).clamp(0, value.game.moveCount),
          onShowPly: (p) => _showPly(p, value.game.moveCount),
          onOpenAnalysis: () => _openAnalysis(value),
          onShowResult: _announceResult,
          showMoves: _showMoves,
          onShowMoves: (show) => setState(() {
            _showMoves = show;
            if (!show) _reviewPly = null;
          }),
        ),
        AsyncError(:final error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load the game: $error', textAlign: TextAlign.center),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _OnlineGameBody extends ConsumerWidget {
  const _OnlineGameBody({
    required this.gameId,
    required this.state,
    required this.ply,
    required this.onShowPly,
    required this.onOpenAnalysis,
    required this.onShowResult,
    required this.showMoves,
    required this.onShowMoves,
  });

  final int gameId;
  final OnlineGameState state;

  /// The number of moves shown on the board.
  final int ply;
  final ValueChanged<int> onShowPly;
  final VoidCallback onOpenAnalysis;

  /// The move list under the board, with the move by move controls.
  final bool showMoves;
  final ValueChanged<bool> onShowMoves;

  /// Shows the result dialog again, once the game is over.
  final VoidCallback onShowResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(onlineGameProvider(gameId).notifier);
    final socket = ref.watch(ogsSocketProvider);
    final prefs = ref.watch(preferencesProvider);
    final data = state.data;
    final game = state.game;
    final phase = state.phase;
    final live = ply == game.moveCount;
    final position = game.positions[ply];
    final bottomColor = state.myColor ?? StoneColor.black;
    final removal = phase == GamePhase.stoneRemoval;
    final finished = phase == GamePhase.finished;
    final score = live && (removal || (finished && data.removed.isNotEmpty))
        ? scoreGame(game, data.removed)
        : null;

    Widget pill(StoneColor color) {
      final player = data.player(color);
      final clock = data.clock;
      final captures = position.capturesOf(color);
      final toMove = phase == GamePhase.play && game.toMove == color;
      final mine = color == state.myColor;
      return PlayerPill(
        color: color,
        name: mine ? 'You' : player.username,
        rank: player.rankLabel,
        isBot: player.isBot,
        end: color == bottomColor,
        active: toMove,
        detail: [
          if (toMove && mine) 'Your move',
          '$captures ${captures == 1 ? 'capture' : 'captures'}',
          if (color == StoneColor.white && data.komi != 0) 'komi ${_points(data.komi)}',
        ].join(' · '),
        onTap: player.id > 0
            ? () => pushFullScreen<void>(context, PlayerScreen(playerId: player.id))
            : null,
        clock: clock != null && phase == GamePhase.play
            ? OgsClockDisplay(clock: clock, color: color, serverNow: () => socket.serverNow)
            : null,
        note:
            live && game.position.lastMove?.isPass == true && game.position.lastMove!.color == color
            ? 'Passed'
            : null,
      );
    }

    final canAct = state.isPlayer && phase == GamePhase.play;

    Future<void> showMenu() => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(
                '${data.width}×${data.height} · ${data.ruleset.label}'
                '${data.handicap > 1 ? ' · H${data.handicap}' : ''}'
                '${data.ranked ? ' · ranked' : ''}',
              ),
              subtitle: data.timeControl == null ? null : Text(data.timeControl!.description),
            ),
            if (canAct)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Resign'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  if (await confirm(context, title: 'Resign this game?', confirmLabel: 'Resign')) {
                    controller.resign();
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.biotech_outlined),
              title: const Text('Analysis board'),
              onTap: () {
                Navigator.pop(sheetContext);
                onOpenAnalysis();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: const Text('Copy SGF'),
              onTap: () {
                Navigator.pop(sheetContext);
                Clipboard.setData(
                  ClipboardData(
                    text: toSgf(
                      game,
                      blackName: data.black.username,
                      whiteName: data.white.username,
                      result: data.outcome,
                    ),
                  ),
                );
                showSnack(context, 'SGF copied to the clipboard');
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Copy game link'),
              onTap: () {
                Navigator.pop(sheetContext);
                Clipboard.setData(ClipboardData(text: 'https://$kOgsHost/game/$gameId'));
                showSnack(context, 'Link copied to the clipboard');
              },
            ),
          ],
        ),
      ),
    );

    Future<void> resign() async {
      if (await confirm(context, title: 'Resign this game?', confirmLabel: 'Resign')) {
        controller.resign();
      }
    }

    final moves = RoundAction(
      icon: Icons.history_rounded,
      label: 'Moves',
      highlighted: showMoves,
      onPressed: () => onShowMoves(!showMoves),
    );

    final Widget above;
    final Widget below;
    final Widget actions;
    if (removal && live && score != null) {
      above = GamePrompt(
        icon: Icons.front_hand_outlined,
        text: state.isPlayer
            ? 'Both passed. Tap the dead stones, then Accept.'
            : 'The players are marking the dead stones.',
      );
      final winner = score.winner;
      below = ScoreCard(
        lines: [
          for (final c in [bottomColor, bottomColor.opposite])
            ScoreLine(
              color: c,
              name: c == state.myColor ? 'You' : data.player(c).username,
              detail: scoreDetail(c == StoneColor.black ? score.black : score.white),
              total: (c == StoneColor.black ? score.black : score.white).total,
            ),
        ],
        verdict: winner == null
            ? 'Jigo'
            : winner == state.myColor
            ? 'You win by ${_points(score.margin)}'
            : '${data.player(winner).username} wins by ${_points(score.margin)}',
        result: '${score.resultString} · estimate',
      );
      actions = state.isPlayer
          ? GameButtons(
              secondary: FilledButton(
                style: softButtonStyle(context),
                onPressed: controller.rejectRemoved,
                child: const Text('Resume play'),
              ),
              primary: FilledButton(
                onPressed: controller.acceptRemoved,
                child: const Text('Accept'),
              ),
            )
          : RoundActionBar(actions: [moves]);
    } else {
      above = pill(bottomColor.opposite);
      below = showMoves
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: MoveList(
                moves: game.moves,
                boardHeight: game.height,
                selected: ply,
                onSelect: onShowPly,
              ),
            )
          : pill(bottomColor);
      actions = RoundActionBar(
        actions: showMoves
            ? [
                RoundAction(
                  icon: Icons.chevron_left_rounded,
                  label: 'Previous',
                  onPressed: ply > 0 ? () => onShowPly(ply - 1) : null,
                ),
                RoundAction(
                  icon: Icons.chevron_right_rounded,
                  label: 'Next',
                  onPressed: live ? null : () => onShowPly(ply + 1),
                ),
                RoundAction(
                  icon: Icons.last_page_rounded,
                  label: 'Live',
                  onPressed: live ? null : () => onShowPly(game.moveCount),
                ),
                moves,
              ]
            : finished
            ? [
                RoundAction(
                  icon: Icons.info_outline_rounded,
                  label: 'Result',
                  onPressed: onShowResult,
                ),
                moves,
                RoundAction(
                  icon: Icons.biotech_outlined,
                  label: 'Analysis',
                  onPressed: onOpenAnalysis,
                ),
                RoundAction(icon: Icons.more_horiz_rounded, label: 'More', onPressed: showMenu),
              ]
            : canAct
            ? [
                RoundAction(
                  icon: Icons.undo_rounded,
                  label: 'Undo',
                  onPressed: !state.isMyTurn && game.moveCount > 0
                      ? () {
                          controller.requestUndo();
                          showSnack(context, 'Undo requested');
                        }
                      : null,
                ),
                RoundAction(
                  icon: Icons.arrow_forward_rounded,
                  label: 'Pass',
                  onPressed: live && state.isMyTurn
                      ? () async {
                          if (await confirm(context, title: 'Pass?', confirmLabel: 'Pass')) {
                            controller.pass();
                          }
                        }
                      : null,
                ),
                moves,
                RoundAction(icon: Icons.flag_outlined, label: 'Resign', onPressed: resign),
              ]
            : [
                moves,
                RoundAction(
                  icon: Icons.biotech_outlined,
                  label: 'Analysis',
                  onPressed: onOpenAnalysis,
                ),
                RoundAction(icon: Icons.more_horiz_rounded, label: 'More', onPressed: showMenu),
              ],
      );
    }

    return GameLayout(
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
        toPlay: !live
            ? null
            : (state.isMyTurn ? state.myColor : (state.pendingMove != null ? state.myColor : null)),
        pendingMove: live ? state.pendingMove : null,
        onPlay: live && state.isMyTurn
            ? (p) {
                final error = controller.play(p);
                if (error != null) showSnack(context, error.message);
              }
            : null,
        onTapStone: live && removal && state.isPlayer ? controller.toggleRemoved : null,
        deadStones: live ? data.removed : const {},
        territory: score == null
            ? null
            : GobanTerritory(black: score.blackTerritory, white: score.whiteTerritory),
      ),
      actions: actions,
    );
  }
}

String _points(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// `Move 28 · 19×19 · Rapid`
String _title(OnlineGameState s) {
  final data = s.data;
  final speed = data.timeControl?.speed;
  return [
    if (s.game.moveCount > 0) 'Move ${s.game.moveCount}',
    '${data.width}×${data.height}',
    if (speed != null && speed.isNotEmpty) speed[0].toUpperCase() + speed.substring(1),
  ].join(' · ');
}

/// The title's second line: the game settings, or the phase when it matters.
String _subtitle(OnlineGameState s) {
  final data = s.data;
  switch (s.phase) {
    case GamePhase.stoneRemoval:
      final score = scoreGame(s.game, data.removed);
      return 'Stone removal · ${score.resultString} (estimate)';
    case GamePhase.finished:
      final winner = data.winner;
      final result = describeResult(outcome: data.outcome, winner: winner);
      return winner == null
          ? result.short
          : '${result.short} · ${data.player(winner).username} wins';
    case GamePhase.play:
      return [
        data.ruleset.label,
        if (data.timeControl case final tc? when tc.system != 'none') tc.description,
        if (data.ranked) 'Ranked',
        if (data.handicap > 1) '${data.handicap} handicap',
      ].join(' · ');
  }
}
