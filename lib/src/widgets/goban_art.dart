import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/settings/preferences.dart';

/// The lighting of a rendered stone, as in goban `rendered_stones.ts` (`RenderOptions`).
@immutable
class StoneLighting {
  const StoneLighting({
    required this.base,
    required this.light,
    required this.ambient,
    required this.hardness,
    required this.diffuseDistance,
    required this.specularDistance,
    this.shellLines = false,
  });

  final Color base;

  /// The direction of the light, not normalized (x right, y down, z towards the viewer).
  final (double, double, double) light;
  final double ambient;
  final int hardness;
  final double diffuseDistance;
  final double specularDistance;
  final bool shellLines;

  String get key =>
      '${base.toARGB32()}-$light-$ambient-$hardness-$diffuseDistance-$specularDistance-$shellLines';

  /// The parameters of the OGS themes. Null for themes that are not rendered (plain, images).
  static StoneLighting? of(StoneTheme theme, StoneColor color) {
    const glassLight = (-4.0, -4.0, 2.0);
    const darkGlass = Color.fromARGB(255, 15, 15, 20);
    if (color == StoneColor.black) {
      return switch (theme) {
        StoneTheme.slate => const StoneLighting(
          base: Color.fromARGB(255, 30, 30, 35),
          light: (-4, -4, 5),
          ambient: 0.85,
          hardness: 17,
          diffuseDistance: 10,
          specularDistance: 8,
        ),
        StoneTheme.glass => const StoneLighting(
          base: darkGlass,
          light: glassLight,
          ambient: 0.85,
          hardness: 30,
          diffuseDistance: 10,
          specularDistance: 10,
        ),
        StoneTheme.wornGlass => const StoneLighting(
          base: darkGlass,
          light: glassLight,
          ambient: 0.85,
          hardness: 20,
          diffuseDistance: 10,
          specularDistance: 10,
        ),
        StoneTheme.night => const StoneLighting(
          base: darkGlass,
          light: glassLight,
          ambient: 0.85,
          hardness: 5,
          diffuseDistance: 10,
          specularDistance: 10,
        ),
        _ => null,
      };
    }
    return switch (theme) {
      StoneTheme.shell => const StoneLighting(
        base: Color.fromARGB(255, 207, 205, 206),
        light: glassLight,
        ambient: 1,
        hardness: 24,
        diffuseDistance: 7,
        specularDistance: 100,
        shellLines: true,
      ),
      StoneTheme.glass => const StoneLighting(
        base: Color.fromARGB(255, 207, 205, 206),
        light: glassLight,
        ambient: 1,
        hardness: 80,
        diffuseDistance: 7,
        specularDistance: 100,
      ),
      StoneTheme.wornGlass => const StoneLighting(
        base: Color.fromARGB(255, 189, 189, 194),
        light: glassLight,
        ambient: 1,
        hardness: 35,
        diffuseDistance: 7,
        specularDistance: 100,
      ),
      StoneTheme.night => const StoneLighting(
        base: Color.fromARGB(255, 100, 100, 100),
        light: glassLight,
        ambient: 1,
        hardness: 13,
        diffuseDistance: 7,
        specularDistance: 100,
      ),
      _ => null,
    };
  }
}

/// Number of shell stones drawn, each with its own lines (OGS also renders ten).
const kShellVariants = 10;

/// Images of the board: OGS textures and stones rendered as on OGS. They are made once,
/// asynchronously; [GobanArt.instance] notifies its listeners when one is ready, and painters
/// draw a simpler version until then.
class GobanArt extends ChangeNotifier {
  GobanArt._();

  static final instance = GobanArt._();

  final _images = <String, ui.Image>{};
  final _pending = <String>{};

  /// An image from the app assets.
  ui.Image? asset(String path) => _get('asset:$path', () async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  });

  /// A stone rendered with [lighting], square, to be clipped to a circle.
  ui.Image? stone(StoneLighting lighting, int variant) => _get(
    'stone:${lighting.key}:${lighting.shellLines ? variant % kShellVariants : 0}',
    () => renderStone(lighting, 1013 * (variant % kShellVariants + 1)),
  );

  ui.Image? _get(String key, Future<ui.Image> Function() make) {
    final image = _images[key];
    if (image != null || _pending.contains(key)) return image;
    _pending.add(key);
    make().then((image) {
      _images[key] = image;
      notifyListeners();
    }, onError: (Object _) {});
    return null;
  }
}

/// The size of the rendered stone images, in pixels.
const _size = 128;

/// Renders a stone as OGS does (goban `preRenderStone`): the base color, clam shell lines for
/// white shell stones, then Phong shading of every pixel.
Future<ui.Image> renderStone(StoneLighting o, int seed) async {
  const radius = _size / 2;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const square = Rect.fromLTWH(0, 0, _size * 1.0, _size * 1.0);
  canvas.drawRect(square, Paint()..color = o.base);
  if (o.shellLines) {
    canvas.clipPath(Path()..addOval(square));
    _paintShellLines(canvas, radius, seed);
  }
  final picture = recorder.endRecording();
  final flat = await picture.toImage(_size, _size);
  picture.dispose();
  final data = await flat.toByteData();
  flat.dispose();
  final pixels = data!.buffer.asUint8List();

  final light = _normalized(o.light);
  final half = _normalized((light.$1, light.$2, light.$3 + 1));
  for (var py = 0; py < _size; py++) {
    for (var px = 0; px < _size; px++) {
      final i = (py * _size + px) * 4;
      final x = px + 0.5 - radius;
      final y = py + 0.5 - radius;
      if (x * x + y * y < (radius + 1) * (radius + 1)) {
        final (r, g, b) = _shade(
          pixels[i],
          pixels[i + 1],
          pixels[i + 2],
          x,
          y,
          radius,
          o,
          light,
          half,
        );
        pixels[i] = r;
        pixels[i + 1] = g;
        pixels[i + 2] = b;
      }
      pixels[i + 3] = 255;
    }
  }
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(pixels, _size, _size, ui.PixelFormat.rgba8888, completer.complete);
  return await completer.future;
}

typedef _Vec = (double, double, double);

_Vec _normalized(_Vec v) {
  final l = math.sqrt(v.$1 * v.$1 + v.$2 * v.$2 + v.$3 * v.$3);
  return (v.$1 / l, v.$2 / l, v.$3 / l);
}

double _dot(_Vec a, _Vec b) => a.$1 * b.$1 + a.$2 * b.$2 + a.$3 * b.$3;

/// goban `phongShade`: the stone is a sphere flattened by an S curve, lit by a diffuse and a
/// specular light; the lightness of the color changes, not its hue.
(int, int, int) _shade(
  int r,
  int g,
  int b,
  double x,
  double y,
  double radius,
  StoneLighting o,
  _Vec light,
  _Vec half,
) {
  final z = math.sqrt(math.max(0, radius * radius - x * x - y * y));
  var n = _normalized((x, y, z));
  final nz = n.$3;
  n = (n.$1, n.$2, nz * nz * (3 - 2 * nz));
  final diffuse = _dot(n, light) / o.diffuseDistance;
  final specular = math.pow(_dot(n, half), o.hardness) / o.specularDistance;
  final hsl = HSLColor.fromColor(Color.fromARGB(255, r, g, b));
  final lightness = (hsl.lightness * (o.ambient + diffuse) + diffuse * 0.5 + specular).clamp(
    0.0,
    1.0,
  );
  final c = hsl.withLightness(lightness).toColor();
  return ((c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round());
}

/// goban `preRenderStone`, `shell_lines`: translucent lines across the stone, with a glow.
void _paintShellLines(Canvas canvas, double radius, int seed) {
  int js32(int v) => v.toSigned(32);
  final lines = 5 + seed % 5;
  var angle = ((seed % 160) + 10) * 0.0174532925;
  if (seed & 0x100 != 0) angle = -angle;
  final sep = radius / (lines * 2);
  final rise = math.cos(angle);
  final run = math.sin(angle);
  final m = rise / run;
  final minV = run / rise;
  final minV21 = (minV * minV - 1).abs();
  var s = seed;
  final rStep = (radius * 0.1).round();
  var r = -radius;
  final baseWidth = radius * 0.07;
  for (var i = 0; i < lines * 4; i++) {
    for (final neg in [false, true]) {
      r += sep + s.remainder(rStep);
      final xp = math.sqrt(r * r / minV21);
      final yp = minV * xp;
      final b = (neg ? -1 : 1) * yp - m * xp;
      final ex = radius * 2;
      s = js32(s * 97) >> 3;
      final alpha = (s.remainder(10) / 10).clamp(0.0, 1.0);
      final color = Color.fromRGBO(194, 191, 198, alpha);
      final blur = (s.remainder(3).abs() + 1) * baseWidth;
      s = js32(s * 51) >> 3;
      final from = Offset(0, b);
      final to = Offset(ex, m * ex + b);
      canvas
        ..drawLine(
          from,
          to,
          Paint()
            ..color = color
            ..strokeWidth = baseWidth * 0.5
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2),
        )
        ..drawLine(
          from,
          to,
          Paint()
            ..color = color
            ..strokeWidth = baseWidth * 0.5,
        );
    }
  }
}

/// Draws a stone of [theme], centered on [center]. Without its image yet, a rendered theme is
/// drawn with a gradient, and an image theme as plain.
void paintStone(
  Canvas canvas, {
  required Offset center,
  required double radius,
  required StoneColor color,
  required StoneTheme theme,
  required Color lineColor,
  int variant = 0,
  double opacity = 1,
}) {
  final rect = Rect.fromCircle(center: center, radius: radius);
  final lighting = StoneLighting.of(theme, color);
  final imagePath = theme.imageAsset(color == StoneColor.black);
  final ui.Image? image = lighting != null
      ? GobanArt.instance.stone(lighting, variant)
      : (imagePath != null ? GobanArt.instance.asset(imagePath) : null);

  if (theme != StoneTheme.plain && imagePath == null && opacity == 1) {
    // goban `renderShadow`.
    canvas.drawCircle(
      center + Offset(radius * 0.2, radius * 0.2),
      radius * 0.9,
      Paint()
        ..color = const Color.fromRGBO(60, 60, 60, 0.7)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.15),
    );
  }

  if (image != null) {
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = true
      ..color = Color.fromRGBO(0, 0, 0, opacity);
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    if (lighting != null) {
      canvas
        ..save()
        ..clipPath(Path()..addOval(rect))
        ..drawImageRect(image, src, rect, paint)
        ..restore();
    } else {
      canvas.drawImageRect(image, src, rect, paint);
    }
    return;
  }

  if (theme == StoneTheme.plain || lighting == null) {
    // goban `renderPlainStone`, also the look of image stones while they load.
    final width = radius * 0.1;
    final fill = color == StoneColor.black ? Colors.black : Colors.white;
    canvas
      ..drawCircle(center, radius - width / 2, Paint()..color = fill.withValues(alpha: opacity))
      ..drawCircle(
        center,
        radius - width / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = lineColor.withValues(alpha: opacity),
      );
    return;
  }

  final base = lighting.base;
  final light = HSLColor.fromColor(base);
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 0.95,
        colors: [
          for (final l in [0.35, 0.0, -0.08])
            light
                .withLightness((light.lightness + l).clamp(0.0, 1.0))
                .toColor()
                .withValues(alpha: opacity),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(rect),
  );
}
