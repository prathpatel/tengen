import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef WebSocketChannelFactory = WebSocketChannel Function(Uri uri);

enum SocketStatus { connecting, connected, disconnected }

/// A message pushed by the server: `name` is the event, e.g. `game/123/move`.
@immutable
class SocketEvent {
  const SocketEvent(this.name, this.data);

  final String name;
  final Object? data;

  @override
  String toString() => 'SocketEvent($name)';
}

class SocketRequestException implements Exception {
  const SocketRequestException(this.command, this.error);

  final String command;
  final Object? error;

  String get message {
    final e = error;
    if (e is Map && e['message'] != null) return e['message'].toString();
    return e?.toString() ?? 'Request $command failed';
  }

  @override
  String toString() => 'SocketRequestException($command, $error)';
}

/// Client for the OGS realtime API.
///
/// A port of the `GobanSocket` class of the OGS `goban` library. Messages are JSON arrays:
/// - client to server: `[command, data]` or `[command, data, requestId]` when a reply is expected;
/// - server to client: `[eventName, data]`, or `[requestId, data, error]` for a reply.
///
/// The socket reconnects automatically with an increasing delay, re-sends the authentication on
/// every connection, and queues the messages sent while disconnected. Listeners that subscribe
/// to per-game events must send `game/connect` again when [status] becomes connected after a
/// reconnection.
class OgsSocket {
  OgsSocket({
    required this.uri,
    WebSocketChannelFactory? channelFactory,
    this.pingInterval = const Duration(seconds: 10),
    this.requestTimeout = const Duration(seconds: 20),
  }) : _channelFactory = channelFactory ?? WebSocketChannel.connect;

  final Uri uri;
  final WebSocketChannelFactory _channelFactory;
  final Duration pingInterval;
  final Duration requestTimeout;

  final _events = StreamController<SocketEvent>.broadcast();
  final _statusController = StreamController<SocketStatus>.broadcast();
  final Map<int, Completer<Object?>> _pending = {};
  final List<String> _sendQueue = [];

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _lastRequestId = 0;
  int _reconnectAttempts = 0;
  bool _disposed = false;
  Map<String, Object?>? _authentication;
  SocketStatus _status = SocketStatus.disconnected;

  /// Round trip time measured by the last ping.
  Duration latency = Duration.zero;

  /// Local clock minus server clock, in milliseconds, measured by the last ping.
  int clockDriftMs = 0;

  Stream<SocketEvent> get events => _events.stream;
  Stream<SocketStatus> get statusChanges => _statusController.stream;
  SocketStatus get status => _status;
  bool get isConnected => _status == SocketStatus.connected;

  /// The server time, estimated from the local clock and the measured drift.
  DateTime get serverNow => DateTime.now().subtract(Duration(milliseconds: clockDriftMs));

  /// The data of the events named [name].
  Stream<Object?> on(String name) => events.where((e) => e.name == name).map((e) => e.data);

  /// Events the server sends unasked when the connection opens (such as `active-bots`, the
  /// online bots): their last data is kept, for listeners that come later.
  static const retainedEvents = {'active-bots'};
  final Map<String, Object?> _retained = {};

  /// The last data of a [retainedEvents] event, if it came.
  Object? latest(String name) => _retained[name];

  void _setStatus(SocketStatus status) {
    if (_status == status) return;
    _status = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  void connect() {
    if (_disposed || _channel != null) return;
    _reconnectTimer?.cancel();
    _setStatus(SocketStatus.connecting);
    final WebSocketChannel channel;
    try {
      channel = _channelFactory(uri);
    } catch (e) {
      debugPrint('OgsSocket: could not connect: $e');
      _scheduleReconnect();
      return;
    }
    _channel = channel;
    _subscription = channel.stream.listen(
      _onMessage,
      onError: (Object e) {
        debugPrint('OgsSocket error: $e');
        _onClosed(channel);
      },
      onDone: () => _onClosed(channel),
      cancelOnError: true,
    );
    channel.ready.then(
      (_) {
        if (_channel != channel || _disposed) return;
        _reconnectAttempts = 0;
        _setStatus(SocketStatus.connected);
        if (_authentication case final auth?) _write(jsonEncode(['authenticate', auth]));
        final queued = List.of(_sendQueue);
        _sendQueue.clear();
        queued.forEach(_write);
        _ping();
        _pingTimer?.cancel();
        _pingTimer = Timer.periodic(pingInterval, (_) => _ping());
      },
      onError: (Object e) {
        debugPrint('OgsSocket: connection failed: $e');
        _onClosed(channel);
      },
    );
  }

  void _onClosed(WebSocketChannel channel) {
    if (_channel != channel) return;
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    _pingTimer?.cancel();
    _failPending('disconnected');
    _setStatus(SocketStatus.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    final base = math.min(30000, 250 * math.pow(2, _reconnectAttempts).toInt());
    final delay = base + math.Random().nextInt(250);
    _reconnectAttempts++;
    _reconnectTimer = Timer(Duration(milliseconds: delay), connect);
  }

  void _failPending(String reason) {
    final pending = Map.of(_pending);
    _pending.clear();
    for (final completer in pending.values) {
      completer.completeError(SocketRequestException('?', {'message': reason}));
    }
  }

  void _onMessage(dynamic raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw as String);
    } on Object catch (e) {
      debugPrint('OgsSocket: unparseable message: $e');
      return;
    }
    if (decoded is! List || decoded.isEmpty) return;
    final head = decoded[0];
    final data = decoded.length > 1 ? decoded[1] : null;
    if (head is int) {
      final completer = _pending.remove(head);
      if (completer == null) return;
      final error = decoded.length > 2 ? decoded[2] : null;
      if (error != null) {
        completer.completeError(SocketRequestException('#$head', error));
      } else {
        completer.complete(data);
      }
    } else if (head is String) {
      if (head == 'net/pong' && data is Map) {
        final client = data['client'];
        final server = data['server'];
        if (client is num && server is num) {
          final now = DateTime.now().millisecondsSinceEpoch;
          final rtt = now - client.toInt();
          latency = Duration(milliseconds: rtt);
          clockDriftMs = (now - rtt / 2 - server).round();
        }
      }
      if (retainedEvents.contains(head)) _retained[head] = data;
      if (!_events.isClosed) _events.add(SocketEvent(head, data));
    }
  }

  void _write(String message) {
    try {
      _channel!.sink.add(message);
    } on Object catch (e) {
      debugPrint('OgsSocket: send failed: $e');
      _sendQueue.add(message);
    }
  }

  void _ping() {
    if (!isConnected) return;
    _write(
      jsonEncode([
        'net/ping',
        {
          'client': DateTime.now().millisecondsSinceEpoch,
          'drift': clockDriftMs,
          'latency': latency.inMilliseconds,
        },
      ]),
    );
  }

  /// Sets the authentication sent on every connection, and sends it now if connected.
  ///
  /// [jwt] is the `user_jwt` of `/api/v1/ui/config` (guests have one too).
  void authenticate({required String jwt, String? deviceId, String? clientVersion}) {
    _authentication = {
      'jwt': jwt,
      'device_id': ?deviceId,
      'client': 'tengen',
      'client_version': ?clientVersion,
    };
    if (isConnected) _write(jsonEncode(['authenticate', _authentication]));
  }

  /// Sends a command, without waiting for a reply. Queued while disconnected.
  void send(String command, [Object? data]) {
    final message = jsonEncode([command, data]);
    if (isConnected) {
      _write(message);
    } else {
      _sendQueue.add(message);
    }
  }

  /// Sends a command and completes with the server's reply.
  Future<Object?> request(String command, [Object? data]) {
    final id = ++_lastRequestId;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    final message = jsonEncode([command, data, id]);
    if (isConnected) {
      _write(message);
    } else {
      _sendQueue.add(message);
    }
    return completer.future.timeout(
      requestTimeout,
      onTimeout: () {
        _pending.remove(id);
        throw SocketRequestException(command, {'message': 'Timed out'});
      },
    );
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _failPending('closed');
    _setStatus(SocketStatus.disconnected);
    _events.close();
    _statusController.close();
  }
}
