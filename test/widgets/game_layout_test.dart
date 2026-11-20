import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/widgets/game_layout.dart';
import 'package:tengen/src/widgets/player_bar.dart';
import 'package:tengen/src/widgets/ui.dart';

Widget layout() => MaterialApp(
  home: Scaffold(
    body: GameLayout(
      above: const PlayerPill(
        color: StoneColor.white,
        name: 'Computer',
        detail: '3 captures · komi 6.5',
        active: false,
        note: 'Passed',
      ),
      below: const PlayerPill(
        color: StoneColor.black,
        name: 'You',
        detail: 'Your move · 30 captures',
        active: true,
        end: true,
      ),
      board: const AspectRatio(
        aspectRatio: 1,
        child: ColoredBox(key: Key('board'), color: Colors.brown),
      ),
      actions: RoundActionBar(
        actions: [
          RoundAction(icon: Icons.undo_rounded, label: 'Undo', onPressed: () {}),
          RoundAction(icon: Icons.arrow_forward_rounded, label: 'Pass', onPressed: () {}),
          RoundAction(icon: Icons.history_rounded, label: 'Moves', onPressed: () {}),
          const RoundAction(icon: Icons.flag_outlined, label: 'Resign', onPressed: null),
        ],
      ),
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

  testWidgets('the players and the board are centered above the actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(layout());
    final top = tester.getRect(find.byType(PlayerPill).first);
    final bottom = tester.getRect(find.byType(PlayerPill).last);
    const actionsTop = 900 - kGameActionsHeight;
    final above = top.top;
    final below = actionsTop - bottom.bottom;
    expect(above, greaterThan(10));
    expect((above - below).abs(), lessThanOrEqualTo(1));
  });

  testWidgets('the opponent is on the left and you on the right', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(layout());
    expect(tester.getRect(find.text('Computer')).left, lessThan(150));
    expect(tester.getRect(find.text('You')).right, greaterThan(250));
  });
}
