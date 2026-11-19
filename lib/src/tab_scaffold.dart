import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/view/home/home_tab_screen.dart';
import 'package:tengen/src/view/more/more_tab_screen.dart';
import 'package:tengen/src/view/play/play_tab_screen.dart';
import 'package:tengen/src/view/watch/watch_tab_screen.dart';

enum BottomTab {
  home('Home', Icons.home_outlined, Icons.home),
  play('Play', Icons.sports_esports_outlined, Icons.sports_esports),
  watch('Watch', Icons.live_tv_outlined, Icons.live_tv),
  more('More', Icons.menu, Icons.menu);

  const BottomTab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  Widget get rootScreen => switch (this) {
    home => const HomeTabScreen(),
    play => const PlayTabScreen(),
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
/// Game screens are pushed on the root navigator, above the tab bar.
class MainTabScaffold extends ConsumerWidget {
  const MainTabScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentTabProvider);
    final navigator = tabNavigatorKeys[current]!;
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
        bottomNavigationBar: NavigationBar(
          selectedIndex: current.index,
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
      ),
    );
  }
}
