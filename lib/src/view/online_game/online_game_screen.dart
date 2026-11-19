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
import 'package:tengen/src/view/online_game/game_chat_sheet.dart';
import 'package:tengen/src/view/user/player_screen.dart';
import 'package:tengen/src/widgets/game_layout.dart';
import 'package:tengen/src/widgets/goban.dart';
import 'package:tengen/src/widgets/move_list.dart';
import 'package:tengen/src/widgets/player_bar.dart';

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

  int get gameId => widget.gameId;

  void _showPly(int ply, int moveCount) =>
      setState(() => _reviewPly = ply >= moveCount ? null : ply.clamp(0, moveCount));

  @override
  Widget build(BuildContext context) {
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
        title: switch (async) {
          AsyncData(:final value) => GameTitle(
            icon: _speedIcon(value.data.timeControl?.speed),
            title: [
              if (value.data.timeControl?.speed case final speed?)
                speed[0].toUpperCase() + speed.substring(1),
              if (value.data.timeControl case final tc? when tc.system != 'none') tc.description,
            ].join(' · ').ifEmpty(value.data.name.isEmpty ? 'Game $gameId' : value.data.name),
            subtitle:
                '${value.data.width}×${value.data.height} · ${value.data.ruleset.label} · '
                '${value.data.ranked ? 'Ranked' : 'Unranked'}'
                '${value.data.handicap > 1 ? ' · ${value.data.handicap} handicap' : ''}',
          ),
          _ => Text('Game $gameId'),
        },
        actions: [
          if (!connected)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Tooltip(message: 'Reconnecting…', child: Icon(Icons.cloud_off)),
            ),
        ],
      ),
      body: switch (async) {
        AsyncData(:final value) => _OnlineGameBody(
          gameId: gameId,
          state: value,
          ply: (_reviewPly ?? value.game.moveCount).clamp(0, value.game.moveCount),
          onShowPly: (p) => _showPly(p, value.game.moveCount),
          unreadChat: value.chat.length - (_seenChat ??= value.chat.length),
          onOpenChat: () async {
            await showGameChat(context, gameId);
            if (mounted) {
              setState(() => _seenChat = ref.read(onlineGameProvider(gameId)).value?.chat.length);
            }
          },
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
    required this.unreadChat,
    required this.onOpenChat,
  });

  final int gameId;
  final OnlineGameState state;

  /// The number of moves shown on the board.
  final int ply;
  final ValueChanged<int> onShowPly;
  final int unreadChat;
  final VoidCallback onOpenChat;

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

    Widget bar(StoneColor color) {
      final player = data.player(color);
      final clock = data.clock;
      return PlayerBar(
        color: color,
        name: player.username,
        rank: player.rankLabel,
        isBot: player.isBot,
        captures: position.capturesOf(color),
        komi: color == StoneColor.white ? data.komi : null,
        active: phase == GamePhase.play && game.toMove == color,
        onTap: player.id > 0
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
    } else if (live && removal) {
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
    } else if (live && finished) {
      final winner = data.winner;
      banner = GameBanner(
        title: winner == null
            ? 'Game over'
            : '${data.player(winner).username} wins${_outcomeSuffix(data.outcome)}',
      );
    } else if (live && (game.position.lastMove?.isPass ?? false)) {
      banner = GameBanner(title: '${data.player(game.position.lastMove!.color).username} passed');
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

    return GameLayout(
      moveList: MoveList(
        moves: game.moves,
        boardHeight: game.height,
        selected: ply,
        onSelect: onShowPly,
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
      actions: [
        GameAction(icon: Icons.menu, tooltip: 'Menu', onPressed: showMenu),
        GameAction(
          icon: Icons.chat_bubble_outline,
          tooltip: 'Chat',
          badge: unreadChat,
          onPressed: onOpenChat,
        ),
        if (canAct) ...[
          GameAction(
            icon: Icons.front_hand_outlined,
            tooltip: 'Pass',
            onPressed: live && state.isMyTurn
                ? () async {
                    if (await confirm(context, title: 'Pass?', confirmLabel: 'Pass')) {
                      controller.pass();
                    }
                  }
                : null,
          ),
          GameAction(
            icon: Icons.undo,
            tooltip: 'Request undo',
            onPressed: !state.isMyTurn && game.moveCount > 0
                ? () {
                    controller.requestUndo();
                    showSnack(context, 'Undo requested');
                  }
                : null,
          ),
        ],
        GameAction(
          icon: Icons.chevron_left,
          tooltip: 'Previous move',
          large: true,
          onPressed: ply > 0 ? () => onShowPly(ply - 1) : null,
        ),
        GameAction(
          icon: Icons.chevron_right,
          tooltip: 'Next move',
          large: true,
          onPressed: live ? null : () => onShowPly(ply + 1),
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

IconData _speedIcon(String? speed) => switch (speed) {
  'blitz' => Icons.bolt,
  'rapid' => Icons.timer_outlined,
  'live' => Icons.schedule,
  'correspondence' => Icons.mail_outline,
  _ => Icons.grid_on,
};

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
