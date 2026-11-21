import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/constants.dart';
import 'package:tengen/src/model/auth/auth_controller.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/game.dart';
import 'package:tengen/src/model/ogs/game_data.dart';
import 'package:tengen/src/model/ogs/ogs_repository.dart';
import 'package:tengen/src/model/ogs/user.dart';
import 'package:tengen/src/model/online_game/automatch_controller.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/utils/test_env.dart';
import 'package:tengen/src/view/auth/sign_in_screen.dart';
import 'package:tengen/src/view/chat/chat_rooms_screen.dart';
import 'package:tengen/src/view/home/my_games_screen.dart';
import 'package:tengen/src/view/online_game/online_game_screen.dart';
import 'package:tengen/src/view/play/automatch_screen.dart';
import 'package:tengen/src/view/play/play_screen.dart';
import 'package:tengen/src/view/settings/settings_screen.dart';
import 'package:tengen/src/view/user/player_screen.dart';
import 'package:tengen/src/widgets/board_thumbnail.dart';
import 'package:tengen/src/widgets/goban.dart';
import 'package:tengen/src/widgets/ui.dart';

/// The home tab. Your game (or an empty board of the size you would play) fills the top as a
/// tilted backdrop that fades into the page; over it, the size and speed of your next game,
/// what is happening (`Your move against kuro_neko`), Continue and New game, and three tiles.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();

  /// `Move 22 · 2:14 left · Rated`
  static String _gameDetail(PlayerGame game, GoGame? built) {
    final data = game.data;
    final clock = data?.clock;
    final parts = [
      if (built != null) 'Move ${built.moveCount}',
      if (clock != null && built != null) '${clock.read(built.toMove, DateTime.now()).label} left',
      if (data != null && data.ranked) 'Rated',
      if (data != null && !data.ranked) 'Unrated',
    ];
    return parts.isEmpty ? '${game.width}×${game.height}' : parts.join(' · ');
  }
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// The backdrop moves at half the speed of the page (parallax).
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider).value;
    final signedIn = auth?.isSignedIn ?? false;
    final user = auth?.user;
    final prefs = ref.watch(preferencesProvider);
    final settings = ref.watch(automatchSettingsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // The game to show: one waiting for your move first.
    final games = signedIn ? ref.watch(activeGamesProvider).value : null;
    final current = games == null || games.isEmpty
        ? null
        : (games.where((g) => g.isTurnOf(user!.id)).firstOrNull ?? games.first);
    final currentGame = current?.data?.buildGameCached();

    void play() {
      if (!signedIn) {
        showSignIn(context);
        return;
      }
      ref.read(automatchProvider.notifier).find(settings);
      pushFullScreen<void>(context, const AutomatchScreen());
    }

    final (String headline, String detail, Widget primary, Widget secondary) = switch ((
      current,
      signedIn,
    )) {
      (final PlayerGame game?, _) => (
        '${game.isTurnOf(user!.id) ? 'Your move' : 'Their move'}\n'
            'against ${(game.black.id == user.id ? game.white : game.black).username}',
        HomeScreen._gameDetail(game, currentGame),
        _PillButton.primary(
          icon: Icons.play_arrow_rounded,
          label: 'Continue',
          onTap: () => pushFullScreen<void>(context, OnlineGameScreen(gameId: game.id)),
        ),
        _PillButton.glass(label: 'New game', onTap: () => showNewGame(context)),
      ),
      (null, true) => (
        'Ready for\na game?',
        '${settings.size}×${settings.size} · ${settings.speed.label} · ${settings.timeLabel}',
        _PillButton.primary(icon: Icons.play_arrow_rounded, label: 'Play now', onTap: play),
        _PillButton.glass(label: 'New game', onTap: () => showNewGame(context)),
      ),
      (null, false) => (
        'Play Go,\nonline or here',
        'Sign in to online-go.com, or play on this phone',
        _PillButton.primary(
          icon: Icons.login_rounded,
          label: 'Sign in',
          onTap: () => showSignIn(context),
        ),
        _PillButton.glass(
          label: 'Play offline',
          onTap: () => showNewGame(context, tab: PlayTab.offline),
        ),
      ),
    };

    final backdropBoard = currentGame?.board ?? _openingBoard;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final top = MediaQuery.paddingOf(context).top;
          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: height * 0.66,
                child: AnimatedBuilder(
                  animation: _scroll,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(
                      0,
                      -0.45 * (_scroll.hasClients ? math.max(0.0, _scroll.offset) : 0),
                    ),
                    child: child,
                  ),
                  child: GestureDetector(
                    onTap: current == null
                        ? null
                        : () => pushFullScreen<void>(context, OnlineGameScreen(gameId: current.id)),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 700),
                      child: _Backdrop(
                        key: ValueKey(current?.id ?? 0),
                        board: backdropBoard,
                        lastMove: currentGame?.position.lastMove?.point,
                        prefs: prefs,
                      ),
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                controller: _scroll,
                padding: EdgeInsets.only(
                  top: top + 12,
                  bottom: MediaQuery.paddingOf(context).bottom + kFloatingBarClearance + 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Entrance(child: _NextGameChips(signedIn: signedIn)),
                    SizedBox(height: (height * 0.25).clamp(48.0, 300.0)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 450),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0, 0.12),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        layoutBuilder: (current, previous) =>
                            Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
                        child: Entrance(
                          key: ValueKey(headline),
                          delay: const Duration(milliseconds: 90),
                          offset: 32,
                          child: Column(
                            key: ValueKey(headline),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                headline,
                                style: theme.textTheme.displaySmall?.copyWith(
                                  fontSize: 34,
                                  height: 1.12,
                                  color: scheme.onSurface,
                                  shadows: const [Shadow(color: Color(0x99000000), blurRadius: 18)],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                detail,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: scheme.onSurface.withValues(alpha: 0.75),
                                  shadows: const [Shadow(color: Color(0x99000000), blurRadius: 12)],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Entrance(
                      delay: const Duration(milliseconds: 180),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Wrap(spacing: 10, runSpacing: 10, children: [primary, secondary]),
                      ),
                    ),
                    const SizedBox(height: 26),
                    _YourGo(heroGameId: current?.id),
                  ],
                ),
              ),
              // Once the page scrolls, a fade behind the status bar keeps the time readable.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: top + 12,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _scroll,
                    builder: (context, _) {
                      final offset = _scroll.hasClients ? _scroll.offset : 0.0;
                      return Opacity(
                        opacity: ((offset - 40) / 120).clamp(0.0, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0, 0.7, 1],
                              colors: [
                                scheme.surface,
                                scheme.surface.withValues(alpha: 0.85),
                                scheme.surface.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Without a game of yours, the backdrop shows an opening: a board with stones looks alive where
/// an empty one looks bare. It is decoration only.
final _openingBoard = Board.empty(19, 19)
    .withStones(
      const [
        (3, 3),
        (15, 3),
        (15, 15),
        (2, 9),
        (9, 3),
        (13, 16),
        (16, 9),
        (10, 10),
        (6, 16),
        (13, 13),
        (5, 5),
        (16, 12),
      ].map((p) => Point(p.$1, p.$2)),
      StoneColor.black,
    )
    .withStones(
      const [
        (3, 15),
        (16, 14),
        (15, 10),
        (2, 5),
        (5, 2),
        (9, 15),
        (14, 5),
        (11, 13),
        (3, 11),
        (13, 2),
        (16, 6),
        (9, 9),
      ].map((p) => Point(p.$1, p.$2)),
      StoneColor.white,
    );

/// The board, large and tilted, fading into the page below and darkened at the top for the
/// status bar.
class _Backdrop extends StatefulWidget {
  const _Backdrop({required this.board, required this.lastMove, required this.prefs, super.key});

  final Board board;
  final Point? lastMove;
  final Preferences prefs;

  @override
  State<_Backdrop> createState() => _BackdropState();
}

/// The backdrop drifts slowly, as if a camera moved over the board.
class _BackdropState extends State<_Backdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Endless: off in tests (they could not settle) and when animations are reduced.
    if (!inFlutterTest && !MediaQuery.disableAnimationsOf(context) && !_drift.isAnimating) {
      _drift.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.max(constraints.maxWidth * 1.3, constraints.maxHeight * 1.1);
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              OverflowBox(
                maxWidth: size,
                maxHeight: size,
                alignment: const Alignment(0.1, -0.2),
                child: AnimatedBuilder(
                  animation: _drift,
                  builder: (context, child) {
                    final t = Curves.easeInOutSine.transform(_drift.value);
                    return Transform.translate(
                      offset: Offset(18 * t - 9, 10 * t - 5),
                      child: Transform.scale(scale: 1 + 0.06 * t, child: child),
                    );
                  },
                  child: Transform.rotate(
                    angle: -0.14,
                    child: SizedBox.square(
                      dimension: size,
                      // Drawn once, then only moved by the drift.
                      child: RepaintBoundary(
                        child: IgnorePointer(
                          child: ExcludeSemantics(
                            child: Goban(
                              board: widget.board,
                              lastMove: widget.lastMove,
                              theme: widget.prefs.boardTheme,
                              blackStones: widget.prefs.blackStones,
                              whiteStones: widget.prefs.whiteStones,
                              showCoordinates: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.2, 0.42, 0.74, 1],
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0),
                      surface.withValues(alpha: 0.32),
                      surface.withValues(alpha: 0.92),
                      surface,
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The size and speed of the next game, as chips over the board.
class _NextGameChips extends ConsumerWidget {
  const _NextGameChips({required this.signedIn});

  final bool signedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(automatchSettingsProvider);
    void set(AutomatchSettings s) => ref.read(automatchSettingsProvider.notifier).update(s);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (final size in const [9, 13, 19])
            _Chip(
              label: '$size×$size',
              selected: settings.size == size,
              onTap: () => set(settings.copyWith(size: size)),
            ),
          if (signedIn) ...[
            const SizedBox(width: 6),
            for (final speed in GameSpeed.values)
              _Chip(
                label: speed == GameSpeed.correspondence ? 'Daily' : speed.label,
                selected: settings.speed == speed,
                onTap: () => set(settings.copyWith(speed: speed)),
              ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const duration = Duration(milliseconds: 260);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        child: Pressable(
          onTap: onTap,
          child: GlassPanel(
            radius: 20,
            tint: Colors.black,
            opacity: 0.12,
            shadow: false,
            blur: false,
            child: Stack(
              children: [
                // The light fill fades and grows in under the selected chip.
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: duration,
                    curve: Curves.easeOut,
                    child: AnimatedScale(
                      scale: selected ? 1 : 0.6,
                      duration: duration,
                      curve: Curves.easeOutBack,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: scheme.onSurface,
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  child: AnimatedDefaultTextStyle(
                    duration: duration,
                    style: theme.textTheme.bodyLarge!.copyWith(
                      color: selected ? scheme.surface : Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    child: Text(label),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The main buttons: a solid pill and a glass one.
class _PillButton extends StatelessWidget {
  const _PillButton.primary({required this.label, required this.onTap, this.icon}) : glass = false;
  const _PillButton.glass({required this.label, required this.onTap}) : glass = true, icon = null;

  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = glass ? scheme.onSurface : scheme.surface;
    final content = Padding(
      padding: EdgeInsets.fromLTRB(icon == null ? 26 : 20, 15, 26, 15),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, color: fg, size: 24), const SizedBox(width: 8)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(color: fg, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        child: glass
            ? GlassPanel(radius: 30, opacity: 0.6, blur: false, child: content)
            : DecoratedBox(
                decoration: ShapeDecoration(
                  color: scheme.onSurface,
                  shape: const StadiumBorder(),
                  shadows: const [
                    BoxShadow(color: Color(0x40000000), blurRadius: 18, offset: Offset(0, 6)),
                  ],
                ),
                child: content,
              ),
      ),
    );
  }
}

/// What is yours below the main buttons: your record and recent form, your other games, and
/// your last results. Signed out, what signing in brings.
class _YourGo extends ConsumerWidget {
  const _YourGo({required this.heroGameId});

  /// The game already shown at the top, left out of the other games.
  final int? heroGameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider).value;
    if (auth == null || !auth.isSignedIn) return const _SignedOutCard();
    final user = auth.user;
    final me = ref.watch(playerProvider(user.id)).value;
    final stats = ref.watch(playerStatsProvider(user.id)).value;
    final recent = ref.watch(playerGamesProvider(user.id));
    final active = ref.watch(activeGamesProvider).value ?? const <PlayerGame>[];
    final others = [
      ...active.where((g) => g.id != heroGameId && g.isTurnOf(user.id)),
      ...active.where((g) => g.id != heroGameId && !g.isTurnOf(user.id)),
    ];
    final finished = recent.value ?? const <PlayerGame>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Entrance(
          delay: const Duration(milliseconds: 260),
          child: _RecordCard(
            rank: (me ?? user).rankLabel,
            rating: me?.rating,
            stats: stats,
            form: [for (final g in finished.take(10)) _outcomeFor(g, user.id)],
          ),
        ),
        if (others.isNotEmpty) ...[
          _SectionHeader(
            title: 'Your games',
            trailing: '${others.length}',
            onTap: () => pushFullScreen<void>(context, const MyGamesScreen()),
          ),
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: others.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) => Entrance(
                delay: Duration(milliseconds: 320 + 70 * i),
                child: _OngoingCard(game: others[i], userId: user.id),
              ),
            ),
          ),
        ],
        _SectionHeader(
          title: 'Recent games',
          trailing: 'See all',
          onTap: () => pushFullScreen<void>(context, const MyGamesScreen()),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: switch (recent) {
            AsyncData(:final value) when value.isEmpty => const _Note(
              'No finished games yet. Your results will show here.',
            ),
            AsyncData(:final value) => _Rounded(
              children: [
                for (final (i, g) in value.take(5).indexed)
                  Entrance(
                    delay: Duration(milliseconds: 120 + 70 * i),
                    offset: 14,
                    child: _RecentGameRow(game: g, userId: user.id),
                  ),
              ],
            ),
            AsyncError() => const _Note('Could not load your games.'),
            _ => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          },
        ),
      ],
    );
  }
}

enum _Outcome { win, loss, other }

_Outcome _outcomeFor(PlayerGame g, int userId) {
  final winner = g.winner;
  if (winner == null) return _Outcome.other;
  final mine = g.black.id == userId ? StoneColor.black : StoneColor.white;
  return winner == mine ? _Outcome.win : _Outcome.loss;
}

/// `just now`, `40m ago`, `5h ago`, `3d ago`, or the date.
String _ago(BuildContext context, DateTime time) {
  final d = DateTime.now().difference(time);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes}m ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return MaterialLocalizations.of(context).formatShortMonthDay(time.toLocal());
}

/// Rank, rating and record, then the last results as dots (oldest first).
class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.rank,
    required this.rating,
    required this.stats,
    required this.form,
  });

  final String rank;
  final double? rating;
  final ({int games, int wins})? stats;

  /// Newest first.
  final List<_Outcome> form;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = stats;
    final losses = s == null ? null : math.max(0, s.games - s.wins);
    final rate = s == null || s.games == 0 ? null : (s.wins * 100 / s.games).round().clamp(0, 100);
    Widget stat(String label, Widget value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: DefaultTextStyle.merge(
              maxLines: 1,
              style: theme.textTheme.headlineMedium?.copyWith(fontSize: 26, height: 1.1),
              child: value,
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _Rounded(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        children: [
          Row(
            children: [
              stat('Rank', Text(rank.isEmpty ? '–' : rank)),
              stat(
                'Rating',
                rating == null
                    ? const Text('–')
                    : CountUp(value: rating!.round(), builder: (_, v) => Text('$v')),
              ),
              stat(
                'Record',
                s == null
                    ? const Text('…')
                    : CountUp(
                        value: s.wins,
                        builder: (_, w) =>
                            CountUp(value: losses!, builder: (_, l) => Text('$w–$l')),
                      ),
              ),
            ],
          ),
          if (form.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'Last ${form.length}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final (i, o) in form.reversed.indexed)
                        // The dots pop in one after another.
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(milliseconds: 500 + 60 * i),
                          curve: Interval((60 * i) / (500 + 60 * i), 1, curve: Curves.elasticOut),
                          builder: (context, t, child) => Transform.scale(scale: t, child: child),
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: switch (o) {
                                _Outcome.win => scheme.secondary,
                                _Outcome.loss => scheme.error,
                                _Outcome.other => scheme.outline,
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (rate != null)
                  CountUp(
                    value: rate,
                    builder: (_, v) => Text(
                      '$v% won',
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Another game of yours: its board, the opponent and whose move it is.
class _OngoingCard extends StatelessWidget {
  const _OngoingCard({required this.game, required this.userId});

  final PlayerGame game;
  final int userId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final opponent = game.black.id == userId ? game.white : game.black;
    final built = game.data?.buildGameCached();
    final myTurn = game.isTurnOf(userId);
    return Pressable(
      onTap: () => pushFullScreen<void>(context, OnlineGameScreen(gameId: game.id)),
      child: Container(
        width: 148,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: built == null
                  ? SizedBox.square(
                      dimension: 128,
                      child: ColoredBox(color: scheme.surfaceContainerHighest),
                    )
                  : BoardThumbnail(
                      board: built.board,
                      size: 128,
                      lastMove: built.position.lastMove?.point,
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              opponent.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
            Text(
              myTurn ? 'Your move' : 'Their move',
              maxLines: 1,
              style: theme.textTheme.bodySmall?.copyWith(
                color: myTurn ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: myTurn ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A finished game: won or lost, against whom, how and when.
class _RecentGameRow extends StatelessWidget {
  const _RecentGameRow({required this.game, required this.userId});

  final PlayerGame game;
  final int userId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final opponent = game.black.id == userId ? game.white : game.black;
    final outcome = _outcomeFor(game, userId);
    final (Color bg, Color fg, String letter) = switch (outcome) {
      _Outcome.win => (scheme.secondaryContainer, scheme.onSecondaryContainer, 'W'),
      _Outcome.loss => (scheme.errorContainer, scheme.onErrorContainer, 'L'),
      _Outcome.other => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant, '–'),
    };
    return InkWell(
      onTap: () => pushFullScreen<void>(context, OnlineGameScreen(gameId: game.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Text(letter, style: theme.textTheme.titleMedium?.copyWith(color: fg)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'vs ${opponent.username} ${opponent.rankLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      '${game.width}×${game.height}',
                      if (game.outcome != null && game.outcome!.isNotEmpty) game.outcome!,
                      if (game.ended != null) _ago(context, game.ended!),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Signed out: what signing in adds to this screen.
class _SignedOutCard extends StatelessWidget {
  const _SignedOutCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _Rounded(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Text('Your games, here', style: theme.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to online-go.com to see your rank and record, the games waiting for you '
            'and your game history on this screen.',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// `Recent games                See all`
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing, this.onTap});

  final String title;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 14, 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
          if (trailing != null)
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                foregroundColor: scheme.onSurfaceVariant,
                minimumSize: const Size(0, 36),
              ),
              child: Text(trailing!),
            ),
        ],
      ),
    );
  }
}

/// A soft rounded block on the high surface.
class _Rounded extends StatelessWidget {
  const _Rounded({required this.children, this.padding = const EdgeInsets.symmetric(vertical: 4)});

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(26),
    ),
    child: Material(
      type: MaterialType.transparency,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => _Rounded(
    padding: const EdgeInsets.all(18),
    children: [
      Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );
}

/// Your avatar (or a person icon when signed out) in the accent color, for the account sheet.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({required this.user, required this.onTap, this.size = 44, super.key});

  final OgsUser? user;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = user?.username ?? '';
    final icon = user?.iconUrl;
    final initial = Center(
      child: user == null
          ? Icon(Icons.person_outline_rounded, color: scheme.onPrimary)
          : Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: theme.textTheme.titleLarge?.copyWith(color: scheme.onPrimary),
            ),
    );
    return Semantics(
      button: true,
      label: user == null ? 'Account' : name,
      excludeSemantics: true,
      child: Tooltip(
        message: user == null ? 'Account' : name,
        child: Pressable(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
            child: icon != null
                ? Image.network(icon, fit: BoxFit.cover, errorBuilder: (_, _, _) => initial)
                : initial,
          ),
        ),
      ),
    );
  }
}

/// Your profile, games, settings, chat rooms, about, sign in and out.
Future<void> showAccountSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  builder: (_) => const _AccountSheet(),
);

/// A small square of a board's wood (or color).
class BoardSwatch extends StatelessWidget {
  const BoardSwatch({required this.board, required this.size, super.key});

  final BoardTheme board;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = board.textureAsset;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.25),
      child: SizedBox.square(
        dimension: size,
        child: asset == null
            ? ColoredBox(color: board.wood)
            : Image.asset(
                asset,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(color: board.wood),
              ),
      ),
    );
  }
}

class _AccountSheet extends ConsumerWidget {
  const _AccountSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider).value;
    final signedIn = auth?.isSignedIn ?? false;
    final board = ref.watch(preferencesProvider.select((p) => p.boardTheme));
    final theme = Theme.of(context);
    void go(Widget screen) {
      Navigator.pop(context);
      pushFullScreen<void>(context, screen);
    }

    return SafeArea(
      // Scrolls on short phones.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                signedIn ? auth!.user.username : 'Not signed in',
                style: theme.textTheme.headlineSmall,
              ),
            ),
            if (signedIn)
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: const Text('Your profile'),
                onTap: () => go(PlayerScreen(playerId: auth!.user.id)),
              )
            else
              ListTile(
                leading: const Icon(Icons.login_rounded),
                title: const Text('Sign in to online-go.com'),
                onTap: () {
                  Navigator.pop(context);
                  showSignIn(context);
                },
              ),
            if (signedIn)
              ListTile(
                leading: const Icon(Icons.layers_outlined),
                title: const Text('My games'),
                onTap: () => go(const MyGamesScreen()),
              ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () => go(const SettingsScreen()),
            ),
            ListTile(
              leading: BoardSwatch(board: board, size: 24),
              title: const Text('Board and stones'),
              subtitle: Text(board.label),
              onTap: () => go(const SettingsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: const Text('Chat rooms'),
              onTap: () => go(const ChatRoomsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: kAppName,
                  applicationVersion: kAppVersion,
                  applicationIcon: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset('assets/icon/icon.png', width: 56, height: 56),
                  ),
                  applicationLegalese:
                      'Free software under the GNU GPL v3 or later.\n\n'
                      'Based on the Lichess mobile app (github.com/lichess-org/mobile). Online '
                      'play uses the online-go.com APIs; this app is not affiliated with OGS.\n\n'
                      'The Learn course, the board and stone images and the stone sounds come '
                      'from online-go.com, © the OGS contributors, under the GNU AGPL v3.',
                );
              },
            ),
            if (signedIn)
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Sign out'),
                onTap: () async {
                  Navigator.pop(context);
                  if (await confirm(context, title: 'Sign out?', confirmLabel: 'Sign out')) {
                    await ref.read(authProvider.notifier).signOut();
                  }
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
