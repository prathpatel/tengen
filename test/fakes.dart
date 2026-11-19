import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:tengen/src/model/ogs/ogs_socket_provider.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/network/http.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// An in-memory WebSocket: the test plays the server.
class FakeWebSocketChannel with StreamChannelMixin<dynamic> implements WebSocketChannel {
  final _incoming = StreamController<dynamic>();
  final List<List<Object?>> sent = [];
  late final _FakeSink _sink = _FakeSink(this);

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  Future<void> get ready => Future.value();

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  /// Sends a message from the server.
  void serverSend(String event, Object? data) => _incoming.add(jsonEncode([event, data]));

  void serverReply(int id, Object? data, [Object? error]) =>
      _incoming.add(jsonEncode([id, data, error]));

  /// Simulates the server closing the connection.
  Future<void> serverClose() => _incoming.close();

  Iterable<List<Object?>> sentCommands(String command) => sent.where((m) => m.first == command);
}

class _FakeSink implements WebSocketSink {
  _FakeSink(this._channel);

  final FakeWebSocketChannel _channel;
  final _done = Completer<void>();

  @override
  void add(dynamic data) => _channel.sent.add(jsonDecode(data as String) as List<Object?>);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) => stream.forEach(add);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> get done => _done.future;
}

/// A guest `ui/config` response.
const guestConfig = {
  'user': {'id': -1, 'username': 'guest1', 'anonymous': true},
  'user_jwt': 'guest-jwt',
};

/// A fake OGS REST server. [handler] returns the JSON body for a request, or null for 404.
http.Client fakeOgsHttp(Object? Function(http.Request request) handler) =>
    MockClient((request) async {
      final body = handler(request);
      if (body == null) return http.Response('{"detail": "Not found"}', 404);
      if (body is http.Response) return body;
      return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
    });

/// Creates a container wired to fake HTTP, WebSocket and storage.
Future<({ProviderContainer container, List<FakeWebSocketChannel> sockets})> makeContainer({
  Object? Function(http.Request request)? http,
  Map<String, Object> prefs = const {},
  Map<String, String> secureStorage = const {},
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  FlutterSecureStorage.setMockInitialValues(Map.of(secureStorage));
  final sharedPrefs = await SharedPreferences.getInstance();
  final sockets = <FakeWebSocketChannel>[];
  final container = ProviderContainer(
    overrides: [
      ...overrides,
      sharedPreferencesProvider.overrideWithValue(sharedPrefs),
      httpClientProvider.overrideWithValue(
        fakeOgsHttp(http ?? (r) => r.url.path == '/api/v1/ui/config' ? guestConfig : null),
      ),
      webSocketChannelFactoryProvider.overrideWithValue((_) {
        final channel = FakeWebSocketChannel();
        sockets.add(channel);
        return channel;
      }),
    ],
  );
  return (container: container, sockets: sockets);
}
