import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/coordinates.dart';
import 'package:tengen/src/model/puzzle/puzzle.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/widgets/game_layout.dart';
import 'package:tengen/src/widgets/goban.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: GameTitle(
          icon: Icons.extension_outlined,
          title: puzzle?.name.isNotEmpty ?? false ? puzzle!.name : 'Puzzle',
          subtitle: [
            if (puzzle != null) puzzle.typeLabel,
            if (index >= 0) '${index + 1} of ${summary!.length}',
          ].join(' · '),
        ),
        actions: [
          if (puzzle?.description != null)
            IconButton(
              tooltip: 'About this collection',
              icon: const Icon(Icons.info_outline),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (_) => SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Text(puzzle!.description!),
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

class _PuzzleBody extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(puzzleProvider(puzzleId).notifier);
    final prefs = ref.watch(preferencesProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final puzzle = state.puzzle;
    final viewport = GobanViewport.around(puzzle.board, puzzle.interestingPoints);

    final (Color bg, Color fg, IconData icon) = switch (state.status) {
      PuzzleStatus.correct => (Colors.green.shade700, Colors.white, Icons.check_circle),
      PuzzleStatus.wrong => (scheme.errorContainer, scheme.onErrorContainer, Icons.cancel),
      PuzzleStatus.solving => (
        scheme.surfaceContainerHigh,
        scheme.onSurface,
        Icons.lightbulb_outline,
      ),
    };

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Icon(icon, color: fg),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  state.opponentThinking ? '…' : state.message,
                  style: theme.textTheme.titleSmall?.copyWith(color: fg),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!puzzle.hasSolution)
                Text('No solution', style: theme.textTheme.labelSmall?.copyWith(color: fg)),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Goban(
              board: state.game.board,
              viewport: viewport,
              theme: prefs.boardTheme,
              blackStones: prefs.blackStones,
              whiteStones: prefs.whiteStones,
              showCoordinates: prefs.showCoordinates,
              confirmMoves: prefs.confirmMoves,
              lastMove: state.game.position.lastMove?.point,
              toPlay: state.canPlay ? state.game.toMove : null,
              onPlay: (p) {
                final error = controller.play(p);
                if (error != null) showSnack(context, error.message);
              },
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3))),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GameAction(
                    icon: Icons.refresh,
                    tooltip: 'Try again',
                    onPressed: state.game.moveCount > 0 ? controller.retry : null,
                  ),
                  GameAction(
                    icon: Icons.lightbulb_outline,
                    tooltip: 'Hint',
                    onPressed: state.canPlay
                        ? () {
                            final hint = controller.hint();
                            showSnack(
                              context,
                              hint.isEmpty
                                  ? 'No hint for this position'
                                  : 'Try ${hint.map((p) => prettyCoordinate(p, puzzle.board.height)).join(' or ')}',
                            );
                          }
                        : null,
                  ),
                  GameAction(
                    icon: Icons.chevron_left,
                    tooltip: 'Previous puzzle',
                    large: true,
                    onPressed: onPrevious,
                  ),
                  GameAction(
                    icon: Icons.chevron_right,
                    tooltip: 'Next puzzle',
                    large: true,
                    onPressed: onNext,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
