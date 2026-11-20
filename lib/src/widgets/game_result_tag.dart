import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/result.dart';
import 'package:tengen/src/model/ogs/game_data.dart';
import 'package:tengen/src/widgets/ui.dart';

/// The result of a finished game (`W+Res`, `B+4.5`), green when [playerId] won and red when
/// they lost.
class GameResultTag extends StatelessWidget {
  const GameResultTag({required this.game, required this.playerId, super.key});

  final PlayerGame game;
  final int playerId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = game.black.id == playerId
        ? StoneColor.black
        : (game.white.id == playerId ? StoneColor.white : null);
    final winner = game.winner;
    final result = describeResult(outcome: game.outcome, winner: winner).short;
    final won = winner != null && winner == color;
    final lost = winner != null && color != null && winner != color;
    return Tag(
      result,
      background: won
          ? scheme.secondaryContainer
          : (lost ? scheme.errorContainer : scheme.surfaceContainerHighest),
      foreground: won
          ? scheme.onSecondaryContainer
          : (lost ? scheme.onErrorContainer : scheme.onSurfaceVariant),
    );
  }
}
