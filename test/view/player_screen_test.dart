import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/view/user/player_screen.dart';

import '../fakes.dart';

Map<String, Object?> finished(int id) => {
  'id': id,
  'width': 19,
  'height': 19,
  'outcome': 'Resignation',
  'black_lost': false,
  'white_lost': true,
  'ended': '2026-11-19T10:00:00Z',
  'players': {
    'black': {'id': 7, 'username': 'kuro'},
    'white': {'id': 1000 + id, 'username': 'opponent$id'},
  },
};

void main() {
  testWidgets('the profile lists its games without downloading each one', (tester) async {
    final requested = <String>{};
    final (:container, sockets: _) = await makeContainer(
      http: (r) {
        final path = r.url.path;
        if (path.startsWith('/api/v1/games/')) requested.add(path);
        return switch (path) {
          '/api/v1/ui/config' => guestConfig,
          '/api/v1/players/7' => {'id': 7, 'username': 'kuro'},
          '/api/v1/players/7/games' when r.url.queryParameters['page_size'] == '1' => {
            'count': 40,
            'results': <Object?>[],
          },
          '/api/v1/players/7/games' => {
            'results': [for (var i = 1; i <= 20; i++) finished(i)],
          },
          _ => null,
        };
      },
    );
    addTearDown(container.dispose);
    await tester.binding.setSurfaceSize(const Size(412, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PlayerScreen(playerId: 7)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('vs opponent1'), findsOneWidget);
    expect(find.text('vs opponent2'), findsOneWidget);
    // Nothing is downloaded per game: a phone must scroll a long list smoothly.
    expect(requested, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
