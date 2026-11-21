import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/auth/auth_controller.dart';
import 'package:tengen/src/model/online_game/automatch_controller.dart';
import 'package:tengen/src/view/home/home_screen.dart';
import 'package:tengen/src/view/learn/learn_sheet.dart';
import 'package:tengen/src/view/online_game/online_game_screen.dart';
import 'package:tengen/src/view/play/automatch_screen.dart';
import 'package:tengen/src/view/puzzle/puzzles_sheet.dart';
import 'package:tengen/src/view/shell_tab.dart';
import 'package:tengen/src/view/watch/watch_sheet.dart';
import 'package:tengen/src/widgets/ui.dart';

/// The tabs of the app, in a floating glass bar: Home, Puzzles, Learn, Watch, and your avatar
/// for the account. Also what must work wherever the user is: the game found by the automatch
/// opens, whichever screen started the search, and a bar shows a search that goes on.
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
  };

  (IconData, IconData) get icons => switch (this) {
    ShellTab.home => (Icons.home_outlined, Icons.home_rounded),
    ShellTab.puzzles => (Icons.extension_outlined, Icons.extension_rounded),
    ShellTab.learn => (Icons.school_outlined, Icons.school_rounded),
    ShellTab.watch => (Icons.live_tv_outlined, Icons.live_tv_rounded),
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
        body: Stack(
          children: [
            for (final t in ShellTab.values)
              if (_opened.contains(t))
                _FadingPage(key: ValueKey(t), active: t == tab, child: _page(t)),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SizeTransition(sizeFactor: animation, child: child),
                        ),
                        child: automatch is AutomatchSearching
                            ? _SearchingBar(automatch.settings)
                            : const SizedBox(width: double.infinity),
                      ),
                      _TabBar(selected: tab, onSelect: _select),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tab: it fades in when selected, and out of sight (and of finders and screen readers) when
/// another is.
class _FadingPage extends StatefulWidget {
  const _FadingPage({required this.active, required this.child, super.key});

  final bool active;
  final Widget child;

  @override
  State<_FadingPage> createState() => _FadingPageState();
}

class _FadingPageState extends State<_FadingPage> {
  late bool _hidden = !widget.active;

  @override
  void didUpdateWidget(_FadingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active) _hidden = false;
  }

  @override
  Widget build(BuildContext context) => Offstage(
    offstage: _hidden,
    child: IgnorePointer(
      ignoring: !widget.active,
      child: AnimatedOpacity(
        opacity: widget.active ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        onEnd: () {
          if (!widget.active && mounted) setState(() => _hidden = true);
        },
        child: AnimatedScale(
          scale: widget.active ? 1 : 0.985,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          // The page's own animations pause while it is out of sight.
          child: TickerMode(enabled: widget.active, child: widget.child),
        ),
      ),
    ),
  );
}

/// The floating glass bar: a round button per tab, then your avatar.
class _TabBar extends ConsumerWidget {
  const _TabBar({required this.selected, required this.onSelect});

  final ShellTab selected;
  final ValueChanged<ShellTab> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authProvider).value;
    return GlassPanel(
      radius: 34,
      padding: const EdgeInsets.all(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final tab in ShellTab.values) ...[
            Semantics(
              button: true,
              selected: tab == selected,
              label: tab.label,
              excludeSemantics: true,
              child: Tooltip(
                message: tab.label,
                child: Pressable(
                  onTap: () => onSelect(tab),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tab == selected
                          ? scheme.onSurface.withValues(alpha: 0.14)
                          : Colors.transparent,
                    ),
                    child: Icon(
                      tab == selected ? tab.icons.$2 : tab.icons.$1,
                      size: 24,
                      color: tab == selected ? scheme.onSurface : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          AccountAvatar(
            user: auth?.isSignedIn ?? false ? auth!.user : null,
            size: 52,
            onTap: () => showAccountSheet(context),
          ),
        ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Pressable(
        scale: 0.98,
        onTap: () => Navigator.of(
          context,
          rootNavigator: true,
        ).push(MaterialPageRoute<void>(builder: (_) => const AutomatchScreen())),
        child: GlassPanel(
          radius: 28,
          tint: scheme.primaryContainer,
          opacity: 0.85,
          padding: const EdgeInsets.fromLTRB(20, 6, 8, 6),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Looking for an opponent · ${settings.size}×${settings.size} '
                  '${settings.speed.label.toLowerCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
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
