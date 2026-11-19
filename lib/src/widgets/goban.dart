import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/coordinates.dart';
import 'package:tengen/src/model/settings/preferences.dart';

/// Ownership markers drawn on the board when counting.
@immutable
class GobanTerritory {
  const GobanTerritory({this.black = const {}, this.white = const {}});

  final Set<Point> black;
  final Set<Point> white;
}

/// An interactive Go board.
///
/// When [onPlay] is set and [toPlay] is not null the board accepts moves: with [confirmMoves] the
/// first tap shows a preview stone and a second tap on the same point plays it, otherwise a tap
/// plays immediately. [onTapStone] is used in the counting phase to toggle dead groups.
class Goban extends StatefulWidget {
  const Goban({
    required this.board,
    this.theme = BoardTheme.kaya,
    this.showCoordinates = true,
    this.lastMove,
    this.toPlay,
    this.onPlay,
    this.onTapStone,
    this.confirmMoves = false,
    this.pendingMove,
    this.deadStones = const {},
    this.territory,
    super.key,
  });

  final Board board;
  final BoardTheme theme;
  final bool showCoordinates;
  final Point? lastMove;

  /// The color of the stone placed by a tap; null when the user cannot play.
  final StoneColor? toPlay;
  final ValueChanged<Point>? onPlay;
  final ValueChanged<Point>? onTapStone;
  final bool confirmMoves;

  /// A move sent to a server and not confirmed yet, shown as a translucent stone.
  final Point? pendingMove;
  final Set<Point> deadStones;
  final GobanTerritory? territory;

  @override
  State<Goban> createState() => _GobanState();
}

/// Geometry shared by the painter and the hit testing.
@immutable
class GobanGeometry {
  GobanGeometry(Size size, this.columns, this.rows, {required bool coordinates})
    : margin = coordinates ? coordinatesMargin : plainMargin,
      cell = math.min(
        size.width / (columns - 1 + 2 * (coordinates ? coordinatesMargin : plainMargin)),
        size.height / (rows - 1 + 2 * (coordinates ? coordinatesMargin : plainMargin)),
      );

  /// Distance from the board edge to the first line, in cells. With coordinates, the labels get
  /// their own band ([labelCenter]) outside the stones, which reach 0.5 cell beyond the lines.
  static const coordinatesMargin = 1.35;
  static const plainMargin = 0.6;

  /// Distance from the board edge to the center of the coordinate labels, in cells.
  static const labelCenter = 0.42;

  final int columns;
  final int rows;
  final double margin;
  final double cell;

  Offset offsetOf(Point p) => Offset((margin + p.x) * cell, (margin + p.y) * cell);

  /// The intersection closest to [offset], or null when outside the grid.
  Point? pointAt(Offset offset) {
    final x = (offset.dx / cell - margin).round();
    final y = (offset.dy / cell - margin).round();
    if (x < 0 || y < 0 || x >= columns || y >= rows) return null;
    return Point(x, y);
  }
}

class _GobanState extends State<Goban> {
  Point? _preview;

  @override
  void didUpdateWidget(Goban oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.board != widget.board || widget.toPlay == null) _preview = null;
  }

  void _onTap(Offset local, GobanGeometry geometry) {
    final p = geometry.pointAt(local);
    if (p == null) return;
    if (widget.onTapStone != null && widget.board[p] != null) {
      HapticFeedback.selectionClick();
      widget.onTapStone!(p);
      return;
    }
    final onPlay = widget.onPlay;
    if (onPlay == null || widget.toPlay == null || widget.board[p] != null) return;
    if (widget.confirmMoves && _preview != p) {
      HapticFeedback.selectionClick();
      setState(() => _preview = p);
      return;
    }
    setState(() => _preview = null);
    HapticFeedback.lightImpact();
    onPlay(p);
  }

  @override
  Widget build(BuildContext context) {
    final board = widget.board;
    return AspectRatio(
      aspectRatio: board.width / board.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final geometry = GobanGeometry(
            size,
            board.width,
            board.height,
            coordinates: widget.showCoordinates,
          );
          return Semantics(
            label: 'Go board, ${board.width} by ${board.height}',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // A semantic tap has no position: it cannot place a stone.
              excludeFromSemantics: true,
              onTapUp: (details) => _onTap(details.localPosition, geometry),
              child: CustomPaint(
                size: size,
                painter: _GobanPainter(
                  board: board,
                  geometry: geometry,
                  theme: widget.theme,
                  showCoordinates: widget.showCoordinates,
                  lastMove: widget.lastMove,
                  preview: _preview,
                  pendingMove: widget.pendingMove,
                  previewColor: widget.toPlay,
                  deadStones: widget.deadStones,
                  territory: widget.territory,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GobanPainter extends CustomPainter {
  _GobanPainter({
    required this.board,
    required this.geometry,
    required this.theme,
    required this.showCoordinates,
    required this.lastMove,
    required this.preview,
    required this.pendingMove,
    required this.previewColor,
    required this.deadStones,
    required this.territory,
  });

  final Board board;
  final GobanGeometry geometry;
  final BoardTheme theme;
  final bool showCoordinates;
  final Point? lastMove;
  final Point? preview;
  final Point? pendingMove;
  final StoneColor? previewColor;
  final Set<Point> deadStones;
  final GobanTerritory? territory;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = geometry.cell;
    final boardRect = Rect.fromLTWH(
      0,
      0,
      (board.width - 1 + 2 * geometry.margin) * cell,
      (board.height - 1 + 2 * geometry.margin) * cell,
    );

    // Wood, edge to edge as in the lichess app.
    canvas.drawRect(
      boardRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(theme.wood, Colors.white, 0.08)!,
            theme.wood,
            Color.lerp(theme.wood, Colors.black, 0.08)!,
          ],
        ).createShader(boardRect),
    );

    // Grid.
    final linePaint = Paint()
      ..color = theme.lines
      ..strokeWidth = math.max(1, cell * 0.035);
    for (var x = 0; x < board.width; x++) {
      canvas.drawLine(
        geometry.offsetOf(Point(x, 0)),
        geometry.offsetOf(Point(x, board.height - 1)),
        linePaint,
      );
    }
    for (var y = 0; y < board.height; y++) {
      canvas.drawLine(
        geometry.offsetOf(Point(0, y)),
        geometry.offsetOf(Point(board.width - 1, y)),
        linePaint,
      );
    }
    final starPaint = Paint()..color = theme.lines;
    for (final p in starPoints(board.width, board.height)) {
      canvas.drawCircle(geometry.offsetOf(p), cell * 0.1, starPaint);
    }

    if (showCoordinates) _paintCoordinates(canvas);

    // Territory markers under the stones.
    final t = territory;
    if (t != null) {
      for (final (points, color) in [(t.black, Colors.black), (t.white, Colors.white)]) {
        final paint = Paint()..color = color.withValues(alpha: 0.85);
        for (final p in points) {
          canvas.drawRect(
            Rect.fromCenter(center: geometry.offsetOf(p), width: cell * 0.36, height: cell * 0.36),
            paint,
          );
        }
      }
    }

    // Stones.
    for (final p in board.points) {
      final color = board[p];
      if (color == null) continue;
      _paintStone(canvas, p, color, opacity: deadStones.contains(p) ? 0.45 : 1);
    }

    for (final (p, alpha) in [(pendingMove, 0.7), (preview, 0.5)]) {
      final c = previewColor;
      if (p != null && c != null && board[p] == null) {
        _paintStone(canvas, p, c, opacity: alpha);
      }
    }

    final last = lastMove;
    if (last != null && board[last] != null) {
      final stone = board[last]!;
      canvas.drawCircle(
        geometry.offsetOf(last),
        cell * 0.22,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, cell * 0.07)
          ..color = stone == StoneColor.black ? Colors.white : Colors.black,
      );
    }
  }

  void _paintStone(Canvas canvas, Point p, StoneColor color, {double opacity = 1}) {
    final cell = geometry.cell;
    final center = geometry.offsetOf(p);
    final radius = cell * 0.48;
    if (opacity == 1) {
      canvas.drawCircle(
        center + Offset(cell * 0.04, cell * 0.06),
        radius,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.05),
      );
    }
    final rect = Rect.fromCircle(center: center, radius: radius);
    final colors = color == StoneColor.black
        ? const [Color(0xFF5A5A5A), Color(0xFF1A1A1A), Color(0xFF000000)]
        : const [Color(0xFFFFFFFF), Color(0xFFEDEDED), Color(0xFFBDBDBD)];
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 0.95,
          colors: [for (final c in colors) c.withValues(alpha: opacity)],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
    if (opacity < 1 && opacity <= 0.45) {
      // Dead stone cross.
      final paint = Paint()
        ..color = (color == StoneColor.black ? Colors.white : Colors.black).withValues(alpha: 0.8)
        ..strokeWidth = math.max(1.5, cell * 0.06);
      final d = radius * 0.45;
      canvas
        ..drawLine(center + Offset(-d, -d), center + Offset(d, d), paint)
        ..drawLine(center + Offset(d, -d), center + Offset(-d, d), paint);
    }
  }

  void _paintCoordinates(Canvas canvas) {
    final cell = geometry.cell;
    final style = TextStyle(
      color: theme.lines.withValues(alpha: 0.85),
      fontSize: cell * 0.38,
      fontWeight: FontWeight.w600,
    );
    void label(String text, Offset center) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
    }

    const band = GobanGeometry.labelCenter;
    final offset = band * cell;
    final far = (2 * geometry.margin - band + board.height - 1) * cell;
    final right = (2 * geometry.margin - band + board.width - 1) * cell;
    for (var x = 0; x < board.width; x++) {
      final cx = geometry.offsetOf(Point(x, 0)).dx;
      label(prettyColumns[x], Offset(cx, offset));
      label(prettyColumns[x], Offset(cx, far));
    }
    for (var y = 0; y < board.height; y++) {
      final cy = geometry.offsetOf(Point(0, y)).dy;
      label('${board.height - y}', Offset(offset, cy));
      label('${board.height - y}', Offset(right, cy));
    }
  }

  @override
  bool shouldRepaint(_GobanPainter old) =>
      old.board != board ||
      old.theme != theme ||
      old.showCoordinates != showCoordinates ||
      old.lastMove != lastMove ||
      old.preview != preview ||
      old.pendingMove != pendingMove ||
      old.previewColor != previewColor ||
      old.deadStones != deadStones ||
      old.territory != territory ||
      old.geometry.cell != geometry.cell;
}
