import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/coordinates.dart';
import 'package:tengen/src/model/go/game.dart';

/// `Black to play`, or `Move 12 · White D4` / `Move 13 · Black passed`.
String moveSummary(GoGame game) {
  final last = game.position.lastMove;
  String name(StoneColor c) => c == StoneColor.black ? 'Black' : 'White';
  if (last == null) {
    return game.handicapStonesLeft > 0
        ? 'Black places ${game.handicapStonesLeft} handicap stones'
        : '${name(game.toMove)} to play';
  }
  final what = last.isPass
      ? '${name(last.color)} passed'
      : '${name(last.color)} ${prettyCoordinate(last.point, game.height)}';
  return 'Move ${game.moveCount} · $what';
}

/// An app bar title with a smaller line below, e.g. the move number.
class GameTitle extends StatelessWidget {
  const GameTitle({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, overflow: TextOverflow.ellipsis),
        if (subtitle != null)
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

/// Lays out a game: a player bar on each side of the board and actions at the bottom.
///
/// The player bars hug the board, and the group is centered in the space left by the actions.
/// In landscape the player bars and actions go to the right of the board.
class GameLayout extends StatelessWidget {
  const GameLayout({
    required this.board,
    required this.topPlayer,
    required this.bottomPlayer,
    required this.actions,
    this.banner,
    super.key,
  });

  final Widget board;
  final Widget topPlayer;
  final Widget bottomPlayer;
  final List<Widget> actions;

  /// A message shown under the bottom player (result, counting, undo request).
  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final actionBar = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [for (final a in actions) Flexible(child: a)],
          ),
        ),
      ),
    );
    final paddedBoard = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: board,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final landscape = constraints.maxWidth > constraints.maxHeight * 1.2;
        if (landscape) {
          return SafeArea(
            bottom: false,
            child: Row(
              children: [
                Expanded(flex: 3, child: Center(child: paddedBoard)),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [topPlayer, ?banner, bottomPlayer],
                        ),
                      ),
                      actionBar,
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  topPlayer,
                  Flexible(child: paddedBoard),
                  bottomPlayer,
                  ?banner,
                ],
              ),
            ),
            actionBar,
          ],
        );
      },
    );
  }
}

/// An icon button with a label below, used in the game action bar.
class GameAction extends StatelessWidget {
  const GameAction({required this.icon, required this.label, this.onPressed, super.key});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon),
        const SizedBox(height: 2),
        Text(label, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

/// A highlighted message shown under the board.
class GameBanner extends StatelessWidget {
  const GameBanner({required this.title, this.message, this.actions = const [], super.key});

  final String title;
  final String? message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (message != null)
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 8, runSpacing: 4, children: actions),
            ),
        ],
      ),
    );
  }
}
