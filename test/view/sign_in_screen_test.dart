import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/view/auth/sign_in_screen.dart';
import 'package:tengen/src/widgets/goban.dart';

import '../fakes.dart';

void main() {
  testWidgets('a board across the top, the form below it', (tester) async {
    final (:container, sockets: _) = await makeContainer();
    addTearDown(container.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SignInScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(Goban)).width, 390);
    expect(find.text('Play Go online'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Play offline instead'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Play offline instead'), findsOneWidget);
  });
}
