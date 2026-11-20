import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tengen/src/model/ogs/bots.dart';
import 'package:tengen/src/model/ogs/ogs_repository.dart';
import 'package:tengen/src/model/online_game/automatch_controller.dart';
import 'package:tengen/src/model/online_game/bot_challenge_controller.dart';

import '../../fakes.dart';

/// A fake of the OGS games API that counts the games matching the filters, from a list of
/// (black, white, winner) games of player 7.
Object? countGames(http.Request r) {
  if (r.url.path == '/api/v1/ui/config') {
    return {
      'user': {'id': 42, 'username': 'alice'},
      'user_jwt': 'jwt',
    };
  }
  if (r.url.path != '/api/v1/players/7/games') return null;
  const games = [
    (black: 42, white: 7, winner: 42),
    (black: 7, white: 42, winner: 42),
    (black: 7, white: 42, winner: 7),
    (black: 7, white: 3, winner: 7),
    (black: 3, white: 7, winner: 3),
  ];
  final q = r.url.queryParameters;
  expect(q['ended__isnull'], 'false');
  expect(q['annulled'], 'false');
  expect(q['page_size'], '1');
  final count = games.where((g) {
    if (q['black'] case final b? when '${g.black}' != b) return false;
    if (q['white'] case final w? when '${g.white}' != w) return false;
    final blackLost = g.winner != g.black;
    if (q['black_lost'] case final l? when '$blackLost' != l) return false;
    if (q['white_lost'] case final l? when '${!blackLost}' != l) return false;
    return true;
  }).length;
  return {'count': count, 'results': <Object?>[]};
}

void main() {
  test("counts a player's finished games and wins with the OGS filters", () async {
    final (:container, sockets: _) = await makeContainer(http: countGames);
    addTearDown(container.dispose);
    final stats = await container.read(playerStatsProvider(7).future);
    expect(stats, (games: 5, wins: 2));
  });

  test('counts the record of two players against each other', () async {
    final (:container, sockets: _) = await makeContainer(http: countGames);
    addTearDown(container.dispose);
    final record = await container.read(headToHeadProvider((me: 42, them: 7)).future);
    expect(record, (wins: 2, losses: 1));
  });

  group('challenging a person', () {
    test('a correspondence challenge is sent, the game starts when accepted', () async {
      final posts = <http.Request>[];
      final (:container, sockets: _) = await makeContainer(
        http: (r) {
          if (r.method == 'POST') {
            posts.add(r);
            return {'challenge': 8, 'game': 80};
          }
          return r.url.path == '/api/v1/ui/config' ? guestConfig : null;
        },
      );
      addTearDown(container.dispose);
      final sub = container.listen(botChallengeProvider, (_, _) {});
      addTearDown(sub.close);
      await container
          .read(botChallengeProvider.notifier)
          .challengePlayer(
            playerId: 7,
            name: 'kuro_neko',
            color: 'black',
            options: BotGameOptions(
              size: 19,
              clock: BotClock(19, GameSpeed.correspondence, ClockSystem.fischer),
              ranked: true,
            ),
          );
      expect(posts.single.url.path, '/api/v1/players/7/challenge');
      final body = jsonDecode(posts.single.body) as Map<String, dynamic>;
      expect(body['challenger_color'], 'black');
      expect(body['game'], containsPair('ranked', true));
      expect(
        (body['game'] as Map)['time_control_parameters'],
        containsPair('time_increment', 86400),
      );
      expect(container.read(botChallengeProvider), isA<BotChallengeSent>());
    });
  });
}
