import 'dart:math' as math;

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
                _FadingPage(
                  key: ValueKey(t),
                  active: t == tab,
                  // The pages slide the way the tabs are laid out: a tab to the right comes in
                  // from the right.
                  side: t.index.compareTo(tab.index).toDouble(),
                  child: _page(t),
                ),
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
  const _FadingPage({required this.active, required this.side, required this.child, super.key});

  final bool active;

  /// Where the page waits when it is not shown: -1 left of the selected tab, 1 right of it.
  final double side;
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
        child: AnimatedSlide(
          offset: Offset(widget.active ? 0 : widget.side * 0.12, 0),
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeOutCubic,
          // The page's own animations pause while it is out of sight.
          child: TickerMode(enabled: widget.active, child: widget.child),
        ),
      ),
    ),
  );
}

/// The floating glass bar: a round button per tab, then your avatar. The highlight slides to
/// the selected tab, stretching like a drop of liquid on the way, and the icon pops.
class _TabBar extends ConsumerWidget {
  const _TabBar({required this.selected, required this.onSelect});

  final ShellTab selected;
  final ValueChanged<ShellTab> onSelect;

  static const _item = 52.0;
  static const _gap = 4.0;

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
          SizedBox(
            width: ShellTab.values.length * (_item + _gap),
            height: _item,
            child: Stack(
              children: [
                _LiquidIndicator(
                  index: selected.index,
                  extent: _item + _gap,
                  size: _item,
                  color: scheme.onSurface.withValues(alpha: 0.14),
                ),
                Row(
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
                            child: SizedBox.square(
                              dimension: _item,
                              child: _TabIcon(
                                selected: tab == selected,
                                icon: tab.icons.$1,
                                selectedIcon: tab.icons.$2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: _gap),
                    ],
                  ],
                ),
              ],
            ),
          ),
          AccountAvatar(
            user: auth?.isSignedIn ?? false ? auth!.user : null,
            size: _item,
            onTap: () => showAccountSheet(context),
          ),
        ],
      ),
    );
  }
}

/// The selected tab's icon pops a little when chosen; the others are muted.
class _TabIcon extends StatelessWidget {
  const _TabIcon({required this.selected, required this.icon, required this.selectedIcon});

  final bool selected;
  final IconData icon;
  final IconData selectedIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      // A new key restarts the pop each time the tab is selected.
      key: ValueKey(selected),
      tween: Tween(begin: selected ? 0.7 : 1, end: 1),
      duration: Duration(milliseconds: selected ? 520 : 1),
      curve: Curves.elasticOut,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          selected ? selectedIcon : icon,
          key: ValueKey(selected),
          size: 24,
          color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A pill under the selected tab. When the selection moves, its leading edge goes first and
/// its trailing edge follows, so it stretches and then gathers at its new place.
class _LiquidIndicator extends StatefulWidget {
  const _LiquidIndicator({
    required this.index,
    required this.extent,
    required this.size,
    required this.color,
  });

  final int index;

  /// The distance from one tab to the next.
  final double extent;
  final double size;
  final Color color;

  @override
  State<_LiquidIndicator> createState() => _LiquidIndicatorState();
}

class _LiquidIndicatorState extends State<_LiquidIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    value: 1,
  );
  late int _from = widget.index;

  static const _lead = Interval(0, 0.7, curve: Curves.easeOutCubic);
  static const _trail = Interval(0.22, 1, curve: Curves.easeOutBack);

  @override
  void didUpdateWidget(_LiquidIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      // From where the pill is now, if it was still moving.
      _from = oldWidget.index;
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final t = _controller.value;
      final from = _from * widget.extent;
      final to = widget.index * widget.extent;
      final right = to > from;
      final lead = _lead.transform(t);
      final trail = _trail.transform(t);
      // Moving right, the right edge leads; moving left, the left edge does.
      final left = from + (to - from) * (right ? trail : lead);
      final end = from + (to - from) * (right ? lead : trail) + widget.size;
      return Positioned(
        left: left,
        top: 0,
        width: math.max(widget.size * 0.6, end - left),
        height: widget.size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(widget.size / 2),
          ),
        ),
      );
    },
  );
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
