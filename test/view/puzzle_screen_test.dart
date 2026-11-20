import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/puzzle/puzzle.dart';
import 'package:tengen/src/view/puzzle/puzzle_screen.dart';
import 'package:tengen/src/widgets/goban.dart';

import '../fakes.dart';
import '../model/puzzle/puzzle_test.dart' show puzzleJson;

/// [puzzleJson], with the author's comment on the right first move.
Map<String, Object?> commented() {
  final puzzle = Map<String, Object?>.of(puzzleJson['puzzle']! as Map<String, Object?>);
  final tree = Map<String, Object?>.of(puzzle['move_tree']! as Map<String, Object?>);
  final branches = [...tree['branches']! as List<Object?>];
  branches[0] = {
    ...branches[0]! as Map<String, Object?>,
    'text': 'The vital point is on the edge.',
  };
  return {
    ...puzzleJson,
    'puzzle': {
      ...puzzle,
      'move_tree': {...tree, 'branches': branches},
    },
  };
}

void main() {
  testWidgets('the hint shows the move, and the comment the author wrote on it', (tester) async {
    final (:container, sockets: _) = await makeContainer(
      http: (r) => switch (r.url.path) {
        '/api/v1/ui/config' => guestConfig,
        '/api/v1/puzzles/1' => commented(),
        _ => null,
      },
    );
    addTearDown(container.dispose);
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PuzzleScreen(puzzleId: 1)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Black to play'), findsOneWidget);
    // The cropped board fills its width: no empty strip on a side.
    final paint = tester.getSize(
      find.descendant(of: find.byType(Goban), matching: find.byType(CustomPaint)).first,
    );
    final goban = tester.widget<Goban>(find.byType(Goban));
    final view = goban.viewport!;
    final geometry = GobanGeometry(
      paint,
      view.columns,
      view.rows,
      coordinates: goban.showCoordinates,
    );
    expect(geometry.cell * (view.columns - 1 + 2 * geometry.margin), closeTo(paint.width, 1));
    expect(geometry.cell * (view.rows - 1 + 2 * geometry.margin), closeTo(paint.height, 1));
    // The comment of the start of the puzzle.
    expect(find.text('Black to kill.'), findsOneWidget);

    await tester.tap(find.byTooltip('Hint'));
    await tester.pump();
    // (4, 2) on a 9×9 board is E7.
    expect(find.text('Try E7'), findsOneWidget);
    expect(find.text('The vital point is on the edge.'), findsOneWidget);

    // A second tap hides it.
    await tester.tap(find.byTooltip('Hint'));
    await tester.pump();
    expect(find.text('Try E7'), findsNothing);
  });

  testWidgets('a wrong move outside the tree does not repeat the start comment', (tester) async {
    final (:container, sockets: _) = await makeContainer(
      http: (r) => switch (r.url.path) {
        '/api/v1/ui/config' => guestConfig,
        '/api/v1/puzzles/1' => commented(),
        _ => null,
      },
    );
    addTearDown(container.dispose);
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PuzzleScreen(puzzleId: 1)),
      ),
    );
    await tester.pumpAndSettle();
    container.read(puzzleProvider(1).notifier).play(const Point(8, 8));
    await tester.pumpAndSettle();
    expect(find.text('Not the answer'), findsOneWidget);
    expect(find.text('Tap Retry to try again.'), findsOneWidget);
    expect(find.text('Black to kill.'), findsNothing);
  });
}
