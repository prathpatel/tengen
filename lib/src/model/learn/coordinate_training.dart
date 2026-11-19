import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tengen/src/model/settings/preferences.dart';

/// Best scores of the coordinate training, by board size.
final coordinateBestProvider = NotifierProvider<CoordinateBestController, Map<int, int>>(
  CoordinateBestController.new,
);

class CoordinateBestController extends Notifier<Map<int, int>> {
  static String _key(int size) => 'learn.coordinates.best.$size';

  @override
  Map<int, int> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return {
      for (final size in const [9, 13, 19]) size: ?prefs.getInt(_key(size)),
    };
  }

  /// Records a score; returns true when it is a new best.
  Future<bool> record(int size, int score) async {
    if (score <= (state[size] ?? 0)) return false;
    state = {...state, size: score};
    await ref.read(sharedPreferencesProvider).setInt(_key(size), score);
    return true;
  }
}
