import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:tengen/src/model/ogs/bots.dart';
import 'package:tengen/src/model/ogs/ogs_socket_provider.dart';
import 'package:tengen/src/model/online_game/automatch_controller.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/network/http.dart';
import 'package:tengen/src/utils/json.dart';

sealed class BotChallengeState {
  const BotChallengeState();
}

class BotChallengeIdle extends BotChallengeState {
  const BotChallengeIdle();
}

/// The challenge is being sent, or waits for the opponent to accept it.
class BotChallengeWaiting extends BotChallengeState {
  const BotChallengeWaiting(this.opponent, {this.challengeId, this.gameId});

  /// The opponent's name.
  final String opponent;

  /// Known once OGS has created the challenge.
  final int? challengeId;
  final int? gameId;
}

/// A correspondence challenge, sent: the game starts when the opponent accepts it, maybe days
/// later (it then appears in the games list).
class BotChallengeSent extends BotChallengeState {
  const BotChallengeSent(this.opponent);

  final String opponent;
}

class BotChallengeAccepted extends BotChallengeState {
  const BotChallengeAccepted(this.gameId);

  final int gameId;
}

/// The bot declined, did not answer, or the challenge could not be made.
class BotChallengeFailed extends BotChallengeState {
  const BotChallengeFailed(this.message);

  final String message;
}

/// How long to wait for a bot to accept. Bots usually answer within seconds.
const botAnswerTimeout = Duration(seconds: 45);

final botChallengeProvider =
    NotifierProvider.autoDispose<BotChallengeController, BotChallengeState>(
      BotChallengeController.new,
    );

/// Challenges a bot, as the "Play computer" dialog of the OGS website does: a direct challenge
/// (`POST players/{bot}/challenge`), kept alive every second while the bot decides; the game data
/// arriving means the bot accepted, a `gameOfferRejected` notification that it declined.
class BotChallengeController extends Notifier<BotChallengeState> {
  Timer? _keepalive;
  Timer? _timeout;

  /// The challenge waiting for an answer, to withdraw it when the screen closes.
  int? _pendingChallenge;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  @override
  BotChallengeState build() {
    final http = ref.read(ogsHttpProvider);
    ref.onDispose(() {
      // Leaving the screen while waiting withdraws the challenge.
      if (_pendingChallenge case final id?) unawaited(_withdraw(id, http));
      _stop();
    });
    return const BotChallengeIdle();
  }

  /// The body of the challenge, built like the OGS "Play computer" button.
  @visibleForTesting
  static Map<String, Object?> challengeBody(
    BotGameOptions options,
    BotClock clock, {
    String color = 'automatic',
  }) => {
    'challenger_color': color,
    'invite_only': false,
    'min_ranking': -1000,
    'max_ranking': 1000,
    'game': {
      'name': 'Friendly Match',
      'width': options.size,
      'height': options.size,
      'ranked': options.ranked,
      'handicap': options.handicap ? -1 : 0,
      'rules': 'japanese',
      'komi_auto': 'automatic',
      'disable_analysis': false,
      'initial_state': null,
      'private': false,
      'time_control': clock.systemName,
      'time_control_parameters': clock.toJson(),
      'pause_on_weekends': false,
    },
  };

  Future<void> challenge(OgsBot bot, BotGameOptions options) async {
    if (state is BotChallengeWaiting) return;
    final (:clock, :problem) = botAccepts(bot, options);
    if (clock == null) {
      state = BotChallengeFailed(problem ?? '${bot.username} cannot play this game');
      return;
    }
    await _send(
      playerId: bot.id,
      name: bot.username,
      body: challengeBody(options, clock),
      timeout: botAnswerTimeout,
    );
  }

  /// Challenges a person, as the OGS player page does. A live game waits here for their answer
  /// (as long as the challenge is not cancelled); a correspondence one is just sent.
  Future<void> challengePlayer({
    required int playerId,
    required String name,
    required BotGameOptions options,
    String color = 'automatic',
  }) async {
    if (state is BotChallengeWaiting) return;
    final correspondence = options.clock.speed == GameSpeed.correspondence;
    await _send(
      playerId: playerId,
      name: name,
      body: challengeBody(options, options.clock, color: color),
      wait: !correspondence,
    );
  }

  Future<void> _send({
    required int playerId,
    required String name,
    required Map<String, Object?> body,
    Duration? timeout,
    bool wait = true,
  }) async {
    state = BotChallengeWaiting(name);
    final http = ref.read(ogsHttpProvider);
    final Object? response;
    try {
      response = await http.post('/api/v1/players/$playerId/challenge', body);
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = BotChallengeFailed(e is OgsHttpException ? e.message : 'Could not reach OGS');
      return;
    }
    final json = asMap(response) ?? const {};
    final challengeId = asInt(json['challenge']);
    final game = json['game'];
    final gameId = asInt(game is Map ? game['id'] : game);
    if (!ref.mounted || state is! BotChallengeWaiting) {
      // Cancelled while the challenge was being made.
      if (challengeId != null) unawaited(_withdraw(challengeId, http));
      return;
    }
    if (challengeId == null || gameId == null) {
      state = const BotChallengeFailed('OGS did not create the game');
      return;
    }
    if (!wait) {
      state = BotChallengeSent(name);
      return;
    }
    state = BotChallengeWaiting(name, challengeId: challengeId, gameId: gameId);
    _pendingChallenge = challengeId;

    final socket = ref.read(ogsSocketProvider);
    _subscriptions
      ..add(
        socket.on('game/$gameId/gamedata').listen((_) {
          _stop();
          socket.send('game/disconnect', {'game_id': gameId});
          state = BotChallengeAccepted(gameId);
        }),
      )
      ..add(
        socket.on('notification').listen((data) {
          final n = asMap(data) ?? const {};
          if (n['type'] != 'gameOfferRejected' || asInt(n['game_id']) != gameId) return;
          _stop();
          state = BotChallengeFailed(
            rejectionMessage(asMap(n['rejection_details'])) ??
                (n['message'] as String?) ??
                '$name declined the game',
          );
        }),
      );
    socket
      ..send('game/connect', {'game_id': gameId})
      ..send('challenge/keepalive', {'challenge_id': challengeId, 'game_id': gameId});
    _keepalive = Timer.periodic(const Duration(seconds: 1), (_) {
      socket.send('challenge/keepalive', {'challenge_id': challengeId, 'game_id': gameId});
    });
    if (timeout != null) {
      _timeout = Timer(timeout, () {
        _stop();
        unawaited(_withdraw(challengeId));
        socket.send('game/disconnect', {'game_id': gameId});
        state = BotChallengeFailed('$name did not answer. Try another bot.');
      });
    }
  }

  /// Withdraws the challenge.
  Future<void> cancel() async {
    final current = state;
    _stop();
    state = const BotChallengeIdle();
    if (current case BotChallengeWaiting(:final challengeId?, :final gameId?)) {
      ref.read(ogsSocketProvider).send('game/disconnect', {'game_id': gameId});
      await _withdraw(challengeId);
    }
  }

  /// Back to idle, once the game is open or the message read.
  void reset() {
    _stop();
    state = const BotChallengeIdle();
  }

  Future<void> _withdraw(int challengeId, [OgsHttp? http]) async {
    try {
      final OgsHttp client = http ?? ref.read(ogsHttpProvider);
      await client.delete('/api/v1/me/challenges/$challengeId');
    } on Object {
      // Already accepted or gone.
    }
  }

  void _stop() {
    _pendingChallenge = null;
    _keepalive?.cancel();
    _timeout?.cancel();
    _keepalive = null;
    _timeout = null;
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    _subscriptions.clear();
  }
}

/// The OGS web client messages for the `rejection_code`s gtp2ogs sends.
String? rejectionMessage(Map<String, dynamic>? details) => switch (details?['rejection_code']) {
  'blacklisted' => 'The operator of this bot will not let you play against it.',
  'board_size_not_square' => 'This bot only plays on square boards.',
  'board_size_not_allowed' => 'This bot does not play on this board size.',
  'handicap_not_allowed' => 'This bot does not play handicap games.',
  'unranked_not_allowed' => 'This bot only plays rated games.',
  'ranked_not_allowed' => 'This bot only plays unrated games.',
  'blitz_not_allowed' => 'This bot does not play blitz games.',
  'too_many_blitz_games' => 'This bot is playing too many blitz games right now. Try again later.',
  'live_not_allowed' => 'This bot does not play live games.',
  'too_many_live_games' => 'This bot is playing too many live games right now. Try again later.',
  'correspondence_not_allowed' => 'This bot does not play correspondence games.',
  'too_many_correspondence_games' =>
    'This bot is playing too many correspondence games right now. Try again later.',
  'time_control_system_not_allowed' => 'This bot does not play with this clock.',
  'time_increment_out_of_range' ||
  'period_time_out_of_range' ||
  'periods_out_of_range' ||
  'main_time_out_of_range' ||
  'max_time_out_of_range' ||
  'per_move_time_out_of_range' => 'This bot does not play with these times.',
  'player_rank_out_of_range' => 'This bot does not play rated games with players of your rank.',
  'not_accepting_new_challenges' => 'This bot is not taking new games right now.',
  'too_many_games_for_player' => 'You are already playing this bot. Finish that game first.',
  'komi_out_of_range' => 'This bot does not play with this komi.',
  _ => null,
};

/// The settings of the last game against a bot, saved on the device.
@immutable
class BotGameSettings {
  const BotGameSettings({
    this.size = 9,
    this.speed = GameSpeed.rapid,
    this.system = ClockSystem.fischer,
    this.ranked = false,
    this.handicap = false,
    this.botId,
  });

  final int size;

  /// Blitz, rapid or live: bots are played in real time.
  final GameSpeed speed;
  final ClockSystem system;
  final bool ranked;
  final bool handicap;
  final int? botId;

  BotClock get clock => BotClock(size, speed, system);

  BotGameOptions options({double? playerRanking}) => BotGameOptions(
    size: size,
    clock: clock,
    ranked: ranked,
    handicap: handicap,
    playerRanking: playerRanking,
  );

  BotGameSettings copyWith({
    int? size,
    GameSpeed? speed,
    ClockSystem? system,
    bool? ranked,
    bool? handicap,
    int? botId,
  }) => BotGameSettings(
    size: size ?? this.size,
    speed: speed ?? this.speed,
    system: system ?? this.system,
    ranked: ranked ?? this.ranked,
    handicap: handicap ?? this.handicap,
    botId: botId ?? this.botId,
  );
}

/// The speeds offered against bots.
const botSpeeds = [GameSpeed.blitz, GameSpeed.rapid, GameSpeed.live];

final botGameSettingsProvider = NotifierProvider<BotGameSettingsController, BotGameSettings>(
  BotGameSettingsController.new,
);

class BotGameSettingsController extends Notifier<BotGameSettings> {
  static const _prefix = 'bot.';

  @override
  BotGameSettings build() {
    final p = ref.watch(sharedPreferencesProvider);
    T byName<T extends Enum>(List<T> values, String key, T fallback) =>
        values.where((v) => v.name == p.getString('$_prefix$key')).firstOrNull ?? fallback;
    const d = BotGameSettings();
    return BotGameSettings(
      size: p.getInt('${_prefix}size') ?? d.size,
      speed: byName(botSpeeds, 'speed', d.speed),
      system: byName(ClockSystem.values, 'system', d.system),
      ranked: p.getBool('${_prefix}ranked') ?? d.ranked,
      handicap: p.getBool('${_prefix}handicap') ?? d.handicap,
      botId: p.getInt('${_prefix}id'),
    );
  }

  Future<void> update(BotGameSettings settings) async {
    state = settings;
    final p = ref.read(sharedPreferencesProvider);
    await Future.wait([
      p.setInt('${_prefix}size', settings.size),
      p.setString('${_prefix}speed', settings.speed.name),
      p.setString('${_prefix}system', settings.system.name),
      p.setBool('${_prefix}ranked', settings.ranked),
      p.setBool('${_prefix}handicap', settings.handicap),
      if (settings.botId case final id?) p.setInt('${_prefix}id', id),
    ]);
  }
}
