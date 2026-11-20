import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:tengen/src/model/ogs/ogs_socket_provider.dart';
import 'package:tengen/src/model/ogs/user.dart';
import 'package:tengen/src/model/online_game/automatch_controller.dart';
import 'package:tengen/src/utils/json.dart';

/// A computer player connected to OGS (through gtp2ogs: KataGo, GnuGo, Fuego and others), as in
/// the `active-bots` event of the OGS realtime server.
@immutable
class OgsBot {
  const OgsBot({
    required this.id,
    required this.username,
    required this.config,
    this.iconUrl,
    this.ranking,
  });

  factory OgsBot.fromJson(Map<String, dynamic> json) => OgsBot(
    id: asInt(json['id']) ?? 0,
    username: json['username'] as String? ?? '?',
    iconUrl: json['icon-url'] as String? ?? json['icon'] as String?,
    ranking: asDouble(json['ranking']),
    config: BotConfig.fromJson(asMap(json['config']) ?? const {}),
  );

  final int id;
  final String username;
  final String? iconUrl;

  /// The OGS rank number (30 is 1d).
  final double? ranking;
  final BotConfig config;

  String get rankLabel => ranking == null ? '?' : rankLabelFor(ranking!);

  /// The strength groups of the OGS "Play computer" dialog.
  BotCategory get category => BotCategory.of(ranking);

  /// Whether the bot runs KataGo, as far as its name tells.
  bool get isKataGo => username.toLowerCase().contains('kata');

  @override
  bool operator ==(Object other) => other is OgsBot && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

enum BotCategory {
  beginner('Beginner'),
  intermediate('Intermediate'),
  advanced('Advanced');

  const BotCategory(this.label);

  final String label;

  /// As on OGS: up to 20k is beginner, up to 6k intermediate.
  static BotCategory of(double? ranking) {
    final r = ranking ?? 0;
    if (r <= 10) return beginner;
    if (r <= 25) return intermediate;
    return advanced;
  }
}

typedef Range = (num, num);

/// The game settings a bot accepts (gtp2ogs config, versions 1 and 2).
@immutable
class BotConfig {
  const BotConfig({
    this.version = 0,
    this.hidden = false,
    this.boardSizes,
    this.timeControlSystems = const {},
    this.speedSettings = const {},
    this.allowRanked = false,
    this.allowUnranked = false,
    this.rankRange,
    this.allowRankedHandicap = false,
    this.allowUnrankedHandicap = false,
    this.declinesChallenges = false,
  });

  factory BotConfig.fromJson(Map<String, dynamic> json) {
    Range? range(Object? v) => switch (asList(v)) {
      [final num low, final num high] => (low, high),
      _ => null,
    };

    final rank = asList(json['allowed_rank_range']);
    return BotConfig(
      version: asInt(json['_config_version']) ?? 0,
      hidden: json['hidden'] == true,
      boardSizes: json['allowed_board_sizes'],
      timeControlSystems: {for (final s in asList(json['allowed_time_control_systems'])) '$s'},
      speedSettings: {
        for (final speed in GameSpeed.values)
          if (asMap(json['allowed_${speed.name}_settings']) case final settings?)
            speed: {
              for (final MapEntry(:key, :value) in settings.entries)
                if (asMap(value) case final ranges?)
                  key: {for (final r in ranges.entries) r.key: ?range(r.value)},
            },
      },
      allowRanked: json['allow_ranked'] == true,
      allowUnranked: json['allow_unranked'] == true,
      rankRange: rank.length == 2 ? ('${rank[0]}', '${rank[1]}') : null,
      allowRankedHandicap: json['allow_ranked_handicap'] == true,
      allowUnrankedHandicap: json['allow_unranked_handicap'] == true,
      declinesChallenges: json['decline_new_challenges'] == true,
    );
  }

  /// 0 when the bot has no configuration.
  final int version;
  final bool hidden;

  /// As sent: a list of sizes, a size, `all`, `square`, or width and height ranges.
  final Object? boardSizes;
  final Set<String> timeControlSystems;

  /// For each speed, for each clock system, the accepted ranges, e.g.
  /// `{blitz: {fischer: {max_time_range: (3, 3600), ...}}}`.
  final Map<GameSpeed, Map<String, Map<String, Range>>> speedSettings;
  final bool allowRanked;
  final bool allowUnranked;
  final (String, String)? rankRange;
  final bool allowRankedHandicap;
  final bool allowUnrankedHandicap;
  final bool declinesChallenges;
}

/// The clock of a game against a bot: the OGS quick match times (`SPEED_OPTIONS`), with the
/// Fischer maximum of the OGS "Play computer" button (ten times the initial time).
@immutable
class BotClock {
  const BotClock._(this.speed, this.system, this.values);

  factory BotClock(int size, GameSpeed speed, ClockSystem system) {
    final s = size <= 9 ? 9 : (size <= 13 ? 13 : 19);
    if (system == ClockSystem.fischer) {
      final (initial, increment) = switch ((s, speed)) {
        (_, GameSpeed.blitz) => (30, 5),
        (9, GameSpeed.rapid) => (120, 7),
        (13, GameSpeed.rapid) => (180, 7),
        (_, GameSpeed.rapid) => (300, 7),
        (9, GameSpeed.live) => (180, 10),
        (13, GameSpeed.live) => (300, 10),
        (_, GameSpeed.live) => (600, 10),
        (_, GameSpeed.correspondence) => (86400 * 3, 86400),
      };
      return BotClock._(speed, system, {
        'initial_time': initial,
        'time_increment': increment,
        'max_time': initial * 10,
      });
    }
    final main = switch ((s, speed)) {
      (_, GameSpeed.blitz) => 30,
      (9, GameSpeed.rapid) => 120,
      (13, GameSpeed.rapid) => 180,
      (_, GameSpeed.rapid) => 300,
      (9, GameSpeed.live) => 300,
      (13, GameSpeed.live) => 600,
      (_, _) => 1200,
    };
    return BotClock._(speed, system, {
      'main_time': main,
      'periods': 5,
      'period_time': speed == GameSpeed.blitz ? 10 : 30,
    });
  }

  final GameSpeed speed;
  final ClockSystem system;
  final Map<String, int> values;

  String get systemName => system == ClockSystem.fischer ? 'fischer' : 'byoyomi';

  BotClock withSpeed(GameSpeed speed) => BotClock._(speed, system, values);

  /// The `time_control_parameters` of a challenge.
  Map<String, Object?> toJson() => {
    'system': systemName,
    'time_control': systemName,
    'speed': speed.name,
    ...values,
    'pause_on_weekends': false,
  };

  @override
  bool operator ==(Object other) =>
      other is BotClock &&
      other.speed == speed &&
      other.system == system &&
      other.values.toString() == values.toString();

  @override
  int get hashCode => Object.hash(speed, system, values.toString());
}

/// The settings of a game against a bot.
@immutable
class BotGameOptions {
  const BotGameOptions({
    required this.size,
    required this.clock,
    this.ranked = false,
    this.handicap = false,
    this.playerRanking,
  });

  final int size;
  final BotClock clock;
  final bool ranked;

  /// Automatic handicap from the ranks, rather than an even game.
  final bool handicap;

  /// The rank number of the player, for the rank limits of ranked games.
  final double? playerRanking;

  BotGameOptions copyWith({int? size, BotClock? clock, bool? ranked, bool? handicap}) =>
      BotGameOptions(
        size: size ?? this.size,
        clock: clock ?? this.clock,
        ranked: ranked ?? this.ranked,
        handicap: handicap ?? this.handicap,
        playerRanking: playerRanking,
      );
}

/// Converts a rank such as `25k`, `3d` or `1p` to a rank number, as gtp2ogs does.
double botRankNumber(String rank) {
  final base = int.tryParse(rank.replaceAll(RegExp('[^0-9]'), '')) ?? 0;
  final suffix = rank.isEmpty ? 'k' : rank[rank.length - 1].toLowerCase();
  if (suffix == 'p') return 999;
  if (suffix == 'd') return 29.0 + base;
  return 30.0 - base;
}

String _duration(num seconds) {
  final s = seconds.round();
  if (s >= 86400 && s % 86400 == 0) return '${s ~/ 86400}d';
  if (s >= 3600 && s % 3600 == 0) return '${s ~/ 3600}h';
  if (s >= 60 && s % 60 == 0) return '${s ~/ 60}m';
  return '${s}s';
}

/// Whether [bot] accepts a game with [options]: the clock to use (the speed can change, see
/// below), or why not. The checks are those of the OGS web client (`getAcceptableTimeSetting`),
/// which follow the ones gtp2ogs makes when a challenge arrives.
({BotClock? clock, String? problem}) botAccepts(OgsBot bot, BotGameOptions options) {
  final config = bot.config;
  if (config.version == 0) return (clock: null, problem: 'No configuration');
  if (config.declinesChallenges) return (clock: null, problem: 'Not taking new games');

  final size = options.size;
  final sizes = config.boardSizes;
  switch (sizes) {
    case 'all' || 'square':
      break;
    case final num n when n == 0 || n == size:
      break;
    case final List<Object?> list when list.length == 1 && list.first == 0:
      break;
    case final List<Object?> list:
      if (!list.contains(size)) {
        return (clock: null, problem: 'Plays on ${list.map((s) => '$s×$s').join(', ')}');
      }
    case final Map<String, dynamic> ranges:
      final fits = switch ((asList(ranges['width_range']), asList(ranges['height_range']))) {
        ([final num w0, final num w1], [final num h0, final num h1]) =>
          size >= w0 && size <= w1 && size >= h0 && size <= h1,
        _ => false,
      };
      if (!fits) return (clock: null, problem: 'Does not play on $size×$size');
    default:
      return (clock: null, problem: 'Does not play on $size×$size');
  }

  if (options.ranked && !config.allowRanked) return (clock: null, problem: 'Unrated games only');
  if (!options.ranked && !config.allowUnranked) return (clock: null, problem: 'Rated games only');

  final rankRange = config.rankRange;
  final r = options.playerRanking;
  if (options.ranked && rankRange != null && r != null) {
    final (low, high) = rankRange;
    if (r < botRankNumber(low) || r > botRankNumber(high)) {
      return (clock: null, problem: 'Rated games with $low to $high players only');
    }
  }

  if (options.handicap) {
    if (options.ranked && !config.allowRankedHandicap) {
      return (clock: null, problem: 'No handicap in rated games');
    }
    if (!options.ranked && !config.allowUnrankedHandicap) {
      return (clock: null, problem: 'Even games only');
    }
  }

  final clock = options.clock;
  if (!config.timeControlSystems.contains(clock.systemName)) {
    return (clock: null, problem: 'No ${clock.system.label} clock');
  }

  String? clockProblem(GameSpeed speed) {
    final ranges = config.speedSettings[speed]?[clock.systemName];
    if (ranges == null) return 'Does not play ${clock.speed.label.toLowerCase()} games';
    final checks = switch (clock.system) {
      ClockSystem.fischer => [
        // Version 1 configs check the initial time against the maximum time range.
        if (config.version == 1)
          ('Initial time', 'max_time_range', clock.values['initial_time']!)
        else
          ('Max time', 'max_time_range', clock.values['max_time']!),
        ('Increment', 'time_increment_range', clock.values['time_increment']!),
      ],
      ClockSystem.byoyomi => [
        ('Main time', 'main_time_range', clock.values['main_time']!),
        ('Periods', 'periods_range', clock.values['periods']!),
        ('Period time', 'period_time_range', clock.values['period_time']!),
      ],
    };
    for (final (label, key, value) in checks) {
      final range = ranges[key];
      if (range == null) continue;
      if (value < range.$1 || value > range.$2) {
        final format = key == 'periods_range' ? (num v) => '$v' : _duration;
        return '$label must be ${format(range.$1)} to ${format(range.$2)}';
      }
    }
    return null;
  }

  final problem = clockProblem(clock.speed);
  if (problem == null) return (clock: clock, problem: null);
  // Version 1 bots have no rapid settings: OGS plays rapid games with their live settings.
  if (config.version == 1 && clock.speed == GameSpeed.rapid) {
    if (clockProblem(GameSpeed.live) == null) {
      return (clock: clock.withSpeed(GameSpeed.live), problem: null);
    }
  }
  return (clock: null, problem: problem);
}

/// The bots online now, weakest first, as the OGS server announces them.
final activeBotsProvider = StreamProvider<List<OgsBot>>((ref) async* {
  final socket = ref.watch(ogsSocketProvider);
  List<OgsBot> parse(Object? data) {
    final bots = [
      for (final b in (asMap(data) ?? const <String, dynamic>{}).values)
        if (asMap(b) case final map?) OgsBot.fromJson(map),
    ].where((b) => b.id > 0 && !b.config.hidden).toList();
    bots.sort((a, b) => (a.ranking ?? 0).compareTo(b.ranking ?? 0));
    return bots;
  }

  if (socket.latest('active-bots') case final data?) yield parse(data);
  yield* socket.on('active-bots').map(parse);
});
