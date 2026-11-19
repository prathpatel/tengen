import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/game.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/view/analysis/analysis_screen.dart';
import 'package:tengen/src/widgets/goban.dart';

void main() {
  testWidgets('explores a variation and goes back to the game', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = GoGame.create(width: 9).play(const Point(2, 2)).play(const Point(6, 6));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(home: AnalysisScreen(game: game)),
      ),
    );
    Board shown() => tester.widget<Goban>(find.byType(Goban)).board;
    Offset at(Point p) {
      final box = tester.getRect(
        find.descendant(of: find.byType(Goban), matching: find.byType(CustomPaint)),
      );
      return box.topLeft + GobanGeometry(box.size, 9, 9, coordinates: true).offsetOf(p);
    }

    expect(shown()[const Point(6, 6)], StoneColor.white);
    await tester.tap(find.byTooltip('Previous move'));
    await tester.pump();
    expect(shown()[const Point(6, 6)], isNull);

    // White plays elsewhere: a variation.
    await tester.tapAt(at(const Point(4, 4)));
    await tester.pump();
    expect(shown()[const Point(4, 4)], StoneColor.white);
    expect(find.text('Variation from move 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Back to the game'));
    await tester.pump();
    expect(find.text('Variation from move 2'), findsNothing);
    await tester.tap(find.byTooltip('Next move'));
    await tester.pump();
    expect(shown()[const Point(6, 6)], StoneColor.white);
    expect(shown()[const Point(4, 4)], isNull);
  });

  test('truncateGame keeps the first moves', () {
    final game = GoGame.create(width: 9).play(const Point(0, 0)).play(const Point(1, 1));
    expect(truncateGame(game, 1).moveCount, 1);
    expect(truncateGame(game, 5).moveCount, 2);
  });
}
