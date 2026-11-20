import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/online_game/automatch_controller.dart';
import 'package:tengen/src/view/home/home_screen.dart';
import 'package:tengen/src/view/online_game/online_game_screen.dart';
import 'package:tengen/src/view/play/automatch_screen.dart';

/// The home screen, and what must work wherever the user is: the game found by the automatch
/// opens, whichever screen started the search, and a bar shows a search that goes on.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final automatch = ref.watch(automatchProvider);

    ref.listen(automatchProvider, (_, next) {
      if (next is AutomatchFound) {
        ref.read(automatchProvider.notifier).reset();
        Navigator.of(
          context,
          rootNavigator: true,
        ).push(MaterialPageRoute<void>(builder: (_) => OnlineGameScreen(gameId: next.gameId)));
      }
    });

    return Scaffold(
      body: const HomeScreen(),
      bottomNavigationBar: automatch is AutomatchSearching
          ? _SearchingBar(automatch.settings)
          : null,
    );
  }
}

/// Shown at the bottom of the home screen while the automatch looks for an opponent.
class _SearchingBar extends ConsumerWidget {
  const _SearchingBar(this.settings);

  final AutomatchSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.primaryContainer,
      child: InkWell(
        onTap: () => Navigator.of(
          context,
          rootNavigator: true,
        ).push(MaterialPageRoute<void>(builder: (_) => const AutomatchScreen())),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 10, 10),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Looking for an opponent · ${settings.size}×${settings.size} '
                    '${settings.speed.label.toLowerCase()}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.read(automatchProvider.notifier).cancel(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
