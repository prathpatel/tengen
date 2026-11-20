import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tengen/src/model/go/game.dart';
import 'package:tengen/src/model/ogs/game_data.dart';
import 'package:tengen/src/model/ogs/ogs_socket_provider.dart';
import 'package:tengen/src/network/socket.dart';
import 'package:tengen/src/utils/json.dart';

/// The position of an OGS game, kept up to date, for a small board in a list: it connects to the
/// game without its chat, as the OGS "observe games" page does for its boards.
final gamePreviewProvider = StreamProvider.autoDispose.family<GoGame, int>((ref, gameId) {
  final socket = ref.watch(ogsSocketProvider);
  final controller = StreamController<GoGame>();
  OgsGameData? data;
  void connect() => socket.send('game/connect', {'game_id': gameId, 'chat': false});

  final subscriptions = [
    socket.events
        .where((e) => e.name == 'game/$gameId/gamedata' || e.name == 'game/$gameId/move')
        .listen((event) {
          if (event.name.endsWith('/gamedata')) {
            data = OgsGameData.fromJson(asMap(event.data) ?? const {});
          } else if (data case final current?) {
            final json = asMap(event.data) ?? const {};
            final number = asInt(json['move_number']);
            if (number != null && number != current.moves.length + 1) {
              connect(); // Out of sync: the server sends the whole game again.
              return;
            }
            data = current.copyWith(moves: [...current.moves, decodeOgsArrayMove(json['move'])]);
          }
          if (data case final d?) controller.add(d.buildGame());
        }),
    socket.statusChanges.where((s) => s == SocketStatus.connected).listen((_) => connect()),
  ];
  if (socket.isConnected) connect();
  ref.onDispose(() {
    for (final s in subscriptions) {
      unawaited(s.cancel());
    }
    socket.send('game/disconnect', {'game_id': gameId});
    unawaited(controller.close());
  });
  return controller.stream;
});
