import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/result.dart';

/// An action of the result dialog. The dialog closes before [onPressed] runs.
typedef ResultAction = ({String label, VoidCallback onPressed, bool primary});

/// Announces the end of a game, as the lichess app does: the result in large type, how it
/// ended, and what to do next.
Future<void> showResultDialog(
  BuildContext context, {
  required GameResultText result,
  required List<ResultAction> actions,
}) => showDialog<void>(
  context: context,
  builder: (dialogContext) {
    final theme = Theme.of(dialogContext);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              result.short,
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              result.description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 20),
            for (final action in actions)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: action.primary
                      ? FilledButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            action.onPressed();
                          },
                          child: Text(action.label),
                        )
                      : FilledButton.tonal(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            action.onPressed();
                          },
                          child: Text(action.label),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  },
);
