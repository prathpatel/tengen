import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/coordinates.dart';
import 'package:tengen/src/model/puzzle/puzzle.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/widgets/game_layout.dart';
import 'package:tengen/src/widgets/goban.dart';
import 'package:tengen/src/widgets/player_bar.dart';
import 'package:tengen/src/widgets/ui.dart';

/// Solves OGS puzzles, one after the other in their collection.
class PuzzleScreen extends ConsumerStatefulWidget {
  const PuzzleScreen({required this.puzzleId, super.key});

  final int puzzleId;

  @override
  ConsumerState<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends ConsumerState<PuzzleScreen> {
  late int _puzzleId = widget.puzzleId;

  void _goTo(int id) => setState(() => _puzzleId = id);

  @override
  Widget build(BuildContext context) {
    final provider = puzzleProvider(_puzzleId);
    final async = ref.watch(provider);
    final summary = ref.watch(collectionSummaryProvider(_puzzleId)).value;
    final index = summary?.indexWhere((e) => e.id == _puzzleId) ?? -1;
    final previous = index > 0 ? summary![index - 1].id : null;
    final next = summary != null && index >= 0 && index < summary.length - 1
        ? summary[index + 1].id
        : null;

    ref.listen(provider.select((s) => s.value?.puzzle), (_, puzzle) {
      if (puzzle != null) {
        ref
            .read(lastPuzzleProvider.notifier)
            .set(puzzle.id, [?puzzle.collectionName, puzzle.name].join(' · '));
      }
    });

    final puzzle = async.value?.puzzle;
    final description = puzzle?.description;
    return Scaffold(
      // A keyboard opened by a sheet over the game (the chat) must not squeeze the board.
      resizeToAvoidBottomInset: false,
      appBar: TopBar(
        title: index >= 0
            ? 'Puzzle ${index + 1} of ${summary!.length}'
            : (puzzle?.name.isNotEmpty ?? false ? puzzle!.name : 'Puzzle'),
        subtitle: [?puzzle?.collectionName, ?puzzle?.typeLabel].join(' · '),
        actions: [
          if (description != null)
            CircleIconButton(
              icon: Icons.info_outline_rounded,
              tooltip: 'About this collection',
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Text(description, style: Theme.of(context).textTheme.bodyLarge),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: switch (async) {
        AsyncData(:final value) => _PuzzleBody(
          puzzleId: _puzzleId,
          state: value,
          onPrevious: previous == null ? null : () => _goTo(previous),
          onNext: next == null ? null : () => _goTo(next),
        ),
        AsyncError(:final error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load the puzzle: $error', textAlign: TextAlign.center),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _PuzzleBody extends ConsumerStatefulWidget {
  const _PuzzleBody({
    required this.puzzleId,
    required this.state,
    required this.onPrevious,
    required this.onNext,
  });

  final int puzzleId;
  final PuzzleState state;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  ConsumerState<_PuzzleBody> createState() => _PuzzleBodyState();
}

class _PuzzleBodyState extends ConsumerState<_PuzzleBody> {
  /// The hint shown: the moves to try from the current position.
  Set<Point>? _hint;

  @override
  void didUpdateWidget(_PuzzleBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A hint is for one position.
    if (oldWidget.state.game.moveCount != widget.state.game.moveCount ||
        oldWidget.puzzleId != widget.puzzleId) {
      _hint = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final controller = ref.read(puzzleProvider(widget.puzzleId).notifier);
    final prefs = ref.watch(preferencesProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final puzzle = state.puzzle;
    final viewport = GobanViewport.around(puzzle.board, puzzle.interestingPoints);
    final toPlay = puzzle.toPlay == StoneColor.black ? 'Black' : 'White';
    final hint = _hint;

    // The card under the board: the result, the hint, or the comment of the position.
    final hintText = hint == null || hint.isEmpty
        ? null
        : hint.map((p) => prettyCoordinate(p, puzzle.board.height)).join(' or ');
    // The author's comment on the move played; a move outside the tree has none (the node is
    // still the one before it).
    final moveComment = state.node == puzzle.root ? null : state.node.text;
    final Widget? card = switch (state.status) {
      PuzzleStatus.correct => FeedbackCard(
        kind: FeedbackKind.success,
        title: 'Correct!',
        body: moveComment ?? 'Solved. Tap Next for the next puzzle.',
      ),
      PuzzleStatus.wrong => FeedbackCard(
        kind: FeedbackKind.failure,
        title: 'Not the answer',
        body: moveComment ?? 'Tap Retry to try again.',
      ),
      PuzzleStatus.solving when hint != null => FeedbackCard(
        kind: FeedbackKind.hint,
        title: hintText == null ? 'No hint for this position' : 'Try $hintText',
        // The comment the puzzle's author wrote on that move, if any.
        body:
            hint.map((p) => state.node.branchAt(p)?.text).nonNulls.firstOrNull ??
            (hintText == null ? null : 'Circled on the board.'),
      ),
      PuzzleStatus.solving when state.node.text != null => FeedbackCard(
        kind: FeedbackKind.comment,
        title: state.node.text!,
      ),
      _ => null,
    };

    return GameLayout(
      above: Padding(
        padding: const EdgeInsets.only(bottom: 14, top: 4),
        // A row, not a Center: the pill keeps its own height (the board takes the rest).
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 18, 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StoneIcon(puzzle.toPlay, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    state.opponentThinking
                        ? 'Answering…'
                        : !puzzle.hasSolution
                        ? '$toPlay to play · no solution given'
                        : '$toPlay to play',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      board: Goban(
        board: state.game.board,
        viewport: viewport,
        theme: prefs.boardTheme,
        blackStones: prefs.blackStones,
        whiteStones: prefs.whiteStones,
        showCoordinates: prefs.showCoordinates,
        confirmMoves: prefs.confirmMoves,
        sound: prefs.stoneSound,
        lastMove: state.game.position.lastMove?.point,
        toPlay: state.canPlay ? state.game.toMove : null,
        marks: {for (final p in hint ?? const <Point>{}) p: const ShapeMark(ShapeKind.circle)},
        onPlay: (p) {
          final error = controller.play(p);
          if (error != null) showSnack(context, error.message);
        },
      ),
      below: card ?? const SizedBox(height: 8),
      actions: RoundActionBar(
        actions: [
          RoundAction(
            icon: Icons.chevron_left_rounded,
            label: 'Previous',
            onPressed: widget.onPrevious,
          ),
          RoundAction(
            icon: Icons.lightbulb_outline_rounded,
            label: 'Hint',
            highlighted: hint != null,
            onPressed: state.canPlay
                ? () => setState(() => _hint = hint == null ? controller.hint() : null)
                : null,
          ),
          RoundAction(
            icon: Icons.refresh_rounded,
            label: 'Retry',
            onPressed: state.game.moveCount > 0 ? controller.retry : null,
          ),
          RoundAction(icon: Icons.chevron_right_rounded, label: 'Next', onPressed: widget.onNext),
        ],
      ),
    );
  }
}
