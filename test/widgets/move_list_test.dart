import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/game.dart';
import 'package:tengen/src/widgets/move_list.dart';

void main() {
  testWidgets('numbers the moves by pairs, as chess.com does', (tester) async {
    var selected = 5;
    final moves = [
      const GoMove(StoneColor.black, Point(3, 3)),
      const GoMove(StoneColor.white, Point(15, 15)),
      const GoMove(StoneColor.black, Point(15, 3)),
      const GoMove.pass(StoneColor.white),
      const GoMove(StoneColor.black, Point(3, 15)),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => MoveList(
              moves: moves,
              boardHeight: 19,
              selected: selected,
              onSelect: (i) => setState(() => selected = i),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. D16 Q4   2. Q16 Pass   3. D4
    for (final n in ['1.', '2.', '3.']) {
      expect(find.text(n), findsOneWidget);
    }
    expect(find.text('4.'), findsNothing);
    expect(find.text('5.'), findsNothing);
    for (final label in ['D16', 'Q4', 'Q16', 'D4']) {
      expect(find.text(label), findsOneWidget);
    }

    // Tapping the second move of the first pair selects position 2.
    await tester.tap(find.text('Q4'));
    await tester.pumpAndSettle();
    expect(selected, 2);
  });
}
