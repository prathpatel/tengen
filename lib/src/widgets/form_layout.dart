import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/widgets/segmented_choice.dart';

/// A form field with its label above.
class LabeledField extends StatelessWidget {
  const LabeledField(this.label, this.child, {super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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

/// A scrolling form with its main button pinned at the bottom, above the system navigation bar,
/// and an optional small note under it. The content is capped in width on tablets.
class FormWithAction extends StatelessWidget {
  const FormWithAction({required this.children, required this.action, this.footnote, super.key});

  final List<Widget> children;
  final Widget action;
  final String? footnote;

  static const maxWidth = 560.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
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
        SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: double.infinity, child: action),
                    if (footnote != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          footnote!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Widget boardSizeSelector(int size, ValueChanged<int> onChanged) => SegmentedChoice<int>(
  choices: const [Choice(9, '9×9'), Choice(13, '13×13'), Choice(19, '19×19')],
  selected: size,
  onChanged: onChanged,
);
