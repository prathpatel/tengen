import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/widgets/goban.dart';

/// A small, non interactive board, for game and puzzle previews.
class BoardThumbnail extends ConsumerWidget {
  const BoardThumbnail({
    required this.board,
    required this.size,
    this.lastMove,
    this.viewport,
    super.key,
  });

  final Board board;
  final double size;
  final Point? lastMove;
  final GobanViewport? viewport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(preferencesProvider.select((p) => p.boardTheme));
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox.square(
        dimension: size,
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: Goban(
              board: board,
              theme: theme,
              showCoordinates: false,
              lastMove: lastMove,
              viewport: viewport,
            ),
          ),
        ),
      ),
    );
  }
}
