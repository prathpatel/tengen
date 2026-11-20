import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tengen/src/model/settings/preferences.dart';

import '../../fakes.dart';

void main() {
  test('defaults to the OGS look: Kaya, Slate and Shell', () async {
    final (:container, sockets: _) = await makeContainer();
    addTearDown(container.dispose);
    final prefs = container.read(preferencesProvider);
    expect(
      (prefs.boardTheme, prefs.blackStones, prefs.whiteStones),
      (BoardTheme.kaya, StoneTheme.slate, StoneTheme.shell),
    );
  });

  test('saves the board and stone themes', () async {
    final (:container, sockets: _) = await makeContainer();
    addTearDown(container.dispose);
    final controller = container.read(preferencesProvider.notifier);
    await controller.setBoardTheme(BoardTheme.persimmon);
    await controller.setBlackStones(StoneTheme.glass);
    await controller.setWhiteStones(StoneTheme.badukTV);

    final stored = container.read(sharedPreferencesProvider);
    expect(
      [
        stored.getString('prefs.boardTheme'),
        stored.getString('prefs.blackStones'),
        stored.getString('prefs.whiteStones'),
      ],
      ['persimmon', 'glass', 'badukTV'],
    );

    // Read back by the next start of the app.
    final (container: again, sockets: _) = await makeContainer(
      prefs: {for (final k in stored.getKeys()) k: stored.get(k)!},
    );
    addTearDown(again.dispose);
    final prefs = again.read(preferencesProvider);
    expect(
      (prefs.boardTheme, prefs.blackStones, prefs.whiteStones),
      (BoardTheme.persimmon, StoneTheme.glass, StoneTheme.badukTV),
    );
  });

  test('keeps a theme close to the one chosen in earlier versions', () async {
    final (:container, sockets: _) = await makeContainer(
      prefs: {'prefs.boardTheme': 'walnut', 'prefs.whiteStones': 'slate'},
    );
    addTearDown(container.dispose);
    final prefs = container.read(preferencesProvider);
    expect(prefs.boardTheme, BoardTheme.blackWalnut);
    // Slate has no white stones.
    expect(prefs.whiteStones, StoneTheme.shell);
  });

  test('every theme image is in the app assets', () {
    final paths = [
      for (final t in BoardTheme.values) ?t.textureAsset,
      for (final t in StoneTheme.values) ...[?t.imageAsset(true), ?t.imageAsset(false)],
    ];
    expect(paths, isNotEmpty);
    for (final path in paths) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });
}
