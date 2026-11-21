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
/// the selection is a pill that slides under the options; the options themselves never move.
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
    // A dark track with the selected option on a lighter pill that slides from one option to
    // the next, as in the Tengen design.
    final index = choices.indexWhere((c) => c.value == selected);
    final n = choices.length;
    const duration = Duration(milliseconds: 320);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: IntrinsicHeight(
          child: Stack(
            children: [
              if (index >= 0)
                Positioned.fill(
                  child: AnimatedAlign(
                    alignment: Alignment(n == 1 ? 0 : -1 + 2 * index / (n - 1), 0),
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    child: FractionallySizedBox(
                      widthFactor: 1 / n,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final choice in choices)
                    Expanded(
                      child: Semantics(
                        selected: choice.value == selected,
                        button: true,
                        child: Material(
                          type: MaterialType.transparency,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: enabled ? () => onChanged!(choice.value) : null,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: AnimatedDefaultTextStyle(
                                    duration: duration,
                                    style: theme.textTheme.titleMedium!.copyWith(
                                      fontSize: 17,
                                      color: choice.value == selected
                                          ? scheme.onSurface
                                          : scheme.onSurfaceVariant,
                                      fontWeight: choice.value == selected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (choice.icon != null) ...[
                                          Icon(
                                            choice.icon,
                                            size: 18,
                                            color: choice.value == selected
                                                ? scheme.onSurface
                                                : scheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        Text(choice.label, maxLines: 1),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
