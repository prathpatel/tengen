import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/utils/json.dart';

/// OGS time control settings (`time_control` of the game data).
@immutable
class OgsTimeControl {
  const OgsTimeControl({
    required this.system,
    this.speed,
    this.mainTime,
    this.periodTime,
    this.periods,
    this.increment,
    this.maxTime,
    this.stonesPerPeriod,
    this.perMove,
  });

  factory OgsTimeControl.fromJson(Map<String, dynamic> json) {
    final system = (json['system'] ?? json['time_control']) as String? ?? 'none';
    return OgsTimeControl(
      system: system,
      speed: json['speed'] as String?,
      mainTime: _seconds(json['main_time'] ?? json['initial_time'] ?? json['total_time']),
      periodTime: _seconds(json['period_time']),
      periods: asInt(json['periods']),
      increment: _seconds(json['time_increment']),
      maxTime: _seconds(json['max_time']),
      stonesPerPeriod: asInt(json['stones_per_period']),
      perMove: _seconds(json['per_move']),
    );
  }

  static Duration? _seconds(Object? v) {
    final s = asDouble(v);
    return s == null ? null : Duration(milliseconds: (s * 1000).round());
  }

  /// One of `fischer`, `byoyomi`, `canadian`, `simple`, `absolute`, `none`.
  final String system;

  /// `blitz`, `rapid`, `live` or `correspondence`.
  final String? speed;
  final Duration? mainTime;
  final Duration? periodTime;
  final int? periods;
  final Duration? increment;
  final Duration? maxTime;
  final int? stonesPerPeriod;
  final Duration? perMove;

  /// Short description, e.g. `10m + 5×30s` or `5m + 10s`.
  String get description {
    String d(Duration? x) => x == null ? '?' : formatShortDuration(x);
    return switch (system) {
      'byoyomi' => '${d(mainTime)} + $periods×${d(periodTime)}',
      'fischer' => '${d(mainTime)} + ${d(increment)}',
      'canadian' => '${d(mainTime)} + ${d(periodTime)}/$stonesPerPeriod',
      'simple' => '${d(perMove)} / move',
      'absolute' => d(mainTime),
      _ => 'No clock',
    };
  }
}

/// The clock state of one player, as sent by OGS.
@immutable
class PlayerClock {
  const PlayerClock({
    required this.thinkingTime,
    this.periods,
    this.periodTime,
    this.movesLeft,
    this.blockTime,
  });

  /// Parses `black_time`/`white_time`. Simple time sends a bare number of milliseconds.
  factory PlayerClock.fromJson(Object? json) {
    if (json is num) return PlayerClock(thinkingTime: Duration(milliseconds: json.round()));
    final map = asMap(json) ?? const {};
    Duration? secs(Object? v) {
      final s = asDouble(v);
      return s == null ? null : Duration(milliseconds: (s * 1000).round());
    }

    return PlayerClock(
      thinkingTime: secs(map['thinking_time']) ?? Duration.zero,
      periods: asInt(map['periods']),
      periodTime: secs(map['period_time']),
      movesLeft: asInt(map['moves_left']),
      blockTime: secs(map['block_time']),
    );
  }

  final Duration thinkingTime;
  final int? periods;
  final Duration? periodTime;
  final int? movesLeft;
  final Duration? blockTime;

  /// The clock after [elapsed] time has been spent on it.
  ClockReading read(Duration elapsed) {
    final main = thinkingTime - elapsed;
    if (main > Duration.zero) {
      return ClockReading(
        main: main,
        periods: periods,
        periodTime: periodTime,
        movesLeft: movesLeft,
        blockTime: blockTime,
      );
    }
    final overflow = -main;
    final pt = periodTime;
    final p = periods;
    if (pt != null && pt > Duration.zero && p != null) {
      // Byo-yomi: each full period spent is lost.
      final used = overflow.inMilliseconds ~/ pt.inMilliseconds;
      final left = p - used;
      if (left <= 0) return const ClockReading(main: Duration.zero, periods: 0, flagged: true);
      return ClockReading(
        main: Duration.zero,
        periods: left,
        periodTime: Duration(
          milliseconds: pt.inMilliseconds - overflow.inMilliseconds % pt.inMilliseconds,
        ),
      );
    }
    final bt = blockTime;
    if (bt != null) {
      // Canadian: a block of time for a number of moves.
      final block = bt - overflow;
      return ClockReading(
        main: Duration.zero,
        blockTime: block > Duration.zero ? block : Duration.zero,
        movesLeft: movesLeft,
        flagged: block <= Duration.zero,
      );
    }
    return const ClockReading(main: Duration.zero, flagged: true);
  }
}

/// What a clock shows at a given time.
@immutable
class ClockReading {
  const ClockReading({
    required this.main,
    this.periods,
    this.periodTime,
    this.movesLeft,
    this.blockTime,
    this.flagged = false,
  });

  final Duration main;
  final int? periods;
  final Duration? periodTime;
  final int? movesLeft;
  final Duration? blockTime;
  final bool flagged;

  /// Whether the main time is over and the player is in overtime.
  bool get inOvertime => main <= Duration.zero && !flagged;

  /// The time that matters most right now, used for low time warnings.
  Duration get critical => inOvertime ? (periodTime ?? blockTime ?? Duration.zero) : main;

  String get label {
    if (flagged) return '0:00';
    final buffer = StringBuffer();
    if (main > Duration.zero) {
      buffer.write(formatClock(main));
      if (periods != null && periodTime != null) {
        buffer.write(' (${periods!}×${formatShortDuration(periodTime!)})');
      } else if (blockTime != null && movesLeft != null) {
        buffer.write(' + ${formatShortDuration(blockTime!)}/${movesLeft!}');
      }
    } else if (periodTime != null) {
      buffer.write('${formatClock(periodTime!)} (${periods ?? 0})');
    } else if (blockTime != null) {
      buffer.write('${formatClock(blockTime!)}/${movesLeft ?? 0}');
    } else {
      buffer.write('0:00');
    }
    return buffer.toString();
  }
}

/// The game clock (`clock` of the game data, or a `game/<id>/clock` event).
@immutable
class OgsClock {
  const OgsClock({
    required this.currentPlayerId,
    required this.blackPlayerId,
    required this.whitePlayerId,
    required this.lastMove,
    required this.black,
    required this.white,
    this.serverNow,
    this.pausedSince,
    this.expiration,
  });

  factory OgsClock.fromJson(Map<String, dynamic> json) {
    DateTime? time(Object? v) {
      final ms = asInt(v);
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    }

    return OgsClock(
      currentPlayerId: asInt(json['current_player']) ?? 0,
      blackPlayerId: asInt(json['black_player_id']) ?? 0,
      whitePlayerId: asInt(json['white_player_id']) ?? 0,
      lastMove: time(json['last_move']) ?? DateTime.now(),
      black: PlayerClock.fromJson(json['black_time']),
      white: PlayerClock.fromJson(json['white_time']),
      serverNow: time(json['now']),
      pausedSince: json['pause'] is Map && (json['pause'] as Map)['paused'] == true
          ? time(json['paused_since'])
          : null,
      expiration: time(json['expiration']),
    );
  }

  final int currentPlayerId;
  final int blackPlayerId;
  final int whitePlayerId;
  final DateTime lastMove;
  final PlayerClock black;
  final PlayerClock white;
  final DateTime? serverNow;
  final DateTime? pausedSince;
  final DateTime? expiration;

  StoneColor? get currentColor => currentPlayerId == blackPlayerId
      ? StoneColor.black
      : (currentPlayerId == whitePlayerId ? StoneColor.white : null);

  /// Reads the clock of [color] at server time [now]: only the player to move is running.
  ClockReading read(StoneColor color, DateTime now) {
    final clock = color == StoneColor.black ? black : white;
    final running = currentColor == color && pausedSince == null;
    final elapsed = running ? now.difference(lastMove) : Duration.zero;
    return clock.read(elapsed.isNegative ? Duration.zero : elapsed);
  }
}

/// `1:05:03`, `4:59` or `0:09`.
String formatClock(Duration d) {
  final total = math.max(0, d.inSeconds);
  final days = total ~/ 86400;
  if (days > 0) return '${days}d ${(total % 86400) ~/ 3600}h';
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = (total % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// `30s`, `5m`, `1h30m`, `3d`.
String formatShortDuration(Duration d) {
  final s = d.inSeconds;
  if (s % 86400 == 0 && s >= 86400) return '${s ~/ 86400}d';
  if (s >= 3600) {
    final m = (s % 3600) ~/ 60;
    return m == 0 ? '${s ~/ 3600}h' : '${s ~/ 3600}h${m}m';
  }
  if (s >= 60) {
    final rest = s % 60;
    return rest == 0 ? '${s ~/ 60}m' : '${s ~/ 60}m${rest}s';
  }
  return '${s}s';
}
