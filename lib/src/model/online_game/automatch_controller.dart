import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:tengen/src/model/ogs/ogs_socket_provider.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/utils/json.dart';

/// The speeds of the OGS quick match.
enum GameSpeed {
  blitz('Blitz'),
  rapid('Rapid'),
  live('Live'),
  correspondence('Correspondence');

  const GameSpeed(this.label);

  final String label;

  /// Short label for the quick pairing grid.
  String get shortLabel => this == correspondence ? 'Daily' : label;

  /// Typical game length on OGS (`SPEED_OPTIONS` of the OGS website).
  String estimate(int size) => switch (this) {
    blitz =>
      '~${switch (size) {
        9 => 5,
        13 => 10,
        _ => 15,
      }} min',
    rapid =>
      '~${switch (size) {
        9 => 10,
        13 => 20,
        _ => 25,
      }} min',
    live =>
      '~${switch (size) {
        9 => 15,
        13 => 30,
        _ => 40,
      }} min',
    correspondence => '1 day per move',
  };
}

/// The clock systems offered by the OGS quick match.
enum ClockSystem {
  fischer('Fischer'),
  byoyomi('Byo-yomi');

  const ClockSystem(this.label);

  final String label;
}

/// The OGS quick match handicap options.
enum HandicapMode {
  /// Handicaps between players of different ranks.
  required('Required', 'Handicaps between players with different ranks'),

  /// Handicaps by default, but even games are accepted.
  standard('Standard', 'Handicaps by default, even games accepted'),
  disabled('Disabled', 'Even games only');

  const HandicapMode(this.label, this.description);

  final String label;
  final String description;
}

/// The time control of a quick match, exactly as on OGS (`SPEED_OPTIONS`).
String quickMatchTime(int size, GameSpeed speed, ClockSystem system) {
  if (speed == GameSpeed.correspondence) return '3d + 1d';
  final fischer = system == ClockSystem.fischer;
  return switch ((size, speed)) {
    (_, GameSpeed.blitz) => fischer ? '30s + 5s' : '30s + 5×10s',
    (9, GameSpeed.rapid) => fischer ? '2m + 7s' : '2m + 5×30s',
    (13, GameSpeed.rapid) => fischer ? '3m + 7s' : '3m + 5×30s',
    (_, GameSpeed.rapid) => fischer ? '5m + 7s' : '5m + 5×30s',
    (9, GameSpeed.live) => fischer ? '3m + 10s' : '5m + 5×30s',
    (13, GameSpeed.live) => fischer ? '5m + 10s' : '10m + 5×30s',
    (_, _) => fischer ? '10m + 10s' : '20m + 5×30s',
  };
}

/// What to look for when asking OGS to find an opponent: the options of the OGS quick match.
@immutable
class AutomatchSettings {
  const AutomatchSettings({
    this.size = 9,
    this.speed = GameSpeed.rapid,
    this.system = ClockSystem.fischer,
    this.flexibleClock = true,
    this.handicap = HandicapMode.standard,
    this.lowerRankDiff = 3,
    this.upperRankDiff = 3,
  });

  /// 9, 13 or 19.
  final int size;
  final GameSpeed speed;
  final ClockSystem system;

  /// Also accept the other clock system ("Flexible" on OGS; "Exact" when false).
  final bool flexibleClock;
  final HandicapMode handicap;

  /// How many ranks below and above the player the opponent may be.
  final int lowerRankDiff;
  final int upperRankDiff;

  /// Correspondence games only use Fischer time on OGS.
  ClockSystem get effectiveSystem =>
      speed == GameSpeed.correspondence ? ClockSystem.fischer : system;

  String get timeLabel => quickMatchTime(size, speed, effectiveSystem);

  /// The `automatch/find_match` preferences, built like the OGS quick match page does. OGS
  /// automatch games always use Japanese rules.
  Map<String, Object?> toPreferences(String uuid) => {
    'uuid': uuid,
    'size_speed_options': [
      {'size': '${size}x$size', 'speed': speed.name, 'system': effectiveSystem.name},
      if (flexibleClock && speed != GameSpeed.correspondence)
        {
          'size': '${size}x$size',
          'speed': speed.name,
          'system':
              (effectiveSystem == ClockSystem.fischer ? ClockSystem.byoyomi : ClockSystem.fischer)
                  .name,
        },
    ],
    'lower_rank_diff': lowerRankDiff,
    'upper_rank_diff': upperRankDiff,
    'rules': {'condition': 'required', 'value': 'japanese'},
    'handicap': {
      'condition': handicap == HandicapMode.standard ? 'preferred' : 'required',
      'value': handicap == HandicapMode.disabled ? 'disabled' : 'enabled',
    },
  };

  AutomatchSettings copyWith({
    int? size,
    GameSpeed? speed,
    ClockSystem? system,
    bool? flexibleClock,
    HandicapMode? handicap,
    int? lowerRankDiff,
    int? upperRankDiff,
  }) => AutomatchSettings(
    size: size ?? this.size,
    speed: speed ?? this.speed,
    system: system ?? this.system,
    flexibleClock: flexibleClock ?? this.flexibleClock,
    handicap: handicap ?? this.handicap,
    lowerRankDiff: lowerRankDiff ?? this.lowerRankDiff,
    upperRankDiff: upperRankDiff ?? this.upperRankDiff,
  );
}

/// The quick match options last used, saved on the device (like the OGS website preferences).
final automatchSettingsProvider = NotifierProvider<AutomatchSettingsController, AutomatchSettings>(
  AutomatchSettingsController.new,
);

class AutomatchSettingsController extends Notifier<AutomatchSettings> {
  static const _prefix = 'automatch.';

  @override
  AutomatchSettings build() {
    final p = ref.watch(sharedPreferencesProvider);
    T byName<T extends Enum>(List<T> values, String key, T fallback) =>
        values.where((v) => v.name == p.getString('$_prefix$key')).firstOrNull ?? fallback;
    const d = AutomatchSettings();
    return AutomatchSettings(
      size: p.getInt('${_prefix}size') ?? d.size,
      speed: byName(GameSpeed.values, 'speed', d.speed),
      system: byName(ClockSystem.values, 'system', d.system),
      flexibleClock: p.getBool('${_prefix}flexible') ?? d.flexibleClock,
      handicap: byName(HandicapMode.values, 'handicap', d.handicap),
      lowerRankDiff: p.getInt('${_prefix}lower') ?? d.lowerRankDiff,
      upperRankDiff: p.getInt('${_prefix}upper') ?? d.upperRankDiff,
    );
  }

  Future<void> update(AutomatchSettings settings) async {
    state = settings;
    final p = ref.read(sharedPreferencesProvider);
    await Future.wait([
      p.setInt('${_prefix}size', settings.size),
      p.setString('${_prefix}speed', settings.speed.name),
      p.setString('${_prefix}system', settings.system.name),
      p.setBool('${_prefix}flexible', settings.flexibleClock),
      p.setString('${_prefix}handicap', settings.handicap.name),
      p.setInt('${_prefix}lower', settings.lowerRankDiff),
      p.setInt('${_prefix}upper', settings.upperRankDiff),
    ]);
  }
}

sealed class AutomatchState {
  const AutomatchState();
}

class AutomatchIdle extends AutomatchState {
  const AutomatchIdle();
}

class AutomatchSearching extends AutomatchState {
  const AutomatchSearching(this.uuid, this.settings);

  final String uuid;
  final AutomatchSettings settings;
}

class AutomatchFound extends AutomatchState {
  const AutomatchFound(this.gameId);

  final int gameId;
}

final automatchProvider = NotifierProvider<AutomatchController, AutomatchState>(
  AutomatchController.new,
);

/// Finds an opponent with the OGS automatch system.
class AutomatchController extends Notifier<AutomatchState> {
  @override
  AutomatchState build() {
    final socket = ref.watch(ogsSocketProvider);
    final sub = socket.on('automatch/start').listen((data) {
      final json = asMap(data) ?? const {};
      final current = state;
      if (current is AutomatchSearching && json['uuid'] == current.uuid) {
        final gameId = asInt(json['game_id']);
        if (gameId != null) state = AutomatchFound(gameId);
      }
    });
    final cancelSub = socket.on('automatch/cancel').listen((data) {
      final json = asMap(data) ?? const {};
      final current = state;
      if (current is AutomatchSearching && (json['uuid'] == null || json['uuid'] == current.uuid)) {
        state = const AutomatchIdle();
      }
    });
    ref.onDispose(() {
      sub.cancel();
      cancelSub.cancel();
    });
    return const AutomatchIdle();
  }

  void find(AutomatchSettings settings) {
    final uuid = _uuidV4();
    ref.read(ogsSocketProvider).send('automatch/find_match', settings.toPreferences(uuid));
    state = AutomatchSearching(uuid, settings);
  }

  void cancel() {
    final current = state;
    if (current is AutomatchSearching) {
      ref.read(ogsSocketProvider).send('automatch/cancel', {'uuid': current.uuid});
    }
    state = const AutomatchIdle();
  }

  /// Call once the found game has been opened.
  void reset() => state = const AutomatchIdle();
}

String _uuidV4() {
  final r = math.Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
