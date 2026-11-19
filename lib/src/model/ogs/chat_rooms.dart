import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:tengen/src/model/auth/auth_controller.dart';
import 'package:tengen/src/model/ogs/ogs_socket_provider.dart';
import 'package:tengen/src/model/ogs/user.dart';
import 'package:tengen/src/network/socket.dart';
import 'package:tengen/src/utils/json.dart';

/// A public OGS chat room.
@immutable
class ChatRoomInfo {
  const ChatRoomInfo(this.channel, this.name, [this.country]);

  final String channel;
  final String name;

  /// ISO country code used for the flag, null for rooms that are not about a language.
  final String? country;

  /// The flag emoji of [country], or a globe.
  String get flag {
    final c = country;
    if (c == null || c.length != 2) return '🌐';
    return String.fromCharCodes(c.toUpperCase().codeUnits.map((u) => 0x1F1E6 + u - 65));
  }
}

/// The global rooms of the OGS website, in the same order.
const globalChatRooms = [
  ChatRoomInfo('global-english', 'English', 'us'),
  ChatRoomInfo('global-help', 'Help'),
  ChatRoomInfo('global-offtopic', 'Off Topic'),
  ChatRoomInfo('global-rengo', 'Rengo'),
  ChatRoomInfo('global-joseki', 'OGS Joseki Explorer'),
  ChatRoomInfo('global-japanese', '日本語', 'jp'),
  ChatRoomInfo('global-zh-hans', '中文', 'cn'),
  ChatRoomInfo('global-zh-hant', '廣東話', 'hk'),
  ChatRoomInfo('global-korean', '한국어', 'kr'),
  ChatRoomInfo('global-russian', 'Русский', 'ru'),
  ChatRoomInfo('global-polish', 'Polski', 'pl'),
  ChatRoomInfo('global-arabic', 'العربية'),
  ChatRoomInfo('global-bulgarian', 'Български', 'bg'),
  ChatRoomInfo('global-catalan', 'Català'),
  ChatRoomInfo('global-czech', 'Čeština', 'cz'),
  ChatRoomInfo('global-esperanto', 'Esperanto'),
  ChatRoomInfo('global-german', 'Deutsch', 'de'),
  ChatRoomInfo('global-spanish', 'Español', 'es'),
  ChatRoomInfo('global-french', 'Français', 'fr'),
  ChatRoomInfo('global-filipino', 'Filipino', 'ph'),
  ChatRoomInfo('global-indonesian', 'Indonesian', 'id'),
  ChatRoomInfo('global-hebrew', 'עברית', 'il'),
  ChatRoomInfo('global-hindi', 'हिन्दी', 'in'),
  ChatRoomInfo('global-nepali', 'नेपाली', 'np'),
  ChatRoomInfo('global-bangla', 'বাংলা', 'bd'),
  ChatRoomInfo('global-lithuanian', 'Lietuvių', 'lt'),
  ChatRoomInfo('global-hungarian', 'Magyar', 'hu'),
  ChatRoomInfo('global-dutch', 'Nederlands', 'nl'),
  ChatRoomInfo('global-norwegian', 'Norsk', 'no'),
  ChatRoomInfo('global-italian', 'Italiano', 'it'),
  ChatRoomInfo('global-portuguese', 'Português', 'pt'),
  ChatRoomInfo('global-romanian', 'Română', 'ro'),
  ChatRoomInfo('global-swedish', 'Svenska', 'se'),
  ChatRoomInfo('global-finnish', 'Suomi', 'fi'),
  ChatRoomInfo('global-turkish', 'Türkçe', 'tr'),
  ChatRoomInfo('global-ukrainian', 'Українська', 'ua'),
  ChatRoomInfo('global-vietnamese', 'Tiếng Việt', 'vn'),
  ChatRoomInfo('global-thai', 'ภาษาไทย', 'th'),
];

/// A message of a chat room (`chat-message` event).
@immutable
class ChatRoomMessage {
  const ChatRoomMessage({
    required this.id,
    required this.user,
    required this.text,
    required this.date,
    this.system = false,
  });

  /// Parses a `chat-message` event. Returns null when it has no displayable text.
  static ChatRoomMessage? fromJson(Map<String, dynamic> json) {
    final message = asMap(json['message']) ?? const {};
    final body = message['m'];
    final text = switch (body) {
      final String s => s,
      final Map<dynamic, dynamic> m => m['text'] as String?,
      _ => null,
    };
    if (text == null || text.trim().isEmpty) return null;
    final seconds = asInt(message['t']) ?? 0;
    return ChatRoomMessage(
      id: message['i'] as String? ?? '${json['id']}-$seconds-${text.hashCode}',
      user: OgsUser.fromJson(json),
      text: text,
      // OGS sends seconds.
      date: DateTime.fromMillisecondsSinceEpoch(seconds * 1000),
      system: json['system'] == true,
    );
  }

  final String id;
  final OgsUser user;
  final String text;
  final DateTime date;

  /// A message from the server (e.g. a flood warning).
  final bool system;
}

@immutable
class ChatRoomState {
  const ChatRoomState({
    this.messages = const [],
    this.users = const {},
    this.topic,
    this.joined = false,
  });

  /// Oldest first.
  final List<ChatRoomMessage> messages;

  /// The people in the room, by id.
  final Map<int, OgsUser> users;
  final String? topic;

  /// Whether the server answered the join.
  final bool joined;

  ChatRoomState copyWith({
    List<ChatRoomMessage>? messages,
    Map<int, OgsUser>? users,
    String? topic,
    bool? joined,
  }) => ChatRoomState(
    messages: messages ?? this.messages,
    users: users ?? this.users,
    topic: topic ?? this.topic,
    joined: joined ?? this.joined,
  );
}

/// Joins an OGS chat room while it is watched, and leaves it when disposed.
///
/// Uses the realtime API like the website: `chat/join`, `chat/part` and `chat/send`; the server
/// pushes `chat-message` (the recent history on join, then live), `chat-join`, `chat-part`,
/// `chat-topic` and `chat-message-removed`.
final chatRoomProvider = NotifierProvider.autoDispose
    .family<ChatRoomController, ChatRoomState, String>(ChatRoomController.new);

class ChatRoomController extends Notifier<ChatRoomState> {
  ChatRoomController(this.channel);

  final String channel;

  /// Keeps the last messages only.
  static const maxMessages = 500;

  static const _events = {
    'chat-message',
    'chat-join',
    'chat-part',
    'chat-topic',
    'chat-message-removed',
  };

  @override
  ChatRoomState build() {
    final socket = ref.watch(ogsSocketProvider);
    void join() => socket.send('chat/join', {'channel': channel});

    final subscriptions = <StreamSubscription<Object?>>[
      socket.events
          .where((e) => _events.contains(e.name) && asMap(e.data)?['channel'] == channel)
          .listen((e) => state = _apply(state, e.name, asMap(e.data)!)),
      socket.statusChanges.where((s) => s == SocketStatus.connected).listen((_) => join()),
    ];
    ref.onDispose(() {
      for (final s in subscriptions) {
        s.cancel();
      }
      socket.send('chat/part', {'channel': channel});
    });
    // When the socket is still connecting, the status listener joins.
    if (socket.isConnected) join();
    return const ChatRoomState();
  }

  ChatRoomState _apply(ChatRoomState s, String event, Map<String, dynamic> json) {
    switch (event) {
      case 'chat-message':
        final message = ChatRoomMessage.fromJson(json);
        if (message == null || s.messages.any((m) => m.id == message.id)) return s;
        final messages = [...s.messages, message];
        return s.copyWith(
          messages: List.unmodifiable(
            messages.length > maxMessages
                ? messages.sublist(messages.length - maxMessages)
                : messages,
          ),
        );
      case 'chat-join':
        return s.copyWith(
          joined: true,
          users: Map.unmodifiable({
            ...s.users,
            for (final u in asList(json['users']))
              if (asMap(u) case final map?) OgsUser.fromJson(map).id: OgsUser.fromJson(map),
          }),
        );
      case 'chat-part':
        final id = asInt(asMap(json['user'])?['id']);
        return s.copyWith(users: Map.unmodifiable({...s.users}..remove(id)));
      case 'chat-topic':
        return s.copyWith(topic: json['topic'] as String? ?? '');
      case 'chat-message-removed':
        final uuid = json['uuid'];
        return s.copyWith(messages: s.messages.where((m) => m.id != uuid).toList());
      default:
        return s;
    }
  }

  /// Sends [text] to the room. Requires a signed in user. The message is shown right away; the
  /// server's echo of it is recognized by its id.
  bool send(String text) {
    final body = text.trim();
    final user = ref.read(authProvider).value?.user;
    if (body.isEmpty || user == null || user.anonymous) return false;
    final now = DateTime.now();
    final uuid = '${user.id.toRadixString(36)}.${now.millisecondsSinceEpoch.toRadixString(36)}';
    ref.read(ogsSocketProvider).send('chat/send', {
      'channel': channel,
      'uuid': uuid,
      'message': body,
    });
    state = state.copyWith(
      messages: List.unmodifiable([
        ...state.messages,
        ChatRoomMessage(id: uuid, user: user, text: body, date: now),
      ]),
    );
    return true;
  }
}
