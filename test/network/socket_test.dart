import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tengen/src/network/socket.dart';

import '../fakes.dart';

void main() {
  late List<FakeWebSocketChannel> channels;
  late OgsSocket socket;

  setUp(() {
    channels = [];
    socket = OgsSocket(
      uri: Uri.parse('wss://example.test/'),
      channelFactory: (_) {
        final c = FakeWebSocketChannel();
        channels.add(c);
        return c;
      },
    );
  });

  tearDown(() => socket.dispose());

  test('authenticates on connect and flushes queued messages in order', () async {
    socket
      ..authenticate(jwt: 'jwt-1')
      ..send('game/connect', {'game_id': 1})
      ..connect();
    await pumpEventQueue();
    expect(socket.status, SocketStatus.connected);
    final commands = channels.single.sent.map((m) => m.first).toList();
    expect(commands.take(3), ['authenticate', 'game/connect', 'net/ping']);
    expect(channels.single.sent.first[1], containsPair('jwt', 'jwt-1'));
  });

  test('request completes with the reply carrying its id', () async {
    socket.connect();
    await pumpEventQueue();
    final future = socket.request('gamelist/query', {'list': 'live'});
    await pumpEventQueue();
    final message = channels.single.sentCommands('gamelist/query').single;
    final id = message[2]! as int;
    channels.single.serverReply(id, {'results': <Object?>[]});
    expect(await future, {'results': <Object?>[]});
  });

  test('request fails with the server error', () async {
    socket.connect();
    await pumpEventQueue();
    final future = socket.request('game/move', {'game_id': 1});
    await pumpEventQueue();
    final id = channels.single.sentCommands('game/move').single[2]! as int;
    channels.single.serverReply(id, null, {'code': 'x', 'message': 'Not your turn'});
    await expectLater(
      future,
      throwsA(isA<SocketRequestException>().having((e) => e.message, 'message', 'Not your turn')),
    );
  });

  test('dispatches server events and measures the clock drift with pongs', () async {
    socket.connect();
    await pumpEventQueue();
    final events = <SocketEvent>[];
    socket.events.listen(events.add);
    final now = DateTime.now().millisecondsSinceEpoch;
    channels.single
      ..serverSend('game/1/phase', 'finished')
      ..serverSend('net/pong', {'client': now, 'server': now - 5000});
    await pumpEventQueue();
    expect(events.map((e) => e.name), ['game/1/phase', 'net/pong']);
    expect(events.first.data, 'finished');
    expect(socket.clockDriftMs, closeTo(5000, 200));
  });

  test('reconnects after a disconnection and authenticates again', () {
    fakeAsync((async) {
      socket
        ..authenticate(jwt: 'jwt-1')
        ..connect();
      async.flushMicrotasks();
      final statuses = <SocketStatus>[];
      socket.statusChanges.listen(statuses.add);
      channels.single.serverClose();
      async.flushMicrotasks();
      expect(socket.status, SocketStatus.disconnected);
      async.elapse(const Duration(seconds: 2));
      expect(channels, hasLength(2));
      expect(socket.status, SocketStatus.connected);
      expect(channels.last.sent.first.first, 'authenticate');
      expect(statuses, [
        SocketStatus.disconnected,
        SocketStatus.connecting,
        SocketStatus.connected,
      ]);
    });
  });
}
