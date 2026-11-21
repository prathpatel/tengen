import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/coordinates.dart';
import 'package:tengen/src/model/go/game.dart';
import 'package:tengen/src/model/go/scoring.dart';
import 'package:tengen/src/widgets/ui.dart';

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

/// `35 territory + 6 prisoners`, `28 territory + 30 stones + 6.5 komi`.
String scoreDetail(SideScore side) {
  String n(num v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';
  return [
    '${side.territory} territory',
    if (side.stones > 0) '${side.stones} stones',
    if (side.prisoners > 0) '${side.prisoners} ${side.prisoners == 1 ? 'prisoner' : 'prisoners'}',
    if (side.handicap > 0) '${side.handicap} handicap',
    if (side.komi != 0) '${n(side.komi)} komi',
  ].join(' + ');
}

/// The height kept for the actions at the bottom of a game, whatever they are (round actions
/// while playing, two large buttons when counting): the board must not move between phases.
const kGameActionsHeight = 112.0;

/// Lays out a game screen below its top bar: what goes above the board (the opponent, or a
/// prompt), the board, what goes below (you, the score, the move list), and the actions.
///
/// The board is as large as the room left allows, and the block of the three is centered in
/// the space above the actions. In landscape the board is on the left and the rest on the right.
class GameLayout extends StatelessWidget {
  const GameLayout({
    required this.board,
    required this.above,
    required this.below,
    required this.actions,
    super.key,
  });

  final Widget board;
  final Widget above;
  final Widget below;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    // The players and the actions slide softly into place when the screen opens.
    final above = Entrance(offset: -16, child: this.above);
    final below = Entrance(delay: const Duration(milliseconds: 80), child: this.below);
    final actions = Entrance(
      delay: const Duration(milliseconds: 160),
      offset: 40,
      child: this.actions,
    );
    // The board sits inset, with rounded corners and a soft shadow.
    final board = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(20), child: this.board),
      ),
    );
    final actionArea = SafeArea(
      top: false,
      child: SizedBox(
        height: kGameActionsHeight,
        child: Center(child: actions),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final landscape = constraints.maxWidth > constraints.maxHeight * 1.2;
        if (landscape) {
          return SafeArea(
            bottom: false,
            child: Row(
              children: [
                Expanded(flex: 3, child: Center(child: board)),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [above, const SizedBox(height: 12), below],
                        ),
                      ),
                      actionArea,
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
              child: CustomMultiChildLayout(
                delegate: _GameAreaLayout(),
                children: [
                  LayoutId(id: _GameAreaLayout.top, child: above),
                  LayoutId(id: _GameAreaLayout.board, child: board),
                  LayoutId(id: _GameAreaLayout.bottom, child: below),
                ],
              ),
            ),
            actionArea,
          ],
        );
      },
    );
  }
}

/// Two large buttons side by side (`Resume play` / `Accept`), for the end of a game.
class GameButtons extends StatelessWidget {
  const GameButtons({required this.secondary, required this.primary, super.key});

  final Widget secondary;
  final Widget primary;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      children: [
        Expanded(child: secondary),
        const SizedBox(width: 14),
        Expanded(child: primary),
      ],
    ),
  );
}

/// A prompt above the board (`Both passed. Tap the dead stones, then Accept.`).
class GamePrompt extends StatelessWidget {
  const GamePrompt({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icon, color: scheme.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One line of a [ScoreCard].
@immutable
class ScoreLine {
  const ScoreLine({
    required this.color,
    required this.name,
    required this.detail,
    required this.total,
  });

  final StoneColor color;
  final String name;

  /// `35 territory + 6 prisoners`
  final String detail;
  final double total;
}

/// The score when counting: each player's points, then who wins.
class ScoreCard extends StatelessWidget {
  const ScoreCard({required this.lines, required this.verdict, required this.result, super.key});

  final List<ScoreLine> lines;

  /// `You win by 4.5`
  final String verdict;

  /// `B+4.5`
  final String result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final best = lines.map((l) => l.total).fold<double>(double.negativeInfinity, math.max);
    String points(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    _Stone(line.color, size: 20),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 64,
                      child: Text(
                        line.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        line.detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    Text(
                      points(line.total),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: line.total == best ? scheme.onSurface : scheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            Divider(height: 24, color: scheme.outlineVariant),
            Row(
              children: [
                Expanded(child: Text(verdict, style: theme.textTheme.headlineSmall)),
                Text(
                  result,
                  style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stone extends StatelessWidget {
  const _Stone(this.color, {required this.size});

  final StoneColor color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        center: const Alignment(-0.35, -0.4),
        colors: color == StoneColor.black
            ? const [Color(0xFF5A5A5A), Color(0xFF111111)]
            : const [Color(0xFFFFFFFF), Color(0xFFC8C8C8)],
      ),
    ),
  );
}

/// Lays out the players and the board, top to bottom: the board is as large as the room the
/// players leave allows.
class _GameAreaLayout extends MultiChildLayoutDelegate {
  static const top = 'top';
  static const board = 'board';
  static const bottom = 'bottom';

  static const gap = 6.0;

  @override
  void performLayout(Size size) {
    final wide = BoxConstraints(minWidth: size.width, maxWidth: size.width, maxHeight: size.height);
    final topHeight = layoutChild(top, wide).height;
    final bottomHeight = layoutChild(bottom, wide).height;
    final room = (size.height - gap * 2 - topHeight - bottomHeight).clamp(0.0, size.height);
    final boardSize = layoutChild(board, BoxConstraints(maxWidth: size.width, maxHeight: room));

    // The block of the three is centered: the space it leaves is shared evenly above and below.
    final block = topHeight + boardSize.height + bottomHeight;
    var y = math.max(gap, (size.height - block) / 2);
    positionChild(top, Offset(0, y));
    y += topHeight;
    positionChild(board, Offset((size.width - boardSize.width) / 2, y));
    y += boardSize.height;
    positionChild(bottom, Offset(0, y));
  }

  @override
  bool shouldRelayout(_GameAreaLayout oldDelegate) => false;
}
