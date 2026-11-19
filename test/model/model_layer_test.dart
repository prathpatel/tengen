import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The model layer must not depend on the UI (same rule as the lichess app).
void main() {
  test('lib/src/model does not import view/ or widgets/', () {
    final offenders = <String>[
      for (final file in Directory('lib/src/model').listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.dart'))
          for (final line in file.readAsLinesSync())
            if (RegExp("^import 'package:tengen/src/(view|widgets)/").hasMatch(line))
              '${file.path}: $line',
    ];
    expect(offenders, isEmpty);
  });
}
