import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/coordinates.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/widgets/goban.dart';
import 'package:tengen/src/widgets/goban_art.dart';

/// A small, non-interactive board, for lists (your games, the games of a player, puzzles, top
/// games).
///
/// It has its own light painter rather than the full [Goban]: the wood is one image, the stones
/// plain shaded discs, and nothing animates. A list shows many of these at once, and the full
/// board (stone images, sounds, animations) for each one makes scrolling heavy.
class BoardThumbnail extends ConsumerWidget {
  const BoardThumbnail({
    required this.board,
    required this.size,
    this.lastMove,
    this.viewport,
    super.key,
  });

  final Board board;
  final double size;
  final Point? lastMove;
  final GobanViewport? viewport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(preferencesProvider.select((p) => p.boardTheme));
    final vp = viewport ?? GobanViewport.full(board);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox.square(
        dimension: size,
        child: ExcludeSemantics(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _ThumbnailPainter(
                board: board,
                viewport: vp,
                lastMove: lastMove,
                theme: theme,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThumbnailPainter extends CustomPainter {
  _ThumbnailPainter({
    required this.board,
    required this.viewport,
    required this.lastMove,
    required this.theme,
  }) : super(repaint: GobanArt.instance);

  final Board board;
  final GobanViewport viewport;
  final Point? lastMove;
  final BoardTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final vp = viewport;
    final geometry = GobanGeometry(
      size,
      vp.columns,
      vp.rows,
      coordinates: false,
      originX: vp.left,
      originY: vp.top,
    );
    final cell = geometry.cell;
    final area = Offset.zero & size;

    canvas.drawRect(area, Paint()..color = theme.wood);
    final path = theme.textureAsset;
    final texture = path == null ? null : GobanArt.instance.asset(path);
    if (texture != null) {
      paintImage(
        canvas: canvas,
        rect: area,
        image: texture,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
      );
    }

    final line = Paint()
      ..color = theme.lines
      ..strokeWidth = math.max(0.5, cell * 0.04);
    for (var x = vp.left; x <= vp.right; x++) {
      canvas.drawLine(
        geometry.offsetOf(Point(x, vp.top)),
        geometry.offsetOf(Point(x, vp.bottom)),
        line,
      );
    }
    for (var y = vp.top; y <= vp.bottom; y++) {
      canvas.drawLine(
        geometry.offsetOf(Point(vp.left, y)),
        geometry.offsetOf(Point(vp.right, y)),
        line,
      );
    }
    final star = Paint()..color = theme.stars;
    for (final p in starPoints(board.width, board.height).where(vp.contains)) {
      canvas.drawCircle(geometry.offsetOf(p), math.max(1, cell * 0.1), star);
    }

    final radius = cell * 0.47;
    final black = Paint()..color = const Color(0xFF1A1A1A);
    final white = Paint()..color = const Color(0xFFF2F1EC);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, cell * 0.04)
      ..color = const Color(0x55000000);
    final shine = Paint()..color = const Color(0x40FFFFFF);
    for (final p in board.points) {
      final color = board[p];
      if (color == null || !vp.contains(p)) continue;
      final c = geometry.offsetOf(p);
      if (color == StoneColor.black) {
        canvas
          ..drawCircle(c, radius, black)
          ..drawCircle(c - Offset(radius * 0.3, radius * 0.3), radius * 0.3, shine);
      } else {
        canvas
          ..drawCircle(c, radius, white)
          ..drawCircle(c, radius, edge);
      }
    }

    final last = lastMove;
    if (last != null && vp.contains(last) && board[last] != null) {
      canvas.drawCircle(
        geometry.offsetOf(last),
        radius * 0.42,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, cell * 0.1)
          ..color = board[last] == StoneColor.black ? Colors.white : Colors.black,
      );
    }
  }

  @override
  bool shouldRepaint(_ThumbnailPainter old) =>
      old.board != board ||
      old.viewport != viewport ||
      old.lastMove != lastMove ||
      old.theme != theme;
}
