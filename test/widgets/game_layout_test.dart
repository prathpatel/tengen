import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/widgets/game_layout.dart';
import 'package:tengen/src/widgets/player_bar.dart';

Widget layout() => const MaterialApp(
  home: Scaffold(
    body: GameLayout(
      moveList: SizedBox(height: 44),
      topPlayer: PlayerBar(
        color: StoneColor.white,
        name: 'Computer',
        captures: 3,
        komi: 6.5,
        active: false,
        note: 'Passed',
      ),
      bottomPlayer: PlayerBar(color: StoneColor.black, name: 'You', captures: 30, active: true),
      board: AspectRatio(
        aspectRatio: 1,
        child: ColoredBox(key: Key('board'), color: Colors.brown),
      ),
      actions: [
        GameAction(icon: Icons.menu, tooltip: 'Menu'),
        GameTextAction(label: 'Accept', primary: true, onPressed: null),
      ],
    ),
  ),
);

void main() {
  for (final textScale in [1.0, 1.3]) {
    testWidgets('the board uses the full width of a phone, text ×$textScale', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.binding.setSurfaceSize(const Size(412, 860));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(layout());
      expect(tester.getRect(find.byKey(const Key('board'))).width, 412);
      expect(find.text('Passed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('on a short screen the board fits the height', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(layout());
    final board = tester.getRect(find.byKey(const Key('board')));
    expect(board.width, lessThan(412));
    expect(board.bottom, lessThan(tester.getRect(find.text('You')).top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the players and the board are centered between the moves and the buttons', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(layout());
    final players = tester.getRect(find.byType(PlayerBar).first);
    final lastPlayer = tester.getRect(find.byType(PlayerBar).last);
    final moves = tester.getRect(find.byType(SizedBox).first);
    final buttons = tester.getRect(find.byTooltip('Menu'));
    expect(players.top, lessThan(lastPlayer.top));
    final above = players.top - moves.bottom;
    // The action bar: 4 px of padding above its 56 px row, the buttons centered in it.
    final barTop = buttons.center.dy - 28 - 4;
    final below = barTop - lastPlayer.bottom;
    expect(above, greaterThan(10));
    expect((above - below).abs(), lessThanOrEqualTo(1));
  });
}
