import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tengen/src/model/ogs/bots.dart';
import 'package:tengen/src/model/ogs/ogs_socket_provider.dart';
import 'package:tengen/src/model/online_game/automatch_controller.dart';
import 'package:tengen/src/model/online_game/bot_challenge_controller.dart';

import '../../fakes.dart';

/// A bot as in the `active-bots` event (trimmed from a real one, GnuGo on OGS).
Map<String, Object?> botJson({
  int id = 58441,
  String username = 'GnuGo',
  double ranking = 19.05,
  int version = 2,
  Object sizes = const [9, 13, 19],
  bool allowRanked = true,
  bool unrankedHandicap = true,
  List<String> rankRange = const ['30k', '9d'],
  Map<String, Object?>? live,
  bool rapid = true,
}) => {
  'id': id,
  'username': username,
  'icon-url': 'https://example.org/$id.png',
  'ranking': ranking,
  'is_bot': true,
  'config': {
    '_config_version': version,
    'hidden': false,
    'bot_id': id,
    'username': username,
    'allowed_time_control_systems': ['fischer', 'byoyomi', 'simple'],
    'allowed_board_sizes': sizes,
    'allowed_blitz_settings': {
      'fischer': {
        'initial_time_range': [3, 3600],
        'max_time_range': [3, 3600],
        'time_increment_range': [3, 300],
      },
      'byoyomi': {
        'main_time_range': [0, 3600],
        'period_time_range': [3, 300],
        'periods_range': [1, 10],
      },
      'concurrent_games': 2,
    },
    if (rapid)
      'allowed_rapid_settings': {
        'fischer': {
          'initial_time_range': [5, 600],
          'max_time_range': [5, 7200],
          'time_increment_range': [5, 300],
        },
        'byoyomi': {
          'main_time_range': [0, 3600],
          'period_time_range': [5, 30],
          'periods_range': [1, 10],
        },
      },
    'allowed_live_settings':
        live ??
        {
          'fischer': {
            'initial_time_range': [10, 3600],
            'max_time_range': [10, 7200],
            'time_increment_range': [10, 300],
          },
        },
    'allow_ranked': allowRanked,
    'allow_unranked': true,
    'allowed_rank_range': rankRange,
    'allow_ranked_handicap': false,
    'allow_unranked_handicap': unrankedHandicap,
    'decline_new_challenges': false,
  },
};

OgsBot bot([Map<String, Object?>? json]) =>
    OgsBot.fromJson(jsonDecode(jsonEncode(json ?? botJson())) as Map<String, dynamic>);

BotGameOptions game({
  int size = 9,
  GameSpeed speed = GameSpeed.rapid,
  ClockSystem system = ClockSystem.fischer,
  bool ranked = false,
  bool handicap = false,
  double? playerRanking,
}) => BotGameOptions(
  size: size,
  clock: BotClock(size, speed, system),
  ranked: ranked,
  handicap: handicap,
  playerRanking: playerRanking,
);

void main() {
  group('bots', () {
    test('parses the bot and its config', () {
      final b = bot();
      expect(b.username, 'GnuGo');
      expect(b.rankLabel, '11k');
      expect(b.category, BotCategory.intermediate);
      expect(b.isKataGo, isFalse);
      expect(bot(botJson(username: '5k-kgs-humanlike-kata')).isKataGo, isTrue);
      expect(b.config.speedSettings[GameSpeed.rapid]!['fischer']!['max_time_range'], (5, 7200));
    });

    test('uses the clocks of the OGS quick match', () {
      expect(BotClock(19, GameSpeed.rapid, ClockSystem.fischer).toJson(), {
        'system': 'fischer',
        'time_control': 'fischer',
        'speed': 'rapid',
        'initial_time': 300,
        'time_increment': 7,
        'max_time': 3000,
        'pause_on_weekends': false,
      });
      expect(BotClock(9, GameSpeed.live, ClockSystem.byoyomi).values, {
        'main_time': 300,
        'periods': 5,
        'period_time': 30,
      });
    });

    test('accepts a game within the bot settings', () {
      final (:clock, :problem) = botAccepts(bot(), game());
      expect(problem, isNull);
      expect(clock, BotClock(9, GameSpeed.rapid, ClockSystem.fischer));
    });

    test('explains why a bot cannot play', () {
      String? why(BotGameOptions o, [Map<String, Object?>? json]) =>
          botAccepts(bot(json), o).problem;
      expect(why(game(size: 13), botJson(sizes: [19])), 'Plays on 19×19');
      expect(why(game(ranked: true), botJson(allowRanked: false)), 'Unrated games only');
      expect(why(game(handicap: true), botJson(unrankedHandicap: false)), 'Even games only');
      expect(
        why(game(ranked: true, playerRanking: 5), botJson(rankRange: ['20k', '1d'])),
        'Rated games with 20k to 1d players only',
      );
      // Live byo-yomi: the bot has only Fischer settings for live games.
      expect(
        why(game(speed: GameSpeed.live, system: ClockSystem.byoyomi)),
        'Does not play live games',
      );
      // 19×19 live Fischer: 600s initial, max 6000s; the increment range starts at 10s.
      expect(why(game(size: 19, speed: GameSpeed.live)), isNull);
      expect(
        why(
          game(size: 19, speed: GameSpeed.live),
          botJson(
            live: {
              'fischer': {
                'max_time_range': [10, 1800],
                'time_increment_range': [10, 300],
              },
            },
          ),
        ),
        'Max time must be 10s to 30m',
      );
    });

    test('plays rapid games of version 1 bots with their live settings, as OGS does', () {
      final v1 = bot(
        botJson(
          version: 1,
          rapid: false,
          live: {
            'fischer': {
              'max_time_range': [30, 3600],
              'time_increment_range': [5, 300],
            },
          },
        ),
      );
      final (:clock, :problem) = botAccepts(v1, game());
      expect(problem, isNull);
      expect(clock!.speed, GameSpeed.live);
    });

    test('reads the bots announced by the server, hidden ones left out', () async {
      final (:container, :sockets) = await makeContainer();
      addTearDown(container.dispose);
      final sub = container.listen(activeBotsProvider, (_, _) {});
      addTearDown(sub.close);
      await pumpEventQueue();
      final hidden = botJson(id: 3, username: 'Hidden', ranking: 5);
      (hidden['config']! as Map<String, Object?>)['hidden'] = true;
      sockets.single.serverSend('active-bots', {
        '1': botJson(id: 1, username: 'Strong', ranking: 38),
        '2': botJson(id: 2, username: 'Weak', ranking: 5),
        '3': hidden,
      });
      await pumpEventQueue();
      expect(container.read(activeBotsProvider).value!.map((b) => b.username), ['Weak', 'Strong']);
    });
  });

  group('challenge', () {
    late List<http.Request> requests;

    Future<
      ({
        BotChallengeController controller,
        FakeWebSocketChannel socket,
        BotChallengeState Function() read,
      })
    >
    setUp({Object? Function(http.Request)? challengeReply}) async {
      requests = [];
      final (:container, :sockets) = await makeContainer(
        http: (r) {
          requests.add(r);
          if (r.url.path == '/api/v1/ui/config') {
            return {
              'user': {'id': 42, 'username': 'alice', 'ranking': 20},
              'user_jwt': 'jwt',
            };
          }
          if (r.url.path == '/api/v1/players/58441/challenge') {
            return challengeReply?.call(r) ?? {'challenge': 5, 'game': 77, 'uuid': 'u'};
          }
          if (r.url.path == '/api/v1/me/challenges/5') return '';
          return null;
        },
      );
      addTearDown(container.dispose);
      final sub = container.listen(botChallengeProvider, (_, _) {});
      addTearDown(sub.close);
      // Open the socket.
      container.read(ogsSocketProvider);
      await pumpEventQueue();
      return (
        controller: container.read(botChallengeProvider.notifier),
        socket: sockets.single,
        read: () => container.read(botChallengeProvider),
      );
    }

    test('challenges the bot like OGS and opens the game when it accepts', () async {
      final (:controller, :socket, :read) = await setUp();
      await controller.challenge(bot(), game(size: 13, handicap: true));
      final post = requests.singleWhere((r) => r.method == 'POST');
      expect(post.url.path, '/api/v1/players/58441/challenge');
      final body = jsonDecode(post.body) as Map<String, dynamic>;
      expect(body['challenger_color'], 'automatic');
      expect(body['game'], containsPair('width', 13));
      expect(body['game'], containsPair('handicap', -1));
      expect(body['game'], containsPair('ranked', false));
      expect(body['game'], containsPair('rules', 'japanese'));
      expect(body['game'], containsPair('time_control', 'fischer'));
      expect((body['game'] as Map)['time_control_parameters'], containsPair('initial_time', 180));

      expect(read(), isA<BotChallengeWaiting>());
      expect(socket.sentCommands('game/connect').single[1], {'game_id': 77});
      expect(socket.sentCommands('challenge/keepalive').first[1], {
        'challenge_id': 5,
        'game_id': 77,
      });

      socket.serverSend('game/77/gamedata', {'game_id': 77, 'phase': 'play'});
      await pumpEventQueue();
      expect(read(), isA<BotChallengeAccepted>());
      expect((read() as BotChallengeAccepted).gameId, 77);
      expect(socket.sentCommands('game/disconnect'), isNotEmpty);
    });

    test('reports why the bot declined', () async {
      final (:controller, :socket, :read) = await setUp();
      await controller.challenge(bot(), game());
      socket.serverSend('notification', {
        'id': 'n1',
        'type': 'gameOfferRejected',
        'game_id': 77,
        'rejection_details': {'rejection_code': 'too_many_live_games'},
      });
      await pumpEventQueue();
      expect(
        (read() as BotChallengeFailed).message,
        'This bot is playing too many live games right now. Try again later.',
      );
    });

    test('withdraws the challenge when cancelled', () async {
      final (:controller, socket: _, :read) = await setUp();
      await controller.challenge(bot(), game());
      await controller.cancel();
      expect(read(), isA<BotChallengeIdle>());
      expect(
        requests.where((r) => r.method == 'DELETE').single.url.path,
        '/api/v1/me/challenges/5',
      );
    });

    test('does not send a game the bot cannot play', () async {
      final (:controller, socket: _, :read) = await setUp();
      await controller.challenge(bot(botJson(sizes: [19])), game());
      expect((read() as BotChallengeFailed).message, 'Plays on 19×19');
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
    });

    test('gives up when the bot does not answer', () {
      fakeAsync((async) {
        late BotChallengeController controller;
        late FakeWebSocketChannel socket;
        late BotChallengeState Function() read;
        setUp().then((s) => (controller, socket, read) = (s.controller, s.socket, s.read));
        async.elapse(const Duration(milliseconds: 100));
        controller.challenge(bot(), game());
        async.elapse(const Duration(milliseconds: 100));
        async.elapse(const Duration(seconds: 10));
        expect(socket.sentCommands('challenge/keepalive').length, greaterThanOrEqualTo(10));
        async.elapse(botAnswerTimeout);
        async.flushMicrotasks();
        expect((read() as BotChallengeFailed).message, 'GnuGo did not answer. Try another bot.');
        expect(requests.where((r) => r.method == 'DELETE'), hasLength(1));
      });
    });
  });
}
