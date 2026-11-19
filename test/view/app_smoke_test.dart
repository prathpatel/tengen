import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/app.dart';
import 'package:tengen/src/model/learn/learning_hub.dart';
import 'package:tengen/src/view/more/more_tab_screen.dart';
import 'package:tengen/src/view/settings/settings_screen.dart';

import '../fakes.dart';

const signedInConfig = {
  'user': {'id': 42, 'username': 'alice', 'ranking': 20},
  'user_jwt': 'jwt',
};

Map<String, Object?> collection(int id) => {
  'id': id,
  'name': 'Collection $id',
  'puzzle_count': 10,
  'min_rank': 5,
  'max_rank': 15,
  'rating': 4.5,
  'rating_count': 12,
  'starting_puzzle': {
    'id': id * 10,
    'width': 19,
    'height': 19,
    'initial_state': {'black': 'aabb', 'white': 'ccdd'},
  },
};

Object? fakeServer(Uri url) {
  final path = url.path;
  if (path == '/api/v1/ui/config') return signedInConfig;
  if (path == '/api/v1/players/42') {
    return {
      'id': 42,
      'username': 'alice',
      'ratings': {
        'overall': {'rating': 1450.0, 'deviation': 80.0},
      },
    };
  }
  if (path == '/api/v1/players/42/games') {
    return {
      'results': [
        {
          'id': 5,
          'width': 9,
          'height': 9,
          'outcome': 'Resignation',
          'black_lost': false,
          'white_lost': true,
          'ended': '2026-11-19T10:00:00Z',
          'players': {
            'black': {'id': 42, 'username': 'alice'},
            'white': {'id': 7, 'username': 'a-very-long-opponent-username-indeed', 'ranking': 25},
          },
        },
      ],
    };
  }
  if (path == '/api/v1/ui/overview') return {'active_games': <Object?>[]};
  final match = RegExp(r'^/api/v1/puzzles/collections/(\d+)$').firstMatch(path);
  if (match != null) return collection(int.parse(match.group(1)!));
  return null;
}

/// The real course, parsed once (the asset loading uses an isolate, which the test clock does not
/// run).
final realHub = LearningHub.fromJson(
  jsonDecode(File('assets/learning_hub/learning_hub.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  const sizes = [Size(320, 640), Size(360, 740), Size(412, 915), Size(800, 1280)];
  for (final size in sizes) {
    for (final textScale in [1.0, 1.3]) {
      testWidgets(
        'every screen renders without errors at ${size.width.toInt()}px, text ×$textScale',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = textScale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final (:container, :sockets) = await makeContainer(
            http: (r) => fakeServer(r.url),
            overrides: [learningHubProvider.overrideWith((ref) => realHub)],
          );
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(
            UncontrolledProviderScope(container: container, child: const TengenApp()),
          );
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.textContaining('alice'), findsWidgets);
          expect(find.text('Quick pairing'), findsOneWidget);
          // The recent games are further down the home screen.
          await tester.dragUntilVisible(
            find.text('vs a-very-long-opponent-username-indeed'),
            find.byType(ListView).first,
            const Offset(0, -250),
          );
          expect(tester.takeException(), isNull);

          for (final tab in ['Puzzles', 'Learn', 'Watch', 'More', 'Home']) {
            await tester.tap(find.text(tab).last);
            await tester.pump(const Duration(milliseconds: 500));
            // Answer the realtime game list requests.
            for (final m in sockets.single.sentCommands('gamelist/query').toList()) {
              sockets.single.serverReply(m[2]! as int, {'results': <Object?>[]});
            }
            await tester.pump(const Duration(milliseconds: 300));
            expect(tester.takeException(), isNull, reason: tab);
          }

          // The new game screen, both tabs.
          await tester.tap(find.text('Play').last);
          await tester.pumpAndSettle();
          expect(find.text('Handicaps'), findsOneWidget);
          await tester.tap(find.text('Required'));
          await tester.pump();
          expect(find.textContaining('Play 9×9 rapid'), findsOneWidget);
          await tester.tap(find.text('Offline'));
          await tester.pumpAndSettle();
          expect(find.text('Start game'), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'new game');
          await tester.pageBack();
          await tester.pumpAndSettle();

          // Settings, from the More tab.
          await tester.tap(find.text('More').last);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.scrollUntilVisible(
            find.text('Settings'),
            200,
            scrollable: find
                .descendant(of: find.byType(MoreTabScreen), matching: find.byType(Scrollable))
                .first,
          );
          await tester.ensureVisible(find.text('Settings'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Settings'));
          await tester.pump(const Duration(milliseconds: 500));
          await tester.scrollUntilVisible(
            find.text('Theme'),
            200,
            scrollable: find
                .descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable))
                .first,
          );
          expect(tester.takeException(), isNull, reason: 'settings');

          // Tear down inside the test so that the socket timers are cancelled.
          await tester.pumpWidget(const SizedBox());
          container.dispose();
          await tester.binding.setSurfaceSize(null);
        },
      );
    }
  }
}
