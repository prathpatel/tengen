import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:tengen/src/model/go/board.dart';

/// The click of a stone, from the OGS "Floor Goban (deep)" sounds: five takes for each color,
/// one chosen at random as on OGS (`assets/sounds/stones/`).
class StoneSound {
  StoneSound._();

  static final _random = math.Random();
  static final List<AudioPlayer> _pool = [];
  static int _next = 0;

  /// Off in widget tests, where there is no audio plugin.
  static bool enabled = !_inTest;

  // `flutter test` sets FLUTTER_TEST in the environment of the test process.
  static bool get _inTest => !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  /// Told of every click, for tests.
  @visibleForTesting
  static void Function(StoneColor color)? debugOnPlay;

  static void play(StoneColor color) {
    debugOnPlay?.call(color);
    if (!enabled) return;
    unawaited(_play(color));
  }

  static Future<void> _play(StoneColor color) async {
    try {
      if (_pool.isEmpty) {
        for (var i = 0; i < 3; i++) {
          final player = AudioPlayer();
          await player.setPlayerMode(PlayerMode.lowLatency);
          await player.setReleaseMode(ReleaseMode.stop);
          _pool.add(player);
        }
      }
      // A few players, so that quick moves overlap rather than cut each other.
      final player = _pool[_next++ % _pool.length];
      final take = _random.nextInt(5) + 1;
      await player.play(AssetSource('sounds/stones/${color.name}-$take.ogg'));
    } on Object catch (e) {
      debugPrint('StoneSound: $e');
    }
  }
}
