import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Whether the app runs under `flutter test`, which sets FLUTTER_TEST in the environment of the
/// test process. Endless decorative animations are off there, so that tests can settle.
final bool inFlutterTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
