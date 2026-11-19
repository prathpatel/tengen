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

/// A mark drawn on an intersection: a label (letter or number) or a shape.
@immutable
sealed class GobanMark {
  const GobanMark();
}

class LabelMark extends GobanMark {
  const LabelMark(this.text);

  final String text;

  @override
  bool operator ==(Object other) => other is LabelMark && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

enum ShapeKind { triangle, square, circle, cross }

class ShapeMark extends GobanMark {
  const ShapeMark(this.kind);

  final ShapeKind kind;

  @override
  bool operator ==(Object other) => other is ShapeMark && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;
}

/// The part of the board to show, inclusive bounds in board coordinates.
@immutable
class GobanViewport {
  const GobanViewport(this.left, this.top, this.right, this.bottom);

  /// The whole board.
  GobanViewport.full(Board board) : this(0, 0, board.width - 1, board.height - 1);

  /// The smallest area showing [points] with [margin] free lines around them, or the whole board
  /// when that area is most of it anyway (puzzles are usually in one corner).
  factory GobanViewport.around(Board board, Iterable<Point> points, {int margin = 2}) {
    if (points.isEmpty) return GobanViewport.full(board);
    var left = board.width;
    var top = board.height;
    var right = 0;
    var bottom = 0;
    for (final p in points) {
      if (p.x < left) left = p.x;
      if (p.y < top) top = p.y;
      if (p.x > right) right = p.x;
      if (p.y > bottom) bottom = p.y;
    }
    // Snap to an edge when close to it: the edge matters in life and death problems.
    int low(int v) => v - margin <= 2 ? 0 : v - margin;
    int high(int v, int max) => v + margin >= max - 2 ? max : v + margin;
    final vp = GobanViewport(
      low(left),
      low(top),
      high(right, board.width - 1),
      high(bottom, board.height - 1),
    );
    final area = vp.columns * vp.rows;
    return area > board.width * board.height * 0.7 ? GobanViewport.full(board) : vp;
  }

  final int left;
  final int top;
  final int right;
  final int bottom;

  int get columns => right - left + 1;
  int get rows => bottom - top + 1;

  bool contains(Point p) => p.x >= left && p.x <= right && p.y >= top && p.y <= bottom;

  @override
  bool operator ==(Object other) =>
      other is GobanViewport &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);
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
    this.viewport,
    this.marks = const {},
    super.key,
  });

  final Board board;

  /// Labels and shapes drawn on intersections.
  final Map<Point, GobanMark> marks;

  /// The part of the board shown; the whole board when null.
  final GobanViewport? viewport;
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
  GobanGeometry(
    Size size,
    this.columns,
    this.rows, {
    required bool coordinates,
    this.originX = 0,
    this.originY = 0,
  }) : margin = coordinates ? coordinatesMargin : plainMargin,
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

  /// The number of lines shown, and the board coordinates of the first ones.
  final int columns;
  final int rows;
  final int originX;
  final int originY;
  final double margin;
  final double cell;

  Offset offsetOf(Point p) =>
      Offset((margin + p.x - originX) * cell, (margin + p.y - originY) * cell);

  /// The intersection closest to [offset], or null when outside the grid.
  Point? pointAt(Offset offset) {
    final x = (offset.dx / cell - margin).round();
    final y = (offset.dy / cell - margin).round();
    if (x < 0 || y < 0 || x >= columns || y >= rows) return null;
    return Point(x + originX, y + originY);
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
    final viewport = widget.viewport ?? GobanViewport.full(board);
    return AspectRatio(
      aspectRatio: viewport.columns / viewport.rows,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final geometry = GobanGeometry(
            size,
            viewport.columns,
            viewport.rows,
            coordinates: widget.showCoordinates,
            originX: viewport.left,
            originY: viewport.top,
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
                  viewport: viewport,
                  marks: widget.marks,
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
    required this.viewport,
    required this.marks,
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
  final GobanViewport viewport;
  final Map<Point, GobanMark> marks;
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
    final vp = viewport;
    final boardRect = Rect.fromLTWH(
      0,
      0,
      (vp.columns - 1 + 2 * geometry.margin) * cell,
      (vp.rows - 1 + 2 * geometry.margin) * cell,
    );
    canvas.clipRect(boardRect);

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
    // Where the view cuts the board, the lines run to the border to show that it continues.
    final cutTop = vp.top > 0 ? geometry.margin * cell : 0.0;
    final cutBottom = vp.bottom < board.height - 1 ? geometry.margin * cell : 0.0;
    final cutLeft = vp.left > 0 ? geometry.margin * cell : 0.0;
    final cutRight = vp.right < board.width - 1 ? geometry.margin * cell : 0.0;
    for (var x = vp.left; x <= vp.right; x++) {
      canvas.drawLine(
        geometry.offsetOf(Point(x, vp.top)) - Offset(0, cutTop),
        geometry.offsetOf(Point(x, vp.bottom)) + Offset(0, cutBottom),
        linePaint,
      );
    }
    for (var y = vp.top; y <= vp.bottom; y++) {
      canvas.drawLine(
        geometry.offsetOf(Point(vp.left, y)) - Offset(cutLeft, 0),
        geometry.offsetOf(Point(vp.right, y)) + Offset(cutRight, 0),
        linePaint,
      );
    }
    final starPaint = Paint()..color = theme.lines;
    for (final p in starPoints(board.width, board.height).where(vp.contains)) {
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
    for (final p in board.points.where(vp.contains)) {
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

    for (final MapEntry(key: p, value: mark) in marks.entries) {
      if (vp.contains(p)) _paintMark(canvas, p, mark);
    }

    final last = lastMove;
    if (last != null && board[last] != null && !marks.containsKey(last)) {
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

  void _paintMark(Canvas canvas, Point p, GobanMark mark) {
    final cell = geometry.cell;
    final center = geometry.offsetOf(p);
    final stone = board[p];
    final color = switch (stone) {
      StoneColor.black => Colors.white,
      StoneColor.white => Colors.black,
      null => theme.lines,
    };
    switch (mark) {
      case LabelMark(:final text):
        if (stone == null) {
          // Clear the grid lines under the label.
          canvas.drawCircle(center, cell * 0.36, Paint()..color = theme.wood);
        }
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: color,
              fontSize: cell * (text.length > 1 ? 0.45 : 0.55),
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
      case ShapeMark(:final kind):
        final paint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, cell * 0.07);
        final r = cell * 0.24;
        switch (kind) {
          case ShapeKind.triangle:
            canvas.drawPath(
              Path()
                ..moveTo(center.dx, center.dy - r * 1.1)
                ..lineTo(center.dx + r, center.dy + r * 0.7)
                ..lineTo(center.dx - r, center.dy + r * 0.7)
                ..close(),
              paint,
            );
          case ShapeKind.square:
            canvas.drawRect(Rect.fromCircle(center: center, radius: r * 0.85), paint);
          case ShapeKind.circle:
            canvas.drawCircle(center, r, paint);
          case ShapeKind.cross:
            canvas
              ..drawLine(center + Offset(-r, -r), center + Offset(r, r), paint)
              ..drawLine(center + Offset(r, -r), center + Offset(-r, r), paint);
        }
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
    final vp = viewport;
    final far = (2 * geometry.margin - band + vp.rows - 1) * cell;
    final right = (2 * geometry.margin - band + vp.columns - 1) * cell;
    for (var x = vp.left; x <= vp.right; x++) {
      final cx = geometry.offsetOf(Point(x, vp.top)).dx;
      label(prettyColumns[x], Offset(cx, offset));
      label(prettyColumns[x], Offset(cx, far));
    }
    for (var y = vp.top; y <= vp.bottom; y++) {
      final cy = geometry.offsetOf(Point(vp.left, y)).dy;
      label('${board.height - y}', Offset(offset, cy));
      label('${board.height - y}', Offset(right, cy));
    }
  }

  @override
  bool shouldRepaint(_GobanPainter old) =>
      old.board != board ||
      old.viewport != viewport ||
      old.marks != marks ||
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
