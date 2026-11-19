@Tags(['live'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tengen/src/constants.dart';
import 'package:tengen/src/model/go/game.dart';
import 'package:tengen/src/model/ogs/game_data.dart';
import 'package:tengen/src/network/http.dart';
import 'package:tengen/src/network/socket.dart';
import 'package:tengen/src/utils/json.dart';

/// Replays [data] checking every move against the local rules. Returns the illegal moves found.
List<String> replayWithValidation(OgsGameData data) {
  var game = data.buildGame();
  // Rebuild from scratch with validation on.
  final setupOnly = OgsGameData.fromJson({
    'width': data.width,
    'height': data.height,
    'rules': data.ruleset.name,
    'komi': data.komi,
    'handicap': data.handicap,
    'free_handicap_placement': data.freeHandicapPlacement,
    'initial_player': data.initialPlayer.name,
    'initial_state': {
      'black': data.initialBlack.map((p) => '${String.fromCharCode(97 + p.x)}${String.fromCharCode(97 + p.y)}').join(),
      'white': data.initialWhite.map((p) => '${String.fromCharCode(97 + p.x)}${String.fromCharCode(97 + p.y)}').join(),
    },
    'moves': const <Object?>[],
  });
  game = setupOnly.buildGame();
  final errors = <String>[];
  for (final (i, m) in data.moves.indexed) {
    try {
      game = game.play(m);
    } on IllegalMoveException catch (e) {
      errors.add('move ${i + 1} $m: ${e.reason}');
      game = game.playMove(GoMove(game.toMove, m), validate: false);
    }
  }
  return errors;
}

void main() {
  late OgsHttp api;
  late OgsSocket socket;

  setUpAll(() async {
    api = OgsHttp(http.Client());
    final config = asMap(await api.get('/api/v1/ui/config'))!;
    socket = OgsSocket(uri: ogsWsUri())
      ..authenticate(jwt: config['user_jwt'] as String)
      ..connect();
  });

  tearDownAll(() => socket.dispose());

  test('replays ongoing live games without illegal moves', () async {
    final list = asMap(
      await socket.request('gamelist/query', {
        'list': 'live',
        'sort_by': 'rank',
        'where': <String, Object?>{},
        'from': 0,
        'limit': 15,
      }),
    )!;
    final entries = [
      for (final g in asList(list['results'])) GameListEntry.fromJson(asMap(g)!),
    ];
    expect(entries, isNotEmpty);
    var checkedMoves = 0;
    for (final entry in entries) {
      final gamedata = socket.on('game/${entry.id}/gamedata').first;
      socket.send('game/connect', {'game_id': entry.id, 'chat': false});
      final data = OgsGameData.fromJson(asMap(await gamedata.timeout(const Duration(seconds: 10)))!);
      socket.send('game/disconnect', {'game_id': entry.id});
      final errors = replayWithValidation(data);
      checkedMoves += data.moves.length;
      // ignore: avoid_print
      print('game ${entry.id} ${data.width}x${data.height} ${data.ruleset.name} '
          'h${data.handicap} free=${data.freeHandicapPlacement} moves=${data.moves.length} '
          'errors=$errors');
      expect(errors, isEmpty, reason: 'game ${entry.id}');
      expect(data.buildGame().toMove, isNotNull);
    }
    // ignore: avoid_print
    print('checked $checkedMoves moves');
  });

  test('capture counts match OGS on finished games', () async {
    final list = asMap(
      await socket.request('gamelist/query', {
        'list': 'live',
        'sort_by': 'rank',
        'where': <String, Object?>{},
        'from': 0,
        'limit': 6,
      }),
    )!;
    final playerIds = {
      for (final g in asList(list['results'])) asInt(asMap(asMap(g)!['black'])!['id'])!,
    };
    var compared = 0;
    for (final playerId in playerIds) {
      final games = asMap(
        await api.get('/api/v1/players/$playerId/games', {
          'ordering': '-ended',
          'ended__isnull': 'false',
          'page_size': '5',
        }),
      )!;
      for (final g in asList(games['results'])) {
        final id = asInt(asMap(g)!['id'])!;
        final full = asMap(await api.get('/api/v1/games/$id'))!;
        final gamedata = asMap(full['gamedata'])!;
        final data = OgsGameData.fromJson(gamedata);
        final errors = replayWithValidation(data);
        expect(errors, isEmpty, reason: 'game $id');
        final score = asMap(gamedata['score']);
        if (score == null || data.moves.isEmpty) continue;
        final game = data.buildGame();
        final removed = data.removed;
        final board = game.board;
        // OGS prisoners = captures + dead stones removed at the end, when prisoners count.
        if (gamedata['score_prisoners'] != true) continue;
        final deadWhite = removed.where((p) => board[p]?.name == 'white').length;
        final deadBlack = removed.where((p) => board[p]?.name == 'black').length;
        final blackPrisoners = asInt(asMap(score['black'])!['prisoners']);
        final whitePrisoners = asInt(asMap(score['white'])!['prisoners']);
        // ignore: avoid_print
        print('game $id ${data.ruleset.name}: B ${game.position.blackCaptures}+$deadWhite '
            'vs $blackPrisoners, W ${game.position.whiteCaptures}+$deadBlack vs $whitePrisoners');
        expect(game.position.blackCaptures + deadWhite, blackPrisoners, reason: 'game $id');
        expect(game.position.whiteCaptures + deadBlack, whitePrisoners, reason: 'game $id');
        compared++;
      }
    }
    // ignore: avoid_print
    print('compared $compared finished games');
  });
}
