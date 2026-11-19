import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/online_game/automatch_controller.dart';
import 'package:tengen/src/view/home/home_tab_screen.dart';
import 'package:tengen/src/view/learn/learn_tab_screen.dart';
import 'package:tengen/src/view/more/more_tab_screen.dart';
import 'package:tengen/src/view/online_game/online_game_screen.dart';
import 'package:tengen/src/view/puzzle/puzzle_tab_screen.dart';
import 'package:tengen/src/view/watch/watch_tab_screen.dart';

/// The bottom tabs, as in the lichess app.
enum BottomTab {
  home('Home', Icons.home_outlined, Icons.home_rounded),
  puzzles('Puzzles', Icons.extension_outlined, Icons.extension_rounded),
  learn('Learn', Icons.school_outlined, Icons.school_rounded),
  watch('Watch', Icons.live_tv_outlined, Icons.live_tv_rounded),
  more('More', Icons.menu_rounded, Icons.menu_rounded);

  const BottomTab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  Widget get rootScreen => switch (this) {
    home => const HomeTabScreen(),
    puzzles => const PuzzleTabScreen(),
    learn => const LearnTabScreen(),
    watch => const WatchTabScreen(),
    more => const MoreTabScreen(),
  };
}

final currentTabProvider = NotifierProvider<CurrentTabController, BottomTab>(
  CurrentTabController.new,
);

class CurrentTabController extends Notifier<BottomTab> {
  @override
  BottomTab build() => BottomTab.home;

  BottomTab get current => state;

  set current(BottomTab tab) => state = tab;
}

/// One navigator per tab, so that each tab keeps its own stack of screens (as in the lichess app).
final tabNavigatorKeys = {
  for (final tab in BottomTab.values) tab: GlobalKey<NavigatorState>(debugLabel: tab.name),
};

/// The main scaffold: a bottom navigation bar and the tabs' navigators.
///
/// Game screens are pushed on the root navigator, above the tab bar. This is also where a game
/// found by the automatch is opened, whichever screen started the search.
class MainTabScaffold extends ConsumerWidget {
  const MainTabScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentTabProvider);
    final automatch = ref.watch(automatchProvider);
    final navigator = tabNavigatorKeys[current]!;

    ref.listen(automatchProvider, (_, next) {
      if (next is AutomatchFound) {
        ref.read(automatchProvider.notifier).reset();
        Navigator.of(
          context,
          rootNavigator: true,
        ).push(MaterialPageRoute<void>(builder: (_) => OnlineGameScreen(gameId: next.gameId)));
      }
    });

    return NavigatorPopHandler(
      onPopWithResult: (_) => navigator.currentState?.maybePop(),
      child: Scaffold(
        body: IndexedStack(
          index: current.index,
          children: [
            for (final tab in BottomTab.values)
              HeroControllerScope.none(
                child: Navigator(
                  key: tabNavigatorKeys[tab],
                  onGenerateRoute: (settings) =>
                      MaterialPageRoute<void>(settings: settings, builder: (_) => tab.rootScreen),
                ),
              ),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (automatch is AutomatchSearching) _SearchingBar(automatch.settings),
            NavigationBar(
              selectedIndex: current.index,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                for (final tab in BottomTab.values)
                  NavigationDestination(
                    icon: Icon(tab.icon),
                    selectedIcon: Icon(tab.selectedIcon),
                    label: tab.label,
                  ),
              ],
              onDestinationSelected: (i) {
                final tab = BottomTab.values[i];
                if (tab == current) {
                  // Tapping the current tab goes back to its first screen.
                  tabNavigatorKeys[tab]!.currentState?.popUntil((r) => r.isFirst);
                } else {
                  ref.read(currentTabProvider.notifier).current = tab;
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown above the tab bar while the automatch looks for an opponent.
class _SearchingBar extends ConsumerWidget {
  const _SearchingBar(this.settings);

  final AutomatchSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Looking for an opponent · ${settings.size}×${settings.size} '
                '${settings.speed.label.toLowerCase()}',
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onPrimaryContainer),
              ),
            ),
            TextButton(
              onPressed: () => ref.read(automatchProvider.notifier).cancel(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
