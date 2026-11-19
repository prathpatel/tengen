import 'package:material_ui/material_ui.dart';

/// An option of a [SegmentedChoice].
@immutable
class Choice<T> {
  const Choice(this.value, this.label, {this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// A row of mutually exclusive options that always fills the available width.
///
/// Unlike [SegmentedButton], every option gets the same width whatever its label or selection,
/// labels stay on one line (shrinking when space is short, e.g. with large system fonts), and
/// the selection is shown by the fill only, so nothing moves when the selection changes.
class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    required this.choices,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<Choice<T>> choices;
  final T selected;

  /// Null disables the control.
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onChanged != null;
    final radius = BorderRadius.circular(24);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: scheme.outline),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, choice) in choices.indexed) ...[
                  if (i > 0) VerticalDivider(width: 1, thickness: 1, color: scheme.outline),
                  Expanded(
                    child: Semantics(
                      selected: choice.value == selected,
                      button: true,
                      child: Material(
                        color: choice.value == selected
                            ? scheme.secondaryContainer
                            : Colors.transparent,
                        child: InkWell(
                          onTap: enabled ? () => onChanged!(choice.value) : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (choice.icon != null) ...[
                                      Icon(
                                        choice.icon,
                                        size: 18,
                                        color: choice.value == selected
                                            ? scheme.onSecondaryContainer
                                            : scheme.onSurface,
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      choice.label,
                                      maxLines: 1,
                                      style: theme.textTheme.labelLarge?.copyWith(
                                        color: choice.value == selected
                                            ? scheme.onSecondaryContainer
                                            : scheme.onSurface,
                                        fontWeight: choice.value == selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
