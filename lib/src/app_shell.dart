import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/online_game/automatch_controller.dart';
import 'package:tengen/src/theme.dart';
import 'package:tengen/src/view/home/home_screen.dart';
import 'package:tengen/src/view/learn/learn_sheet.dart';
import 'package:tengen/src/view/online_game/online_game_screen.dart';
import 'package:tengen/src/view/play/automatch_screen.dart';
import 'package:tengen/src/view/puzzle/puzzles_sheet.dart';
import 'package:tengen/src/view/shell_tab.dart';
import 'package:tengen/src/view/user/profile_tab.dart';
import 'package:tengen/src/view/watch/watch_sheet.dart';

/// The tabs of the app, in a solid bar at the bottom: Home, Puzzles, Learn, Watch and Profile.
/// Also what must work wherever the user is: the game found by the automatch opens, whichever
/// screen started the search, and a bar shows a search that goes on.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

extension on ShellTab {
  String get label => switch (this) {
    ShellTab.home => 'Home',
    ShellTab.puzzles => 'Puzzles',
    ShellTab.learn => 'Learn',
    ShellTab.watch => 'Watch',
    ShellTab.profile => 'Profile',
  };

  (IconData, IconData) get icons => switch (this) {
    ShellTab.home => (Icons.home_outlined, Icons.home_rounded),
    ShellTab.puzzles => (Icons.extension_outlined, Icons.extension_rounded),
    ShellTab.learn => (Icons.school_outlined, Icons.school_rounded),
    ShellTab.watch => (Icons.live_tv_outlined, Icons.live_tv_rounded),
    ShellTab.profile => (Icons.person_outline_rounded, Icons.person_rounded),
  };
}

class _AppShellState extends ConsumerState<AppShell> {
  /// The tabs opened so far; they keep their state (scroll, choices) once built.
  final _opened = <ShellTab>{ShellTab.home};

  void _select(ShellTab tab) => ref.read(shellTabProvider.notifier).select(tab);

  Widget _page(ShellTab tab) => switch (tab) {
    ShellTab.home => const HomeScreen(),
    ShellTab.puzzles => const PuzzlesSheet(page: true),
    ShellTab.learn => const LearnSheet(page: true),
    ShellTab.watch => const WatchSheet(page: true),
    ShellTab.profile => const ProfileTab(),
  };

  @override
  Widget build(BuildContext context) {
    final automatch = ref.watch(automatchProvider);
    final tab = ref.watch(shellTabProvider);
    _opened.add(tab);

    ref.listen(automatchProvider, (_, next) {
      if (next is AutomatchFound) {
        ref.read(automatchProvider.notifier).reset();
        Navigator.of(
          context,
          rootNavigator: true,
        ).push(MaterialPageRoute<void>(builder: (_) => OnlineGameScreen(gameId: next.gameId)));
      }
    });

    return PopScope(
      // Back from another tab goes home first.
      canPop: tab == ShellTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(ShellTab.home);
      },
      child: Scaffold(
        body: IndexedStack(
          index: tab.index,
          children: [
            // The other tabs keep their state but pause their animations; unopened ones are
            // not built yet.
            for (final t in ShellTab.values)
              if (_opened.contains(t))
                TickerMode(enabled: t == tab, child: _page(t))
              else
                const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (automatch is AutomatchSearching) _SearchingBar(automatch.settings),
            _TabBar(selected: tab, onSelect: _select),
          ],
        ),
      ),
    );
  }
}

/// The bottom bar: an icon and a label per tab, the selected one in the accent color.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onSelect});

  final ShellTab selected;
  final ValueChanged<ShellTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (final tab in ShellTab.values)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: tab == selected,
                    label: tab.label,
                    excludeSemantics: true,
                    child: Tooltip(
                      message: tab.label,
                      child: InkResponse(
                        onTap: () => onSelect(tab),
                        radius: 32,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              tab == selected ? tab.icons.$2 : tab.icons.$1,
                              size: 23,
                              color: tab == selected ? scheme.primary : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tab.label,
                              maxLines: 1,
                              textScaler: MediaQuery.textScalerOf(context)
                                  .clamp(maxScaleFactor: 1.1),
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: TengenSizes.navLabel,
                                color: tab == selected ? scheme.primary : scheme.onSurfaceVariant,
                                fontWeight: tab == selected ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
      child: InkWell(
        onTap: () => Navigator.of(
          context,
          rootNavigator: true,
        ).push(MaterialPageRoute<void>(builder: (_) => const AutomatchScreen())),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Looking for an opponent · ${settings.size}×${settings.size} '
                  '${settings.speed.label.toLowerCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
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
    );
  }
}
