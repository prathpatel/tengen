import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/utils/stone_sound.dart';
import 'package:tengen/src/widgets/goban.dart';

void main() {
  testWidgets('a stone placed clicks; stepping back through the moves does not', (tester) async {
    final played = <StoneColor>[];
    StoneSound.debugOnPlay = played.add;
    addTearDown(() => StoneSound.debugOnPlay = null);

    final empty = Board.empty(9, 9);
    final one = empty.withStones([const Point(2, 2)], StoneColor.black);
    final two = one.withStones([const Point(6, 6)], StoneColor.white);
    Future<void> show(Board board, Point? last, {bool sound = true}) => tester.pumpWidget(
      MaterialApp(
        home: Goban(board: board, lastMove: last, sound: sound),
      ),
    );

    await show(empty, null);
    await show(one, const Point(2, 2));
    await show(two, const Point(6, 6));
    expect(played, [StoneColor.black, StoneColor.white]);

    // Back one move: the stone goes away, no click.
    await show(one, const Point(2, 2));
    expect(played, hasLength(2));

    // Sound off.
    await show(two, const Point(6, 6), sound: false);
    expect(played, hasLength(2));
  });
}
