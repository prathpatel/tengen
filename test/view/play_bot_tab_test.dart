import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/view/online_game/online_game_screen.dart';
import 'package:tengen/src/view/play/play_screen.dart';

import '../fakes.dart';
import '../model/ogs/bots_test.dart' show botJson;

void main() {
  testWidgets('challenges the chosen OGS bot and opens the game', (tester) async {
    final posts = <http.Request>[];
    final (:container, :sockets) = await makeContainer(
      http: (r) {
        if (r.url.path == '/api/v1/ui/config') {
          return {
            'user': {'id': 42, 'username': 'alice', 'ranking': 20},
            'user_jwt': 'jwt',
          };
        }
        if (r.method == 'POST') {
          posts.add(r);
          return {'challenge': 5, 'game': 77};
        }
        return null;
      },
    );
    addTearDown(container.dispose);
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PlayScreen(tab: PlayTab.computer)),
      ),
    );
    await tester.pump();
    sockets.single.serverSend('active-bots', {
      '1': botJson(id: 1, username: 'katago-micro', ranking: 38, sizes: [19]),
      '2': botJson(id: 2, username: 'amybot-beginner', ranking: 5),
      '3': botJson(id: 3, username: 'GnuGo', ranking: 19),
    });
    await tester.pumpAndSettle();

    // The bots of the player's strength (12k) first.
    expect(find.text('GnuGo'), findsOneWidget);
    expect(find.text('amybot-beginner'), findsNothing);
    expect(find.text('Choose a computer opponent'), findsOneWidget);

    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    expect(find.text('KataGo'), findsOneWidget);
    // 9×9 by default: KataGo micro only plays 19×19 here, and says so.
    expect(find.text('Plays on 19×19'), findsOneWidget);
    await tester.tap(find.text('Intermediate'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('GnuGo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play GnuGo'));
    await tester.pump();
    await tester.pump();
    expect(posts.single.url.path, '/api/v1/players/3/challenge');
    expect((jsonDecode(posts.single.body) as Map)['game'], containsPair('width', 9));
    expect(find.textContaining('Waiting for GnuGo'), findsOneWidget);

    sockets.single.serverSend('game/77/gamedata', {'game_id': 77, 'phase': 'play'});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(OnlineGameScreen), findsOneWidget);
  });
}
