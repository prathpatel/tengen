import 'package:flutter_test/flutter_test.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/ogs/game_data.dart';
import 'package:tengen/src/model/online_game/online_game_controller.dart';

import '../../fakes.dart';

Map<String, Object?> gamedata({List<List<int>> moves = const [], String phase = 'play'}) => {
  'game_id': 7,
  'game_name': 'Test game',
  'width': 9,
  'height': 9,
  'rules': 'japanese',
  'komi': 6.5,
  'handicap': 0,
  'initial_player': 'black',
  'initial_state': {'black': '', 'white': ''},
  'moves': moves,
  'phase': phase,
  'players': {
    'black': {'id': 42, 'username': 'alice', 'rank': 25},
    'white': {'id': 99, 'username': 'bob', 'rank': 27},
  },
  'time_control': {'system': 'fischer', 'initial_time': 300, 'time_increment': 5},
  'clock': {
    'game_id': 7,
    'current_player': 42,
    'black_player_id': 42,
    'white_player_id': 99,
    'last_move': DateTime.now().millisecondsSinceEpoch,
    'black_time': {'thinking_time': 300},
    'white_time': {'thinking_time': 280},
  },
};

void main() {
  Future<
    ({
      FakeWebSocketChannel socket,
      OnlineGameController controller,
      Future<OnlineGameState> Function() read,
    })
  >
  setUpGame({required int userId}) async {
    final (:container, :sockets) = await makeContainer(
      http: (r) => r.url.path == '/api/v1/ui/config'
          ? {
              'user': {'id': userId, 'username': 'alice'},
              'user_jwt': 'jwt',
            }
          : null,
    );
    addTearDown(container.dispose);
    final sub = container.listen(onlineGameProvider(7), (_, _) {});
    addTearDown(sub.close);
    await pumpEventQueue();
    final socket = sockets.single;
    expect(socket.sentCommands('game/connect').single[1], {'game_id': 7, 'chat': true});
    socket.serverSend(
      'game/7/gamedata',
      gamedata(
        moves: [
          [2, 2, 1000],
        ],
      ),
    );
    await pumpEventQueue();
    return (
      socket: socket,
      controller: container.read(onlineGameProvider(7).notifier),
      read: () => container.read(onlineGameProvider(7).future),
    );
  }

  test('builds the game from the game data, as a player', () async {
    final (:socket, :controller, :read) = await setUpGame(userId: 99);
    final state = await read();
    expect(state.myColor, StoneColor.white);
    expect(state.game.board[const Point(2, 2)], StoneColor.black);
    expect(state.isMyTurn, isTrue);
    expect(state.data.white.rankLabel, '3k');
    expect(state.data.timeControl!.description, '5m + 5s');
  });

  test('sends moves and applies the server echo', () async {
    final (:socket, :controller, :read) = await setUpGame(userId: 99);
    expect(controller.play(const Point(2, 2))?.message, 'There is already a stone there.');
    expect(controller.play(const Point(6, 6)), isNull);
    expect(socket.sentCommands('game/move').single[1], {'game_id': 7, 'move': 'gg'});
    expect((await read()).pendingMove, const Point(6, 6));
    expect((await read()).isMyTurn, isFalse);

    socket.serverSend('game/7/move', {
      'game_id': 7,
      'move_number': 2,
      'move': [6, 6, 1200],
    });
    await pumpEventQueue();
    final state = await read();
    expect(state.pendingMove, isNull);
    expect(state.game.board[const Point(6, 6)], StoneColor.white);
    expect(state.game.toMove, StoneColor.black);
  });

  test('reconnects to the game when a move is missed', () async {
    final (:socket, :controller, :read) = await setUpGame(userId: 1);
    expect((await read()).isPlayer, isFalse);
    socket.serverSend('game/7/move', {
      'game_id': 7,
      'move_number': 5,
      'move': [1, 1, 100],
    });
    await pumpEventQueue();
    expect(socket.sentCommands('game/connect'), hasLength(2));
    expect((await read()).game.moveCount, 1);
  });

  test('follows clock, phase, stone removal and the result', () async {
    final (:socket, :controller, :read) = await setUpGame(userId: 42);
    socket
      ..serverSend('game/7/clock', {
        'current_player': 99,
        'black_player_id': 42,
        'white_player_id': 99,
        'last_move': 1000,
        'black_time': {'thinking_time': 120},
        'white_time': {'thinking_time': 60},
      })
      ..serverSend('game/7/phase', 'stone removal')
      ..serverSend('game/7/removed_stones', {'removed': true, 'stones': 'cc', 'all_removed': 'cc'});
    await pumpEventQueue();
    var state = await read();
    expect(state.data.clock!.currentColor, StoneColor.white);
    expect(state.phase, GamePhase.stoneRemoval);
    expect(state.data.removed, {const Point(2, 2)});

    controller.acceptRemoved();
    expect(socket.sentCommands('game/removed_stones/accept').single[1], {
      'game_id': 7,
      'stones': 'cc',
      'strict_seki_mode': false,
    });

    socket.serverSend('game/7/removed_stones_accepted', {
      'player_id': 99,
      'stones': 'cc',
      'phase': 'finished',
      'outcome': '76.5 points',
      'winner': 99,
    });
    await pumpEventQueue();
    state = await read();
    expect(state.phase, GamePhase.finished);
    expect(state.data.winner, StoneColor.white);
  });

  test('disconnects from the game when disposed', () async {
    final (:container, :sockets) = await makeContainer();
    final sub = container.listen(onlineGameProvider(7), (_, _) {});
    await pumpEventQueue();
    sub.close();
    await pumpEventQueue();
    expect(sockets.single.sentCommands('game/disconnect').single[1], {'game_id': 7});
    container.dispose();
  });

  test('collects the players and spectators chat, and sends messages', () async {
    final (:socket, :controller, :read) = await setUpGame(userId: 99);
    Map<String, Object?> line(String channel, String id, Object body) => {
      'channel': channel,
      'line': {
        'chat_id': id,
        'date': 1700000000,
        'move_number': 1,
        'player_id': 42,
        'username': 'alice',
        'body': body,
      },
    };
    socket
      ..serverSend('game/7/chat', line('main', 'a', 'Have a good game'))
      ..serverSend('game/7/chat', line('spectator', 'b', {'en': 'Nice move', 'fr': 'Joli'}))
      ..serverSend('game/7/chat', line('malkovich', 'c', 'hidden comment'))
      ..serverSend('game/7/chat', line('main', 'a', 'Have a good game'));
    await pumpEventQueue();
    var chat = (await read()).chat;
    expect(chat.map((l) => l.text), ['Have a good game', 'Nice move']);
    expect(chat.last.isSpectator, isTrue);
    expect(chat.first.date, DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000));

    controller.sendChat('  thanks!  ');
    expect(socket.sentCommands('game/chat').single[1], {
      'game_id': 7,
      'type': 'main',
      'move_number': 1,
      'body': 'thanks!',
    });

    socket.serverSend('game/7/chat/remove', {
      'game_id': 7,
      'chat_ids': ['a'],
    });
    await pumpEventQueue();
    chat = (await read()).chat;
    expect(chat.map((l) => l.id), ['b']);

    socket.serverSend('game/7/reset-chats', null);
    await pumpEventQueue();
    expect((await read()).chat, isEmpty);
  });

  test('anti-stalling: shows the OGS estimate and ends the game with it', () async {
    final (:socket, :controller, :read) = await setUpGame(userId: 99);
    socket.serverSend('game/7/stalling_score_estimate', {
      'game_id': 7,
      'move_number': 1,
      'predicted_winner': 'black',
      'win_rate': 0.97,
      'score': 12.5,
      'removed': '',
      'ownership': <Object?>[],
    });
    await pumpEventQueue();
    final estimate = (await read()).stallingEstimate!;
    expect(estimate.winner, StoneColor.black);
    expect(estimate.winRate, closeTo(0.97, 1e-9));

    controller.preventStalling(estimate.winner);
    expect(socket.sentCommands('game/prevent_stalling').single[1], {
      'game_id': 7,
      'winner': 'black',
    });

    // A new move makes the estimate stale.
    socket.serverSend('game/7/move', {
      'game_id': 7,
      'move_number': 2,
      'move': [5, 5, 100],
    });
    await pumpEventQueue();
    expect((await read()).stallingEstimate, isNull);
  });
}
