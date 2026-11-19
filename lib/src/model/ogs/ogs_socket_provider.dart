import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tengen/src/constants.dart';
import 'package:tengen/src/model/auth/auth_controller.dart';
import 'package:tengen/src/network/socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Creates the WebSocket channel. Override it in tests with a fake channel.
final webSocketChannelFactoryProvider = Provider<WebSocketChannelFactory>(
  (ref) => WebSocketChannel.connect,
);

/// The app-wide connection to the OGS realtime server.
///
/// Authenticates with the current session's JWT (guests have one too), and again whenever the
/// session changes.
final ogsSocketProvider = Provider<OgsSocket>((ref) {
  final socket = OgsSocket(
    uri: ogsWsUri(),
    channelFactory: ref.watch(webSocketChannelFactoryProvider),
  );
  ref.onDispose(socket.dispose);
  ref.listen(authProvider, (_, next) {
    if (next.value case final auth?) {
      socket.authenticate(jwt: auth.jwt, clientVersion: kAppVersion);
    }
  }, fireImmediately: true);
  socket.connect();
  return socket;
});

/// The connection status of [ogsSocketProvider].
final socketStatusProvider = StreamProvider<SocketStatus>((ref) async* {
  final socket = ref.watch(ogsSocketProvider);
  yield socket.status;
  yield* socket.statusChanges;
});
