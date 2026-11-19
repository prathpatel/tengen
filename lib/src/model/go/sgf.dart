import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/game.dart';
import 'package:tengen/src/model/go/rules.dart';

String _sgfPoint(Point? p) =>
    p == null ? '' : '${String.fromCharCode(97 + p.x)}${String.fromCharCode(97 + p.y)}';

String _escape(String value) => value.replaceAll(r'\', r'\\').replaceAll(']', r'\]');

/// Exports [game] to SGF (FF[4]).
String toSgf(GoGame game, {String? blackName, String? whiteName, String? result, DateTime? date}) {
  final initial = game.positions.first.board;
  final setupBlack = initial.points.where((p) => initial[p] == StoneColor.black).toList();
  final setupWhite = initial.points.where((p) => initial[p] == StoneColor.white).toList();
  final rules = switch (game.ruleset) {
    Ruleset.japanese => 'Japanese',
    Ruleset.chinese => 'Chinese',
    Ruleset.aga => 'AGA',
    Ruleset.korean => 'Korean',
    Ruleset.nz => 'NZ',
    Ruleset.ing => 'Ing',
  };
  final d = date;
  final buffer = StringBuffer('(;FF[4]GM[1]CA[UTF-8]AP[Tengen]')
    ..write(game.width == game.height ? 'SZ[${game.width}]' : 'SZ[${game.width}:${game.height}]')
    ..write('RU[$rules]KM[${game.komi}]');
  if (game.handicap > 1) buffer.write('HA[${game.handicap}]');
  if (blackName != null) buffer.write('PB[${_escape(blackName)}]');
  if (whiteName != null) buffer.write('PW[${_escape(whiteName)}]');
  if (result != null) buffer.write('RE[${_escape(result)}]');
  if (d != null) {
    buffer.write(
      'DT[${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}]',
    );
  }
  if (setupBlack.isNotEmpty) buffer.write('AB${setupBlack.map((p) => '[${_sgfPoint(p)}]').join()}');
  if (setupWhite.isNotEmpty) buffer.write('AW${setupWhite.map((p) => '[${_sgfPoint(p)}]').join()}');
  if (game.positions.first.toMove == StoneColor.white) buffer.write('PL[W]');
  for (final move in game.moves) {
    buffer.write(';${move.color.code}[${_sgfPoint(move.point)}]');
  }
  buffer.write(')');
  return buffer.toString();
}
