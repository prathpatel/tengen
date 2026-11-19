import 'package:tengen/src/model/go/board.dart';

const _ogsSequence = 'abcdefghijklmnopqrstuvwxyz';

/// Column letters as written on a board: the letter I is skipped.
const prettyColumns = 'ABCDEFGHJKLMNOPQRSTUVWXYZ';

/// Encodes a point to the OGS two letter move format (`aa` is the top left corner). A pass is
/// encoded `..`.
String encodeOgsMove(Point? p) => p == null ? '..' : '${_ogsSequence[p.x]}${_ogsSequence[p.y]}';

/// Decodes a string of concatenated OGS moves (e.g. `ddpp..`). `null` entries are passes.
List<Point?> decodeOgsMoves(String encoded) {
  if (encoded.length.isOdd) throw FormatException('Odd length move string', encoded);
  return [
    for (var i = 0; i < encoded.length; i += 2)
      if (encoded[i] == '.')
        null
      else
        Point(_ogsSequence.indexOf(encoded[i]), _ogsSequence.indexOf(encoded[i + 1])),
  ];
}

/// Human readable coordinate, e.g. `D4` (row 1 is at the bottom).
String prettyCoordinate(Point? p, int boardHeight) =>
    p == null ? 'Pass' : '${prettyColumns[p.x]}${boardHeight - p.y}';

/// Star points (hoshi) for the usual board sizes.
List<Point> starPoints(int width, int height) {
  if (width != height) return const [];
  final List<int> lines;
  switch (width) {
    case 19:
      lines = [3, 9, 15];
    case 13:
      lines = [3, 6, 9];
    case 9:
      return const [Point(2, 2), Point(6, 2), Point(4, 4), Point(2, 6), Point(6, 6)];
    default:
      return const [];
  }
  return [
    for (final y in lines)
      for (final x in lines) Point(x, y),
  ];
}

/// Fixed handicap stone placement, matching the OGS `goban` engine.
///
/// Returns an empty list when the board size has no fixed placement (OGS then uses free
/// placement).
List<Point> fixedHandicapStones(int size, int handicap) {
  final List<int> l;
  switch (size) {
    case 19:
      l = [3, 9, 15];
    case 13:
      l = [3, 6, 9];
    case 9:
      l = [2, 4, 6];
    default:
      return const [];
  }
  Point star(int row, int col) => Point(l[col], l[row]);
  final h = handicap.clamp(0, 9);
  if (h < 2) return const [];
  final stones = <Point>[
    star(0, 2),
    star(2, 0),
    if (h >= 3) star(2, 2),
    if (h >= 4) star(0, 0),
    if (h == 5 || h == 7 || h == 9) star(1, 1),
    if (h >= 6) ...[star(1, 0), star(1, 2)],
    if (h >= 8) ...[star(0, 1), star(2, 1)],
  ];
  return stones;
}
