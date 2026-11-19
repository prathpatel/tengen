import 'package:flutter_test/flutter_test.dart';
import 'package:tengen/src/model/online_game/automatch_controller.dart';

import '../../fakes.dart';

void main() {
  test('preferences are built like the OGS quick match page', () {
    const settings = AutomatchSettings(size: 13, speed: GameSpeed.live);
    expect(settings.toPreferences('u1'), {
      'uuid': 'u1',
      'size_speed_options': [
        {'size': '13x13', 'speed': 'live', 'system': 'fischer'},
        {'size': '13x13', 'speed': 'live', 'system': 'byoyomi'},
      ],
      'lower_rank_diff': 3,
      'upper_rank_diff': 3,
      'rules': {'condition': 'required', 'value': 'japanese'},
      'handicap': {'condition': 'preferred', 'value': 'enabled'},
    });
  });

  test('exact clock, handicap modes and correspondence', () {
    final exact = const AutomatchSettings(
      system: ClockSystem.byoyomi,
      flexibleClock: false,
      handicap: HandicapMode.disabled,
    ).toPreferences('u');
    expect(exact['size_speed_options'], [
      {'size': '9x9', 'speed': 'rapid', 'system': 'byoyomi'},
    ]);
    expect(exact['handicap'], {'condition': 'required', 'value': 'disabled'});
    expect(
      const AutomatchSettings(handicap: HandicapMode.required).toPreferences('u')['handicap'],
      {'condition': 'required', 'value': 'enabled'},
    );
    // Correspondence is Fischer only, even with byo-yomi selected.
    final corr = const AutomatchSettings(
      speed: GameSpeed.correspondence,
      system: ClockSystem.byoyomi,
    ).toPreferences('u');
    expect(corr['size_speed_options'], [
      {'size': '9x9', 'speed': 'correspondence', 'system': 'fischer'},
    ]);
  });

  test('time controls match the OGS speed options', () {
    expect(quickMatchTime(9, GameSpeed.blitz, ClockSystem.fischer), '30s + 5s');
    expect(quickMatchTime(9, GameSpeed.blitz, ClockSystem.byoyomi), '30s + 5×10s');
    expect(quickMatchTime(9, GameSpeed.rapid, ClockSystem.fischer), '2m + 7s');
    expect(quickMatchTime(13, GameSpeed.rapid, ClockSystem.byoyomi), '3m + 5×30s');
    expect(quickMatchTime(19, GameSpeed.rapid, ClockSystem.fischer), '5m + 7s');
    expect(quickMatchTime(9, GameSpeed.live, ClockSystem.byoyomi), '5m + 5×30s');
    expect(quickMatchTime(13, GameSpeed.live, ClockSystem.fischer), '5m + 10s');
    expect(quickMatchTime(19, GameSpeed.live, ClockSystem.byoyomi), '20m + 5×30s');
    expect(quickMatchTime(19, GameSpeed.correspondence, ClockSystem.byoyomi), '3d + 1d');
  });

  test('settings are saved and restored', () async {
    final (:container, sockets: _) = await makeContainer();
    addTearDown(container.dispose);
    expect(container.read(automatchSettingsProvider), isA<AutomatchSettings>());
    await container
        .read(automatchSettingsProvider.notifier)
        .update(
          const AutomatchSettings(
            size: 19,
            speed: GameSpeed.blitz,
            system: ClockSystem.byoyomi,
            flexibleClock: false,
            handicap: HandicapMode.disabled,
            lowerRankDiff: 1,
            upperRankDiff: 5,
          ),
        );
    container.invalidate(automatchSettingsProvider);
    final restored = container.read(automatchSettingsProvider);
    expect(restored.size, 19);
    expect(restored.speed, GameSpeed.blitz);
    expect(restored.system, ClockSystem.byoyomi);
    expect(restored.flexibleClock, isFalse);
    expect(restored.handicap, HandicapMode.disabled);
    expect((restored.lowerRankDiff, restored.upperRankDiff), (1, 5));
  });
}
