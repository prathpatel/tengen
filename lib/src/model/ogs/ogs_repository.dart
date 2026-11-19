import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tengen/src/model/auth/auth_controller.dart';
import 'package:tengen/src/model/ogs/game_data.dart';
import 'package:tengen/src/model/ogs/ogs_socket_provider.dart';
import 'package:tengen/src/model/ogs/user.dart';
import 'package:tengen/src/network/http.dart';
import 'package:tengen/src/network/socket.dart';
import 'package:tengen/src/utils/json.dart';

final ogsRepositoryProvider = Provider<OgsRepository>(
  (ref) => OgsRepository(ref.watch(ogsHttpProvider), ref.watch(ogsSocketProvider)),
);

/// Reads data from the OGS REST and realtime APIs.
class OgsRepository {
  const OgsRepository(this._http, this._socket);

  final OgsHttp _http;
  final OgsSocket _socket;

  /// The signed in player's ongoing games.
  Future<List<PlayerGame>> activeGames() async {
    final json = asMap(await _http.get('/api/v1/ui/overview')) ?? const {};
    return [
      for (final g in asList(json['active_games']))
        if (asMap(g) case final map?) PlayerGame.fromJson(map),
    ];
  }

  Future<OgsUser> player(int id) async =>
      OgsUser.fromJson(asMap(await _http.get('/api/v1/players/$id')) ?? const {});

  /// The finished games of a player, most recent first.
  Future<List<PlayerGame>> playerGames(int id, {int pageSize = 20}) async {
    final json =
        asMap(
          await _http.get('/api/v1/players/$id/games', {
            'ordering': '-ended',
            'ended__isnull': 'false',
            'page_size': '$pageSize',
          }),
        ) ??
        const {};
    return [
      for (final g in asList(json['results']))
        if (asMap(g) case final map?) PlayerGame.fromJson(map),
    ];
  }

  /// Ongoing public games, best ranked first. [list] is `live` or `corr`.
  Future<List<GameListEntry>> liveGames({String list = 'live', int limit = 50}) async {
    final reply = asMap(
      await _socket.request('gamelist/query', {
        'list': list,
        'sort_by': 'rank',
        'where': const <String, Object?>{},
        'from': 0,
        'limit': limit,
      }),
    );
    return [
      for (final g in asList(reply?['results']))
        if (asMap(g) case final map?) GameListEntry.fromJson(map),
    ];
  }
}

final activeGamesProvider = FutureProvider.autoDispose<List<PlayerGame>>((ref) async {
  final auth = await ref.watch(authProvider.future);
  if (!auth.isSignedIn) return const [];
  return await ref.watch(ogsRepositoryProvider).activeGames();
});

enum GameListKind {
  live('live', 'Live'),
  correspondence('corr', 'Correspondence');

  const GameListKind(this.ogsName, this.label);

  final String ogsName;
  final String label;
}

final liveGamesProvider = FutureProvider.autoDispose.family<List<GameListEntry>, GameListKind>(
  (ref, kind) => ref.watch(ogsRepositoryProvider).liveGames(list: kind.ogsName),
);

final playerProvider = FutureProvider.autoDispose.family<OgsUser, int>(
  (ref, id) => ref.watch(ogsRepositoryProvider).player(id),
);

final playerGamesProvider = FutureProvider.autoDispose.family<List<PlayerGame>, int>(
  (ref, id) => ref.watch(ogsRepositoryProvider).playerGames(id),
);
