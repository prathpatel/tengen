import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:tengen/src/model/auth/auth_controller.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/coordinates.dart';
import 'package:tengen/src/model/go/game.dart';
import 'package:tengen/src/model/ogs/clock.dart';
import 'package:tengen/src/model/ogs/game_data.dart';
import 'package:tengen/src/model/ogs/ogs_socket_provider.dart';
import 'package:tengen/src/network/socket.dart';
import 'package:tengen/src/utils/json.dart';

@immutable
class OnlineGameState {
  const OnlineGameState({
    required this.data,
    required this.game,
    this.myColor,
    this.pendingMove,
    this.undoRequestedAt,
    this.error,
  });

  final OgsGameData data;
  final GoGame game;

  /// The color of the signed in user, null when watching.
  final StoneColor? myColor;

  /// A move sent to the server and not yet confirmed.
  final Point? pendingMove;

  /// The move number at which the opponent asked for an undo, if pending.
  final int? undoRequestedAt;

  /// The last error message from the server.
  final String? error;

  bool get isPlayer => myColor != null;
  GamePhase get phase => data.phase;
  bool get isMyTurn =>
      myColor != null && phase == GamePhase.play && game.toMove == myColor && pendingMove == null;

  OnlineGameState copyWith({
    OgsGameData? data,
    GoGame? game,
    Point? Function()? pendingMove,
    int? Function()? undoRequestedAt,
    String? Function()? error,
  }) => OnlineGameState(
    data: data ?? this.data,
    game: game ?? this.game,
    myColor: myColor,
    pendingMove: pendingMove != null ? pendingMove() : this.pendingMove,
    undoRequestedAt: undoRequestedAt != null ? undoRequestedAt() : this.undoRequestedAt,
    error: error != null ? error() : this.error,
  );
}

/// Plays or watches an OGS game through the realtime API.
///
/// Sends `game/connect` and builds the state from the `gamedata` event, then applies the move,
/// clock, phase and stone removal events. Connects again after a socket reconnection, the server
/// then sends the full game data again.
final onlineGameProvider = AsyncNotifierProvider.autoDispose
    .family<OnlineGameController, OnlineGameState, int>(OnlineGameController.new);

class OnlineGameController extends AsyncNotifier<OnlineGameState> {
  OnlineGameController(this.gameId);

  final int gameId;

  OgsSocket get _socket => ref.read(ogsSocketProvider);

  int? _userId;

  @override
  Future<OnlineGameState> build() async {
    _userId = (await ref.watch(authProvider.future)).user.id;
    final socket = ref.watch(ogsSocketProvider);
    final prefix = 'game/$gameId/';
    final first = Completer<OnlineGameState>();

    final subscriptions = [
      socket.events.where((e) => e.name.startsWith(prefix)).listen((event) {
        final name = event.name.substring(prefix.length);
        if (name == 'gamedata') {
          final data = OgsGameData.fromJson(asMap(event.data) ?? const {});
          final next = _fromData(data);
          if (!first.isCompleted) {
            first.complete(next);
          } else {
            state = AsyncData(next);
          }
        } else if (state.value case final current?) {
          final next = _apply(current, name, event.data);
          if (next != null) state = AsyncData(next);
        }
      }),
      socket.statusChanges.where((s) => s == SocketStatus.connected).listen((_) => _connect()),
    ];
    ref.onDispose(() {
      for (final s in subscriptions) {
        s.cancel();
      }
      socket.send('game/disconnect', {'game_id': gameId});
    });
    _connect();
    return await first.future;
  }

  void _connect() => _socket.send('game/connect', {'game_id': gameId, 'chat': false});

  OnlineGameState _fromData(OgsGameData data) {
    return OnlineGameState(data: data, game: data.buildGame(), myColor: data.colorOf(_userId));
  }

  /// Applies an event to the current state. Returns null when nothing changed.
  OnlineGameState? _apply(OnlineGameState s, String name, Object? payload) {
    switch (name) {
      case 'move':
        final json = asMap(payload) ?? const {};
        final moveNumber = asInt(json['move_number']);
        final point = decodeOgsArrayMove(json['move']);
        if (moveNumber != null && moveNumber != s.data.moves.length + 1) {
          // Out of sync (missed or duplicated event): ask for the full game again.
          _connect();
          return null;
        }
        return s.copyWith(
          data: s.data.copyWith(moves: [...s.data.moves, point]),
          game: s.game.playMove(GoMove(s.game.toMove, point), validate: false),
          pendingMove: () => null,
          undoRequestedAt: () => null,
        );
      case 'clock':
        final json = asMap(payload);
        if (json == null) return null;
        return s.copyWith(data: s.data.copyWith(clock: OgsClock.fromJson(json)));
      case 'phase':
        return s.copyWith(data: s.data.copyWith(phase: GamePhase.fromOgs(payload)));
      case 'removed_stones':
        final json = asMap(payload) ?? const {};
        final all = json['all_removed'];
        if (all is! String) return null;
        return s.copyWith(data: s.data.copyWith(removed: decodeOgsMoves(all).nonNulls.toSet()));
      case 'removed_stones_accepted':
        final json = asMap(payload) ?? const {};
        final stones = json['stones'];
        return s.copyWith(
          data: s.data.copyWith(
            phase: GamePhase.fromOgs(json['phase']),
            outcome: json['outcome'] as String?,
            winnerId: asInt(json['winner']),
            removed: stones is String ? decodeOgsMoves(stones).nonNulls.toSet() : null,
          ),
        );
      case 'undo_requested':
        final moveNumber = payload is Map ? asInt(payload['move_number']) : asInt(payload);
        return s.copyWith(undoRequestedAt: () => moveNumber);
      case 'undo_canceled':
        return s.copyWith(undoRequestedAt: () => null);
      case 'undo_accepted':
        // The server sends no new game data: resynchronise.
        _connect();
        return s.copyWith(undoRequestedAt: () => null);
      case 'error':
        return s.copyWith(error: () => payload?.toString() ?? 'Error', pendingMove: () => null);
      default:
        return null;
    }
  }

  void _update(OnlineGameState Function(OnlineGameState) f) {
    if (state.value case final s?) state = AsyncData(f(s));
  }

  /// Plays a stone. Returns the reason if the move is illegal locally.
  IllegalMoveException? play(Point p) {
    final s = state.value;
    if (s == null || !s.isMyTurn) return const IllegalMoveException(IllegalMoveReason.wrongTurn);
    try {
      s.game.play(p);
    } on IllegalMoveException catch (e) {
      return e;
    }
    _socket.send('game/move', {'game_id': gameId, 'move': encodeOgsMove(p)});
    _update((s) => s.copyWith(pendingMove: () => p, error: () => null));
    return null;
  }

  void pass() {
    if (!(state.value?.isMyTurn ?? false)) return;
    _socket.send('game/move', {'game_id': gameId, 'move': encodeOgsMove(null)});
  }

  void resign() => _socket.send('game/resign', {'game_id': gameId});

  void requestUndo() {
    final s = state.value;
    if (s == null) return;
    _socket.send('game/undo/request', {'game_id': gameId, 'move_number': s.data.moves.length});
  }

  void acceptUndo() {
    final s = state.value;
    if (s == null) return;
    _socket.send('game/undo/accept', {'game_id': gameId, 'move_number': s.data.moves.length});
  }

  /// In the stone removal phase, marks or unmarks the chain at [p] as dead.
  void toggleRemoved(Point p) {
    final s = state.value;
    if (s == null || s.phase != GamePhase.stoneRemoval || !s.isPlayer) return;
    final group = s.game.board.groupAt(p);
    if (group == null) return;
    final removed = !s.data.removed.contains(p);
    _socket.send('game/removed_stones/set', {
      'game_id': gameId,
      'removed': removed,
      'stones': group.stones.map(encodeOgsMove).join(),
    });
  }

  void acceptRemoved() {
    final s = state.value;
    if (s == null) return;
    _socket.send('game/removed_stones/accept', {
      'game_id': gameId,
      'stones': s.data.removed.map(encodeOgsMove).join(),
      'strict_seki_mode': false,
    });
  }

  void rejectRemoved() => _socket.send('game/removed_stones/reject', {'game_id': gameId});

  void clearError() => _update((s) => s.copyWith(error: () => null));
}
