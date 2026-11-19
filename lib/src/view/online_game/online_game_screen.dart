import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/constants.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/scoring.dart';
import 'package:tengen/src/model/go/sgf.dart';
import 'package:tengen/src/model/ogs/game_data.dart';
import 'package:tengen/src/model/ogs/ogs_socket_provider.dart';
import 'package:tengen/src/model/online_game/online_game_controller.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/network/socket.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/user/player_screen.dart';
import 'package:tengen/src/widgets/game_layout.dart';
import 'package:tengen/src/widgets/goban.dart';
import 'package:tengen/src/widgets/player_bar.dart';

/// Plays or watches a game on online-go.com.
class OnlineGameScreen extends ConsumerWidget {
  const OnlineGameScreen({required this.gameId, super.key});

  final int gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = onlineGameProvider(gameId);
    final async = ref.watch(provider);
    final connected = ref.watch(socketStatusProvider).value == SocketStatus.connected;

    ref.listen(provider.select((s) => s.value?.error), (_, error) {
      if (error != null) {
        showSnack(context, error);
        ref.read(provider.notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(switch (async) {
          AsyncData(:final value) => value.data.name.isEmpty ? 'Game $gameId' : value.data.name,
          _ => 'Game $gameId',
        }),
        actions: [
          if (!connected)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Tooltip(message: 'Reconnecting…', child: Icon(Icons.cloud_off)),
            ),
          if (async.value case final s?)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'sgf':
                    Clipboard.setData(
                      ClipboardData(
                        text: toSgf(
                          s.game,
                          blackName: s.data.black.username,
                          whiteName: s.data.white.username,
                          result: s.data.outcome,
                        ),
                      ),
                    );
                    showSnack(context, 'SGF copied to the clipboard');
                  case 'link':
                    Clipboard.setData(ClipboardData(text: 'https://$kOgsHost/game/$gameId'));
                    showSnack(context, 'Link copied to the clipboard');
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'sgf', child: Text('Copy SGF')),
                PopupMenuItem(value: 'link', child: Text('Copy game link')),
              ],
            ),
        ],
      ),
      body: switch (async) {
        AsyncData(:final value) => _OnlineGameBody(gameId: gameId, state: value),
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
  const _OnlineGameBody({required this.gameId, required this.state});

  final int gameId;
  final OnlineGameState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(onlineGameProvider(gameId).notifier);
    final socket = ref.watch(ogsSocketProvider);
    final prefs = ref.watch(preferencesProvider);
    final data = state.data;
    final game = state.game;
    final phase = state.phase;
    final bottomColor = state.myColor ?? StoneColor.black;
    final removal = phase == GamePhase.stoneRemoval;
    final finished = phase == GamePhase.finished;
    final score = removal || (finished && data.removed.isNotEmpty)
        ? scoreGame(game, data.removed)
        : null;

    Widget bar(StoneColor color) {
      final player = data.player(color);
      final clock = data.clock;
      return PlayerBar(
        color: color,
        name: player.displayName,
        subtitle: color == StoneColor.white ? 'komi ${data.komi}' : null,
        captures: game.position.capturesOf(color),
        active: phase == GamePhase.play && game.toMove == color,
        onTapName: player.id > 0
            ? () => pushFullScreen<void>(context, PlayerScreen(playerId: player.id))
            : null,
        clock: clock != null && phase == GamePhase.play
            ? OgsClockDisplay(clock: clock, color: color, serverNow: () => socket.serverNow)
            : null,
      );
    }

    Widget? banner;
    if (state.undoRequestedAt != null && state.isPlayer) {
      banner = GameBanner(
        title: 'Your opponent asks to undo their last move',
        actions: [FilledButton(onPressed: controller.acceptUndo, child: const Text('Accept'))],
      );
    } else if (removal) {
      banner = GameBanner(
        title: 'Stone removal${score != null ? ': ${score.resultString} (estimate)' : ''}',
        message: state.isPlayer
            ? 'Tap the dead groups, then accept. Both players must accept the same stones.'
            : 'The players are marking the dead stones.',
        actions: [
          if (state.isPlayer) ...[
            FilledButton(onPressed: controller.acceptRemoved, child: const Text('Accept')),
            OutlinedButton(onPressed: controller.rejectRemoved, child: const Text('Resume game')),
          ],
        ],
      );
    } else if (finished) {
      final winner = data.winner;
      banner = GameBanner(
        title: winner == null
            ? 'Game over'
            : '${data.player(winner).username} wins${_outcomeSuffix(data.outcome)}',
      );
    } else if (game.position.lastMove?.isPass ?? false) {
      banner = GameBanner(title: '${data.player(game.position.lastMove!.color).username} passed');
    }

    final canAct = state.isPlayer && phase == GamePhase.play;
    return GameLayout(
      topPlayer: bar(bottomColor.opposite),
      bottomPlayer: bar(bottomColor),
      banner: banner,
      board: Goban(
        board: game.board,
        theme: prefs.boardTheme,
        showCoordinates: prefs.showCoordinates,
        confirmMoves: prefs.confirmMoves,
        lastMove: game.position.lastMove?.point,
        toPlay: state.isMyTurn ? state.myColor : (state.pendingMove != null ? state.myColor : null),
        pendingMove: state.pendingMove,
        onPlay: state.isMyTurn
            ? (p) {
                final error = controller.play(p);
                if (error != null) showSnack(context, error.message);
              }
            : null,
        onTapStone: removal && state.isPlayer ? controller.toggleRemoved : null,
        deadStones: data.removed,
        territory: score == null
            ? null
            : GobanTerritory(black: score.blackTerritory, white: score.whiteTerritory),
      ),
      actions: [
        if (canAct) ...[
          GameAction(
            icon: Icons.front_hand_outlined,
            label: 'Pass',
            onPressed: state.isMyTurn
                ? () async {
                    if (await confirm(context, title: 'Pass?', confirmLabel: 'Pass')) {
                      controller.pass();
                    }
                  }
                : null,
          ),
          GameAction(
            icon: Icons.undo,
            label: 'Undo',
            onPressed: !state.isMyTurn && game.moveCount > 0
                ? () {
                    controller.requestUndo();
                    showSnack(context, 'Undo requested');
                  }
                : null,
          ),
          GameAction(
            icon: Icons.flag_outlined,
            label: 'Resign',
            onPressed: () async {
              if (await confirm(context, title: 'Resign this game?', confirmLabel: 'Resign')) {
                controller.resign();
              }
            },
          ),
        ] else
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '${data.width}×${data.height} · ${data.ruleset.label}'
              '${data.handicap > 1 ? ' · H${data.handicap}' : ''}'
              '${data.timeControl != null ? ' · ${data.timeControl!.description}' : ''}'
              ' · move ${game.moveCount}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  static String _outcomeSuffix(String? outcome) {
    if (outcome == null || outcome.isEmpty) return '';
    final points = double.tryParse(outcome.split(' ').first);
    if (points != null) return ' by $outcome';
    return ' by ${outcome.toLowerCase()}';
  }
}
