import 'package:meta/meta.dart';

/// The color of a stone, or of a player.
enum StoneColor {
  black,
  white;

  StoneColor get opposite => this == black ? white : black;

  /// Short name used in SGF and OGS payloads.
  String get code => this == black ? 'B' : 'W';
}

/// An intersection of the board.
///
/// Uses the OGS convention: `x` is the column from the left, `y` is the row from the top, both
/// starting at 0.
@immutable
class Point {
  const Point(this.x, this.y);

  final int x;
  final int y;

  @override
  bool operator ==(Object other) => other is Point && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Point($x, $y)';
}

/// A group of connected stones of the same color, with its liberties.
@immutable
class StoneGroup {
  const StoneGroup(this.color, this.stones, this.liberties);

  final StoneColor color;
  final Set<Point> stones;
  final Set<Point> liberties;
}

/// An immutable Go board.
@immutable
class Board {
  Board.empty(this.width, this.height)
    : assert(width > 0 && width <= 25 && height > 0 && height <= 25),
      _cells = List<StoneColor?>.filled(width * height, null);

  const Board._(this.width, this.height, this._cells);

  final int width;
  final int height;
  final List<StoneColor?> _cells;

  bool contains(Point p) => p.x >= 0 && p.y >= 0 && p.x < width && p.y < height;

  StoneColor? operator [](Point p) => _cells[p.y * width + p.x];

  /// All the points of the board, row by row.
  Iterable<Point> get points sync* {
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        yield Point(x, y);
      }
    }
  }

  int count(StoneColor color) => _cells.where((c) => c == color).length;

  bool get isEmpty => _cells.every((c) => c == null);

  /// Returns a copy of this board with [stones] set to [color] (or removed if [color] is null).
  ///
  /// No capture is resolved: this is meant for setting up positions.
  Board withStones(Iterable<Point> stones, StoneColor? color) {
    final cells = List<StoneColor?>.of(_cells);
    for (final p in stones) {
      cells[p.y * width + p.x] = color;
    }
    return Board._(width, height, List.unmodifiable(cells));
  }

  Iterable<Point> neighbors(Point p) sync* {
    if (p.x > 0) yield Point(p.x - 1, p.y);
    if (p.x < width - 1) yield Point(p.x + 1, p.y);
    if (p.y > 0) yield Point(p.x, p.y - 1);
    if (p.y < height - 1) yield Point(p.x, p.y + 1);
  }

  /// The group of stones the stone at [p] belongs to, or null if [p] is empty.
  StoneGroup? groupAt(Point p) {
    final color = this[p];
    if (color == null) return null;
    final stones = <Point>{p};
    final liberties = <Point>{};
    final stack = [p];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      for (final n in neighbors(current)) {
        final c = this[n];
        if (c == null) {
          liberties.add(n);
        } else if (c == color && stones.add(n)) {
          stack.add(n);
        }
      }
    }
    return StoneGroup(color, stones, liberties);
  }

  /// The connected empty region containing [p] and the colors of the stones bordering it.
  ({Set<Point> points, Set<StoneColor> borders}) emptyRegionAt(
    Point p, {
    Set<Point>? treatAsEmpty,
  }) {
    bool isEmptyAt(Point q) => this[q] == null || (treatAsEmpty?.contains(q) ?? false);
    assert(isEmptyAt(p));
    final points = <Point>{p};
    final borders = <StoneColor>{};
    final stack = [p];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      for (final n in neighbors(current)) {
        if (isEmptyAt(n)) {
          if (points.add(n)) stack.add(n);
        } else {
          borders.add(this[n]!);
        }
      }
    }
    return (points: points, borders: borders);
  }

  /// Places a stone of [color] at [p] and removes the opponent groups left without liberties.
  ///
  /// If the placed stone's own group has no liberty afterwards (suicide), it is removed as well.
  /// Returns the new board and the stones captured from each side. Throws if [p] is occupied.
  ({Board board, Set<Point> captured, Set<Point> suicided}) place(StoneColor color, Point p) {
    if (this[p] != null) {
      throw StateError('Point $p is occupied');
    }
    final cells = List<StoneColor?>.of(_cells);
    cells[p.y * width + p.x] = color;
    var board = Board._(width, height, cells);

    final captured = <Point>{};
    for (final n in neighbors(p)) {
      if (board[n] == color.opposite && !captured.contains(n)) {
        final group = board.groupAt(n)!;
        if (group.liberties.isEmpty) captured.addAll(group.stones);
      }
    }
    for (final c in captured) {
      cells[c.y * width + c.x] = null;
    }

    final suicided = <Point>{};
    board = Board._(width, height, cells);
    final own = board.groupAt(p)!;
    if (own.liberties.isEmpty) {
      suicided.addAll(own.stones);
      for (final s in suicided) {
        cells[s.y * width + s.x] = null;
      }
    }
    return (
      board: Board._(width, height, List.unmodifiable(cells)),
      captured: captured,
      suicided: suicided,
    );
  }

  /// A compact string identifying the position, used for ko and superko detection.
  String get positionKey =>
      String.fromCharCodes(_cells.map((c) => c == null ? 46 : (c == StoneColor.black ? 98 : 119)));

  @override
  bool operator ==(Object other) =>
      other is Board &&
      other.width == width &&
      other.height == height &&
      other.positionKey == positionKey;

  @override
  int get hashCode => Object.hash(width, height, positionKey);

  /// ASCII rendering, handy for debugging and tests.
  @override
  String toString() {
    final buffer = StringBuffer();
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final c = this[Point(x, y)];
        buffer.write(c == null ? '.' : (c == StoneColor.black ? 'X' : 'O'));
      }
      if (y < height - 1) buffer.writeln();
    }
    return buffer.toString();
  }

  /// Parses an ASCII board as produced by [toString] (`X` black, `O` white, `.` empty).
  factory Board.parse(String ascii) {
    final rows = ascii.trim().split('\n').map((r) => r.trim()).toList();
    final height = rows.length;
    final width = rows.first.length;
    final cells = <StoneColor?>[];
    for (final row in rows) {
      if (row.length != width) throw FormatException('Ragged board', ascii);
      for (final ch in row.split('')) {
        cells.add(switch (ch) {
          'X' => StoneColor.black,
          'O' => StoneColor.white,
          '.' => null,
          _ => throw FormatException('Unexpected character $ch', ascii),
        });
      }
    }
    return Board._(width, height, List.unmodifiable(cells));
  }
}
