import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The launcher icons. On Android, the vector adaptive icon of GoGame (see the icon notes in
/// pubspec.yaml). `dart run flutter_launcher_icons` with Android enabled would replace it.
void main() {
  const res = 'android/app/src/main/res';

  test('the adaptive icon is drawn from the vector drawables', () {
    for (final name in ['ic_launcher', 'ic_launcher_round']) {
      final xml = File('$res/mipmap-anydpi-v26/$name.xml').readAsStringSync();
      expect(xml, contains('<background android:drawable="@drawable/ic_launcher_background"/>'));
      expect(xml, contains('<foreground android:drawable="@drawable/ic_launcher_foreground"/>'));
      expect(xml, contains('<monochrome android:drawable="@drawable/ic_launcher_foreground"/>'));
    }
    expect(
      File('$res/drawable/ic_launcher_background.xml').readAsStringSync(),
      contains('#CFA976'),
    );
    expect(
      File('$res/drawable/ic_launcher_foreground.xml').readAsStringSync(),
      contains('<vector'),
    );
  });

  test('no PNG foreground hides the vector one', () {
    // Android prefers a density specific PNG to the vector of the same name.
    final pngs = Directory(res)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('ic_launcher_foreground.png'))
        .map((f) => f.path);
    expect(pngs, isEmpty);
  });

  test('the iOS project keeps its asset catalog setting', () {
    // flutter_launcher_icons 0.14 rewrites this setting to `AppIcon`, which is not a valid value.
    final project = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(project, isNot(contains('GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = AppIcon')));
  });

  test('the icon helper leaves Android alone', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final config = pubspec.substring(pubspec.indexOf('\nflutter_launcher_icons:'));
    expect(config, contains('\n  android: false\n'));
  });
}
