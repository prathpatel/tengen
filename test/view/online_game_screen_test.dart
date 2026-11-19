import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/view/online_game/online_game_screen.dart';

import '../fakes.dart';

Map<String, Object?> finishedGame() => {
  'game_id': 7,
  'game_name': 'Test game',
  'width': 9,
  'height': 9,
  'rules': 'japanese',
  'komi': 6.5,
  'handicap': 0,
  'initial_player': 'black',
  'initial_state': {'black': '', 'white': ''},
  'moves': [
    [2, 2, 1000],
    [6, 6, 1000],
  ],
  'phase': 'finished',
  'outcome': 'Resignation',
  'winner': 99,
  'players': {
    'black': {'id': 42, 'username': 'alice', 'rank': 25},
    'white': {'id': 99, 'username': 'bob', 'rank': 27},
  },
  'time_control': {'system': 'fischer', 'initial_time': 300, 'time_increment': 5},
};

void main() {
  testWidgets('a finished game shows its result again from the info button', (tester) async {
    final (:container, :sockets) = await makeContainer();
    addTearDown(container.dispose);
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnlineGameScreen(gameId: 7)),
      ),
    );
    await tester.pump();
    sockets.single.serverSend('game/7/gamedata', finishedGame());
    await tester.pumpAndSettle();

    // Opened after the end: no dialog until asked.
    expect(find.byType(Dialog), findsNothing);
    await tester.tap(find.byTooltip('Result'));
    await tester.pumpAndSettle();
    expect(find.text('W+R'), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.textContaining('White is victorious'),
      ),
      findsOneWidget,
    );
    expect(find.text('Analysis board'), findsOneWidget);
  });
}
