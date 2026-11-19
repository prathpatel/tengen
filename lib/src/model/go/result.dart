import 'package:meta/meta.dart';
import 'package:tengen/src/model/go/board.dart';

/// A game result for display: a short line like `W+17.5` or `B+R`, and a sentence.
@immutable
class GameResultText {
  const GameResultText(this.short, this.description);

  final String short;
  final String description;
}

String _name(StoneColor c) => c == StoneColor.black ? 'Black' : 'White';

/// Describes an OGS game outcome (`outcome` of the game data) or a local result string
/// (`B+3.5`, `W+R`).
///
/// OGS outcomes are `N points`, `Resignation`, `Timeout`, `Disconnection`, `Abandonment`,
/// `Cancellation`, `Stone Removal Timeout`, `Disqualification`, `Moderator Decision`, or start with
/// `Server Decision` (the anti-stalling rule: the game was over but a player kept playing, and the
/// winner was decided from the score estimate).
GameResultText describeResult({required String? outcome, required StoneColor? winner}) {
  final o = (outcome ?? '').trim();
  // Local result strings.
  final local = RegExp(r'^([BW])\+(.+)$').firstMatch(o);
  if (local != null) {
    final w = local.group(1) == 'B' ? StoneColor.black : StoneColor.white;
    return describeResult(
      outcome: switch (local.group(2)) {
        'R' => 'Resignation',
        'T' => 'Timeout',
        final points => '$points points',
      },
      winner: w,
    );
  }
  if (o.toLowerCase() == 'jigo' || o == '0 points') {
    return const GameResultText('Jigo', 'Draw: both players have the same score');
  }
  if (winner == null) {
    return switch (o) {
      'Cancellation' => const GameResultText('Cancelled', 'The game was cancelled'),
      'Annulled' => const GameResultText('Annulled', 'The game was annulled'),
      '' => const GameResultText('Game over', 'The game has ended'),
      _ => GameResultText('Game over', o),
    };
  }
  final w = _name(winner);
  final l = _name(winner.opposite);
  final c = winner.code;
  final points = RegExp(r'^([0-9]+(?:\.[0-9]+)?)').firstMatch(o)?.group(1);
  if (points != null) {
    final n = double.parse(points);
    final shown = n == n.roundToDouble() ? n.toInt().toString() : n.toString();
    return GameResultText('$c+$shown', '$w wins by $shown ${n == 1 ? 'point' : 'points'}');
  }
  if (o.startsWith('Server Decision')) {
    return GameResultText(
      '$c+',
      '$w wins by server decision: the game was over, and OGS decided the winner from its '
          'score estimate because a player kept playing instead of passing',
    );
  }
  return switch (o) {
    'Resignation' => GameResultText('$c+R', '$l resigned · $w is victorious'),
    'Timeout' => GameResultText('$c+T', '$l ran out of time · $w is victorious'),
    'Disconnection' => GameResultText('$c+', '$l left the game · $w is victorious'),
    'Abandonment' => GameResultText('$c+', '$l abandoned the game · $w is victorious'),
    'Stone Removal Timeout' => GameResultText(
      '$c+',
      'The dead stones were not agreed in time · $w is victorious',
    ),
    'Disqualification' => GameResultText('$c+', '$l was disqualified · $w is victorious'),
    'Moderator Decision' => GameResultText('$c+', 'Moderator decision · $w is victorious'),
    _ => GameResultText('$c+', '$w is victorious${o.isEmpty ? '' : ' · $o'}'),
  };
}
