import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:tengen/src/model/go/rules.dart';
import 'package:tengen/src/model/ogs/ogs_socket_provider.dart';
import 'package:tengen/src/utils/json.dart';

enum GameSpeed {
  blitz('Blitz', '~5 minutes'),
  rapid('Rapid', '~10 minutes'),
  live('Live', '~20 minutes'),
  correspondence('Correspondence', '~1 day per move');

  const GameSpeed(this.label, this.description);

  final String label;
  final String description;
}

/// What to look for when asking OGS to find an opponent.
@immutable
class AutomatchSettings {
  const AutomatchSettings({
    this.size = 19,
    this.speed = GameSpeed.rapid,
    this.ruleset = Ruleset.japanese,
    this.handicap = true,
  });

  final int size;
  final GameSpeed speed;
  final Ruleset ruleset;
  final bool handicap;

  /// The `automatch/find_match` preferences, as built by the OGS quick match page.
  Map<String, Object?> toPreferences(String uuid) => {
    'uuid': uuid,
    'size_speed_options': [
      for (final system in ['byoyomi', 'fischer'])
        {'size': '${size}x$size', 'speed': speed.name, 'system': system},
    ],
    'lower_rank_diff': 3,
    'upper_rank_diff': 3,
    'rules': {'condition': 'preferred', 'value': ruleset.name},
    'handicap': {'condition': 'preferred', 'value': handicap ? 'enabled' : 'disabled'},
  };

  AutomatchSettings copyWith({int? size, GameSpeed? speed, Ruleset? ruleset, bool? handicap}) =>
      AutomatchSettings(
        size: size ?? this.size,
        speed: speed ?? this.speed,
        ruleset: ruleset ?? this.ruleset,
        handicap: handicap ?? this.handicap,
      );
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
