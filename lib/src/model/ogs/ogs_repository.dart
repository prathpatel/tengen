import 'dart:async';

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

  /// How many games of player [id] match [filters] (the fields of the OGS games API: `black`,
  /// `white`, `black_lost`, `white_lost`, `annulled`, `ended__isnull`…).
  Future<int> countGames(int id, Map<String, String> filters) async {
    final json = asMap(
      await _http.get('/api/v1/players/$id/games', {...filters, 'page_size': '1'}),
    );
    return asInt(json?['count']) ?? 0;
  }

  /// A game with its moves (`gamedata` of `/api/v1/games/<id>`).
  Future<OgsGameData?> gameData(int id) async {
    final json = asMap(await _http.get('/api/v1/games/$id'));
    final data = asMap(json?['gamedata']);
    return data == null ? null : OgsGameData.fromJson({...data, 'game_id': id});
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

/// Finished, not annulled games: the same filters for every count.
const _finished = {'ended__isnull': 'false', 'annulled': 'false'};

/// A player's finished games, and how many they won, counted by OGS.
final playerStatsProvider = FutureProvider.autoDispose.family<({int games, int wins}), int>((
  ref,
  id,
) async {
  final repo = ref.watch(ogsRepositoryProvider);
  final counts = await Future.wait([
    repo.countGames(id, _finished),
    repo.countGames(id, {
      ..._finished,
      'black': '$id',
      'white_lost': 'true',
      'black_lost': 'false',
    }),
    repo.countGames(id, {
      ..._finished,
      'white': '$id',
      'black_lost': 'true',
      'white_lost': 'false',
    }),
  ]);
  return (games: counts[0], wins: counts[1] + counts[2]);
});

/// The record of [me] against [them]: the games each won, counted by OGS.
final headToHeadProvider = FutureProvider.autoDispose
    .family<({int wins, int losses}), ({int me, int them})>((ref, players) async {
      final repo = ref.watch(ogsRepositoryProvider);
      final (:me, :them) = players;
      Future<int> won(int winner, int loser) async {
        final counts = await Future.wait([
          repo.countGames(them, {
            ..._finished,
            'black': '$winner',
            'white': '$loser',
            'white_lost': 'true',
            'black_lost': 'false',
          }),
          repo.countGames(them, {
            ..._finished,
            'black': '$loser',
            'white': '$winner',
            'black_lost': 'true',
            'white_lost': 'false',
          }),
        ]);
        return counts[0] + counts[1];
      }

      final results = await Future.wait([won(me, them), won(them, me)]);
      return (wins: results[0], losses: results[1]);
    });

/// The moves of a game, for a small board (finished games come without them).
final gameDataProvider = FutureProvider.autoDispose.family<OgsGameData?, int>((ref, id) {
  // Kept a few minutes once out of view: scrolling back must not download it again.
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 5), link.close);
  ref.onDispose(timer.cancel);
  return ref.watch(ogsRepositoryProvider).gameData(id);
});
