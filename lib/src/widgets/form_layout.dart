import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/widgets/segmented_choice.dart';

/// A form field with its label above.
class LabeledField extends StatelessWidget {
  const LabeledField(this.label, this.child, {super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

/// A scrolling form with its main button pinned at the bottom, above the system navigation bar.
/// The content is capped in width on tablets.
class FormWithAction extends StatelessWidget {
  const FormWithAction({required this.children, required this.action, super.key});

  final List<Widget> children;
  final Widget action;

  static const maxWidth = 560.0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxWidth),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
              ),
            ),
          ],
        ),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: SizedBox(width: double.infinity, height: 52, child: action),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

Widget boardSizeSelector(int size, ValueChanged<int> onChanged) => SegmentedChoice<int>(
  choices: const [Choice(9, '9×9'), Choice(13, '13×13'), Choice(19, '19×19')],
  selected: size,
  onChanged: onChanged,
);
