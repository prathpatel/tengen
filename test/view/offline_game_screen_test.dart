import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/offline_game/offline_game_controller.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/view/offline_game/offline_game_screen.dart';
import 'package:tengen/src/widgets/goban.dart';

const setup = OfflineGameSetup(opponent: OfflineOpponent.human);

Future<ProviderContainer> pumpScreen(WidgetTester tester, {required bool confirmMoves}) async {
  SharedPreferences.setMockInitialValues({'prefs.confirmMoves': confirmMoves});
  final prefs = await SharedPreferences.getInstance();
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MaterialApp(home: OfflineGameScreen(setup: setup)),
    ),
  );
  return ProviderScope.containerOf(tester.element(find.byType(OfflineGameScreen)));
}

/// The global position of an intersection of the board.
Offset pointOffset(WidgetTester tester, Point p) {
  final box = tester.getRect(
    find.descendant(of: find.byType(Goban), matching: find.byType(CustomPaint)),
  );
  final geometry = GobanGeometry(box.size, 9, 9, coordinates: true);
  return box.topLeft + geometry.offsetOf(p);
}

void main() {
  testWidgets('a tap plays a stone', (tester) async {
    final container = await pumpScreen(tester, confirmMoves: false);
    await tester.tapAt(pointOffset(tester, const Point(2, 6)));
    await tester.pump();
    final game = container.read(offlineGameProvider(setup)).game;
    expect(game.board[const Point(2, 6)], StoneColor.black);
    expect(find.text('Black'), findsOneWidget);
  });

  testWidgets('with confirmation, the second tap plays', (tester) async {
    final container = await pumpScreen(tester, confirmMoves: true);
    final offset = pointOffset(tester, const Point(4, 4));
    await tester.tapAt(offset);
    await tester.pump();
    expect(container.read(offlineGameProvider(setup)).game.moveCount, 0);
    await tester.tapAt(offset);
    await tester.pump();
    expect(
      container.read(offlineGameProvider(setup)).game.board[const Point(4, 4)],
      StoneColor.black,
    );
  });

  testWidgets('passing twice goes to counting, shown in the title and the action bar', (
    tester,
  ) async {
    await pumpScreen(tester, confirmMoves: false);
    final boardBefore = tester.getRect(find.byType(Goban));
    await tester.tap(find.byTooltip('Pass'));
    await tester.pump();
    expect(find.text('Passed'), findsOneWidget);
    await tester.tap(find.byTooltip('Pass'));
    await tester.pump();
    expect(find.textContaining('Counting · W+6.5'), findsOneWidget);
    // Messages never take room from the board.
    expect(tester.getRect(find.byType(Goban)), boardBefore);
    await tester.tap(find.widgetWithText(FilledButton, 'Accept'));
    await tester.pumpAndSettle();
    expect(find.text('Game over · W+6.5'), findsOneWidget);
  });

  testWidgets('the move list and arrows show earlier positions', (tester) async {
    final container = await pumpScreen(tester, confirmMoves: false);
    await tester.tapAt(pointOffset(tester, const Point(2, 2)));
    await tester.pump();
    await tester.tapAt(pointOffset(tester, const Point(6, 6)));
    await tester.pump();
    // The move list shows both moves with their coordinates.
    expect(find.text('C7'), findsOneWidget);
    expect(find.text('G3'), findsOneWidget);

    Board shownBoard() => tester.widget<Goban>(find.byType(Goban)).board;

    await tester.tap(find.byTooltip('Previous move'));
    await tester.pump();
    expect(shownBoard()[const Point(6, 6)], isNull);

    // Moves cannot be played while looking at an earlier position.
    await tester.tapAt(pointOffset(tester, const Point(4, 4)));
    await tester.pump();
    expect(container.read(offlineGameProvider(setup)).game.moveCount, 2);

    // Tapping a move in the list jumps to it; the last one returns to the game.
    await tester.tap(find.text('G3'));
    await tester.pump();
    expect(shownBoard()[const Point(6, 6)], StoneColor.white);
    // Back on the last move, moves can be played again.
    await tester.tapAt(pointOffset(tester, const Point(4, 4)));
    await tester.pump();
    expect(container.read(offlineGameProvider(setup)).game.moveCount, 3);
  });

  testWidgets('resigning shows the result dialog', (tester) async {
    await pumpScreen(tester, confirmMoves: false);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resign'));
    await tester.pumpAndSettle();
    // The confirmation dialog.
    await tester.tap(find.widgetWithText(FilledButton, 'Resign'));
    await tester.pumpAndSettle();
    expect(find.text('W+R'), findsWidgets);
    expect(find.text('Black resigned · White is victorious'), findsOneWidget);
    expect(find.text('Analysis board'), findsOneWidget);
    // Closed, the dialog comes back from the info button of the action bar.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.byTooltip('Pass'), findsNothing);
    await tester.tap(find.byTooltip('Result'));
    await tester.pumpAndSettle();
    expect(find.text('Black resigned · White is victorious'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('New game')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('W+R'), findsNothing);
  });
}
