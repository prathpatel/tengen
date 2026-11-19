import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/widgets/game_layout.dart';

void main() {
  testWidgets('a banner does not move the board', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Widget layout({required bool banner}) => MaterialApp(
      home: Scaffold(
        body: GameLayout(
          moveList: const SizedBox(height: 40),
          topPlayer: const SizedBox(height: 60),
          bottomPlayer: const SizedBox(height: 60),
          board: const AspectRatio(
            aspectRatio: 1,
            child: ColoredBox(key: Key('board'), color: Colors.brown),
          ),
          banner: banner
              ? const GameBanner(title: 'Black passed', message: 'Pass too.', compact: true)
              : null,
          actions: const [GameAction(icon: Icons.menu, tooltip: 'Menu')],
        ),
      ),
    );
    await tester.pumpWidget(layout(banner: false));
    final before = tester.getRect(find.byKey(const Key('board')));
    // The board uses the full width.
    expect(before.width, 400);
    await tester.pumpWidget(layout(banner: true));
    expect(tester.getRect(find.byKey(const Key('board'))), before);
    expect(find.text('Black passed · Pass too.'), findsOneWidget);
  });

  testWidgets('on a short screen a tall banner shrinks the board instead of hiding', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameLayout(
            topPlayer: const SizedBox(height: 60),
            bottomPlayer: const SizedBox(height: 60),
            board: const AspectRatio(
              aspectRatio: 1,
              child: ColoredBox(key: Key('board'), color: Colors.brown),
            ),
            banner: GameBanner(
              title: 'Counting',
              message: 'Tap the dead stones.',
              actions: [FilledButton(onPressed: () {}, child: const Text('Accept'))],
            ),
            actions: const [GameAction(icon: Icons.menu, tooltip: 'Menu')],
          ),
        ),
      ),
    );
    expect(tester.getRect(find.byKey(const Key('board'))).width, lessThan(400));
    // The banner's button is fully visible above the action bar.
    final accept = tester.getRect(find.text('Accept'));
    expect(accept.bottom, lessThan(tester.getRect(find.byTooltip('Menu')).top));
  });
}
