import 'package:flutter_test/flutter_test.dart';
import 'package:tengen/src/model/ogs/chat_rooms.dart';

import '../../fakes.dart';

Map<String, Object?> message(String id, String text, {String channel = 'global-english'}) => {
  'channel': channel,
  'id': 5,
  'username': 'carol',
  'ranking': 28,
  'professional': false,
  'ui_class': '',
  'message': {'i': id, 't': 1700000000, 'm': text},
};

void main() {
  Future<
    ({FakeWebSocketChannel socket, ChatRoomController controller, ChatRoomState Function() read})
  >
  join({bool signedIn = false}) async {
    final (:container, :sockets) = await makeContainer(
      http: (r) => r.url.path == '/api/v1/ui/config'
          ? (signedIn
                ? {
                    'user': {'id': 42, 'username': 'alice'},
                    'user_jwt': 'jwt',
                  }
                : guestConfig)
          : null,
    );
    addTearDown(container.dispose);
    final sub = container.listen(chatRoomProvider('global-english'), (_, _) {});
    addTearDown(sub.close);
    await pumpEventQueue();
    return (
      socket: sockets.single,
      controller: container.read(chatRoomProvider('global-english').notifier),
      read: () => container.read(chatRoomProvider('global-english')),
    );
  }

  test('joins the room and collects its messages, users and topic', () async {
    final (:socket, :controller, :read) = await join();
    expect(socket.sentCommands('chat/join').single[1], {'channel': 'global-english'});
    socket
      ..serverSend('chat-join', {
        'channel': 'global-english',
        'users': [
          {'id': 5, 'username': 'carol', 'ranking': 28},
          {'id': 6, 'username': 'dave', 'ranking': 31},
        ],
      })
      ..serverSend('chat-topic', {'channel': 'global-english', 'topic': 'Be nice', 'timestamp': 1})
      ..serverSend('chat-message', message('m1', 'hello'))
      ..serverSend('chat-message', message('m1', 'hello'))
      ..serverSend('chat-message', message('x', 'elsewhere', channel: 'global-french'))
      ..serverSend('chat-part', {
        'channel': 'global-english',
        'user': {'id': 6, 'username': 'dave'},
      });
    await pumpEventQueue();
    final state = read();
    expect(state.joined, isTrue);
    expect(state.topic, 'Be nice');
    expect(state.users.keys, [5]);
    expect(state.messages.map((m) => m.text), ['hello']);
    expect(state.messages.single.user.rankLabel, '2k');
    expect(state.messages.single.date, DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000));

    socket.serverSend('chat-message-removed', {'channel': 'global-english', 'uuid': 'm1'});
    await pumpEventQueue();
    expect(read().messages, isEmpty);
  });

  test('guests cannot send', () async {
    final (:socket, :controller, :read) = await join();
    expect(controller.send('hi'), isFalse);
    expect(socket.sentCommands('chat/send'), isEmpty);
  });

  test('sends messages, shows them at once and ignores the echo', () async {
    final (:socket, :controller, :read) = await join(signedIn: true);
    expect(controller.send('  good game everyone  '), isTrue);
    final sent = socket.sentCommands('chat/send').single[1]! as Map<String, Object?>;
    expect(sent['channel'], 'global-english');
    expect(sent['message'], 'good game everyone');
    expect(read().messages.single.user.username, 'alice');

    socket.serverSend('chat-message', message(sent['uuid']! as String, 'good game everyone'));
    await pumpEventQueue();
    expect(read().messages, hasLength(1));
  });

  test('leaves the room when no longer watched', () async {
    final (:container, :sockets) = await makeContainer();
    final sub = container.listen(chatRoomProvider('global-help'), (_, _) {});
    await pumpEventQueue();
    sub.close();
    await pumpEventQueue();
    expect(sockets.single.sentCommands('chat/part').single[1], {'channel': 'global-help'});
    container.dispose();
  });

  test('room flags', () {
    expect(globalChatRooms.first.flag, '🇺🇸');
    expect(globalChatRooms[1].flag, '🌐');
    expect(globalChatRooms, hasLength(38));
  });
}
