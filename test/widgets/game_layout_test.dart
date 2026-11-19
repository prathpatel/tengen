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
          banner: banner ? const GameBanner(title: 'Black passed', message: 'Pass too.') : null,
          actions: const [GameAction(icon: Icons.menu, tooltip: 'Menu')],
        ),
      ),
    );
    await tester.pumpWidget(layout(banner: false));
    final before = tester.getRect(find.byKey(const Key('board')));
    await tester.pumpWidget(layout(banner: true));
    expect(tester.getRect(find.byKey(const Key('board'))), before);
    expect(find.text('Black passed'), findsOneWidget);
  });
}
