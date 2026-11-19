import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/widgets/segmented_choice.dart';

void main() {
  testWidgets('options keep the same width whatever is selected', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var selected = 'Required';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SegmentedChoice<String>(
              choices: const [
                Choice('Required', 'Required'),
                Choice('Standard', 'Standard'),
                Choice('Disabled', 'Disabled'),
              ],
              selected: selected,
              onChanged: (v) => setState(() => selected = v),
            ),
          ),
        ),
      ),
    );
    Rect rect(String label) =>
        tester.getRect(find.ancestor(of: find.text(label), matching: find.byType(Expanded)).first);
    final before = [
      for (final l in ['Required', 'Standard', 'Disabled']) rect(l),
    ];
    expect(before[0].width, closeTo(before[1].width, 0.5));
    expect(before[1].width, closeTo(before[2].width, 0.5));
    await tester.tap(find.text('Standard'));
    await tester.pump();
    expect(selected, 'Standard');
    expect([
      for (final l in ['Required', 'Standard', 'Disabled']) rect(l),
    ], before);
    // Labels stay on one line.
    expect(tester.getSize(find.text('Required')).height, lessThan(30));
  });
}
