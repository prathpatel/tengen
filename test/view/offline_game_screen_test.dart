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

  testWidgets('passing twice shows the counting banner', (tester) async {
    await pumpScreen(tester, confirmMoves: false);
    await tester.tap(find.text('Pass'));
    await tester.pump();
    expect(find.text('Black passed'), findsOneWidget);
    await tester.tap(find.text('Pass'));
    await tester.pump();
    expect(find.textContaining('Counting'), findsOneWidget);
    await tester.tap(find.text('Accept'));
    await tester.pump();
    expect(find.text('Game over: W+6.5'), findsOneWidget);
  });
}
