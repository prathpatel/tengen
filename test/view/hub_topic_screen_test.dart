import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/learn/learning_hub.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/view/learn/hub_topic_screen.dart';
import 'package:tengen/src/widgets/goban.dart';

/// A lesson in the format produced by tool/learning_hub/convert.mjs.
final hub = LearningHub.fromJson(const {
  'sections': [
    {
      'title': 'Fundamentals',
      'topics': [
        {
          'id': 'demo',
          'title': 'Demo',
          'subtext': 'All page kinds',
          'pages': [
            {
              'config': {
                'width': 9,
                'height': 9,
                'initial_state': {'black': 'ee', 'white': 'ddde'},
                'marks': {'cross': 'edeffe'},
                'phase': 'finished',
              },
              'choice': {
                'question': 'Count the liberties of the black chain.',
                'options': [
                  {'value': '3', 'label': '3'},
                  {'value': '4', 'label': '4'},
                ],
                'correct': '3',
              },
            },
            {
              'text': 'Capture the white stone.',
              'config': {
                'width': 9,
                'height': 9,
                'initial_player': 'black',
                'initial_state': {'black': 'dcdecd', 'white': 'dd'},
                'move_tree': {
                  'x': -1,
                  'y': -1,
                  'branches': [
                    {'x': 4, 'y': 3, 'correct_answer': true, 'branches': <Object?>[]},
                  ],
                },
              },
            },
            {
              'text': 'Click Pass.',
              'config': {'width': 9, 'height': 9},
              'special': {'type': 'button', 'label': 'Pass'},
            },
            {
              'text': 'Remove the dead stone.',
              'config': {
                'width': 9,
                'height': 9,
                'initial_state': {'black': 'aa', 'white': 'babbab'},
              },
              'special': {'type': 'remove', 'stones': 'aa'},
            },
          ],
        },
      ],
    },
  ],
});

Future<ProviderContainer> pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({'prefs.confirmMoves': false});
  final prefs = await SharedPreferences.getInstance();
  await tester.binding.setSurfaceSize(const Size(400, 860));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        learningHubProvider.overrideWith((ref) => hub),
        hubReplyDelayProvider.overrideWithValue(Duration.zero),
      ],
      child: const MaterialApp(home: HubTopicScreen(topicId: 'demo')),
    ),
  );
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(HubTopicScreen)));
}

Offset at(WidgetTester tester, Point p) {
  final box = tester.getRect(
    find.descendant(of: find.byType(Goban), matching: find.byType(CustomPaint)),
  );
  return box.topLeft + GobanGeometry(box.size, 9, 9, coordinates: true).offsetOf(p);
}

void main() {
  testWidgets('all page kinds, with retry, progress and next', (tester) async {
    final container = await pump(tester);

    // Multiple choice: a wrong answer fails, retry, then the right one.
    expect(find.text('Count the liberties of the black chain.'), findsOneWidget);
    expect(tester.widget<Goban>(find.byType(Goban)).marks, hasLength(3));
    await tester.tap(find.widgetWithText(FilledButton, '4'));
    await tester.pump();
    expect(find.text('Puzzle failed!'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '3'));
    await tester.pump();
    expect(find.text('Great job!'), findsOneWidget);
    expect(container.read(hubProgressProvider), {'demo/0'});
    await tester.tap(find.text('Next'));
    await tester.pump();

    // A move: off the tree fails, the answer succeeds.
    expect(find.text('Capture the white stone.'), findsOneWidget);
    await tester.tapAt(at(tester, const Point(8, 8)));
    await tester.pump();
    expect(find.text('Puzzle failed!'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.tapAt(at(tester, const Point(4, 3)));
    await tester.pump();
    expect(find.text('Great job!'), findsOneWidget);
    expect(tester.widget<Goban>(find.byType(Goban)).board[const Point(3, 3)], isNull);
    await tester.tap(find.text('Next'));
    await tester.pump();

    // A button page.
    await tester.tap(find.widgetWithText(FilledButton, 'Pass'));
    await tester.pump();
    expect(find.text('Great job!'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();

    // Stone removal.
    await tester.tapAt(at(tester, const Point(0, 0)));
    await tester.pump();
    expect(find.text('Great job!'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(container.read(hubProgressProvider), hasLength(4));
  });
}
