import 'package:material_ui/material_ui.dart';

/// Lays out a game: a player bar on each side of the board and actions at the bottom.
///
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

  /// A message shown between the board and the bottom player (result, scoring, undo request).
  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    final actionBar = Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [for (final a in actions) Flexible(child: a)],
      ),
    );
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final landscape = constraints.maxWidth > constraints.maxHeight * 1.2;
          if (landscape) {
            return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Center(child: board),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [topPlayer, ?banner, bottomPlayer, actionBar],
                  ),
                ),
              ],
            );
          }
          return Column(
            children: [
              topPlayer,
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Center(child: board),
                ),
              ),
              ?banner,
              bottomPlayer,
              actionBar,
            ],
          );
        },
      ),
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
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
