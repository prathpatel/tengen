import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/app.dart';
import 'package:tengen/src/model/learn/learning_hub.dart';
import 'package:tengen/src/model/online_game/automatch_controller.dart';
import 'package:tengen/src/view/settings/settings_screen.dart';

import '../fakes.dart';
import '../model/ogs/bots_test.dart' show botJson;

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
          void answerGameLists() {
            for (final m in sockets.single.sentCommands('gamelist/query').toList()) {
              sockets.single.serverReply(m[2]! as int, {'results': <Object?>[]});
            }
          }

          // Home: Play, with board, time and opponent.
          expect(find.text('Find a game'), findsOneWidget);
          expect(find.byTooltip('alice'), findsOneWidget);
          answerGameLists();
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull, reason: 'home');
          await tester.tap(find.text('13×13'));
          await tester.pumpAndSettle();
          expect(container.read(automatchSettingsProvider).size, 13);
          await tester.tap(find.text('9×9'));
          await tester.pumpAndSettle();

          // My games and History.
          await tester.tap(find.text('My games'));
          await tester.pumpAndSettle();
          expect(find.text('No ongoing games. Start one from Play.'), findsOneWidget);
          await tester.tap(find.text('History'));
          await tester.pumpAndSettle();
          expect(find.textContaining('vs a-very-long-opponent-username-indeed'), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'history');
          await tester.tap(find.text('Play'));
          await tester.pumpAndSettle();

          // A game on this phone opens the new game sheet; its three tabs.
          await tester.ensureVisible(find.text('On this phone'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('On this phone'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Set up the game'));
          await tester.pumpAndSettle();
          expect(find.text('Start game'), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'offline');
          Finder sheetTab(String label) =>
              find.descendant(of: find.byType(TabBar), matching: find.text(label));
          await tester.tap(sheetTab('Online'));
          await tester.pumpAndSettle();
          expect(find.text('BOARD SIZE'), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text('Required'),
            120,
            scrollable: find
                .descendant(of: find.byType(TabBarView), matching: find.byType(Scrollable))
                .first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Required'));
          await tester.pump();
          expect(find.textContaining('Find opponent · 9×9'), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'online');
          await tester.tap(sheetTab('Computer'));
          // The bot list loads until the server sends it (a spinner: no settling).
          await tester.pump(const Duration(milliseconds: 500));
          sockets.single.serverSend('active-bots', {
            '1': botJson(id: 1, username: 'a-bot-with-a-rather-long-name-indeed', ranking: 20),
            '2': botJson(id: 2, username: '1d-kgs-humanlike-kata', ranking: 29.4, sizes: [19]),
          });
          await tester.pumpAndSettle();
          expect(find.text('Choose a computer opponent'), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'computer');
          await tester.tap(find.byTooltip('Close'));
          await tester.pumpAndSettle();

          // Puzzles, Learn, Watch and Profile are tabs of the bottom bar.
          Future<void> openTab(String tab, String expected) async {
            await tester.tap(find.byTooltip(tab));
            await tester.pump(const Duration(milliseconds: 500));
            answerGameLists();
            await tester.pump(const Duration(milliseconds: 300));
            expect(find.text(expected), findsWidgets, reason: tab);
            expect(tester.takeException(), isNull, reason: tab);
          }

          await openTab('Puzzles', 'TOP COLLECTIONS');
          await openTab('Learn', 'COURSE');
          await openTab('Watch', 'Updated live');
          await openTab('Profile', 'Settings');
          // The other tabs are out of sight.
          expect(find.text('Updated live'), findsNothing);

          // From the profile: My games, the board, the OGS profile.
          await tester.tap(find.text('My games'));
          await tester.pumpAndSettle();
          expect(find.text('vs a-very-long-opponent-username-indeed'), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'my games');
          await tester.pageBack();
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Board and stones'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Board and stones'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('Stone sound'),
            200,
            scrollable: find
                .descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable))
                .first,
          );
          expect(tester.takeException(), isNull, reason: 'settings');
          await tester.pageBack();
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Profile on OGS'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Profile on OGS'));
          await tester.pumpAndSettle();
          expect(find.text('Open on OGS'), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'profile');

          // Tear down inside the test so that the socket timers are cancelled.
          await tester.pumpWidget(const SizedBox());
          container.dispose();
          await tester.binding.setSurfaceSize(null);
        },
      );
    }
  }
}
