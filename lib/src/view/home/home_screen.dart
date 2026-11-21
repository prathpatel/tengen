import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/constants.dart';
import 'package:tengen/src/model/auth/auth_controller.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/game.dart';
import 'package:tengen/src/model/learn/learning_hub.dart';
import 'package:tengen/src/model/ogs/game_data.dart';
import 'package:tengen/src/model/ogs/ogs_repository.dart';
import 'package:tengen/src/model/ogs/user.dart';
import 'package:tengen/src/model/online_game/automatch_controller.dart';
import 'package:tengen/src/model/puzzle/puzzle.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/auth/sign_in_screen.dart';
import 'package:tengen/src/view/chat/chat_rooms_screen.dart';
import 'package:tengen/src/view/home/my_games_screen.dart';
import 'package:tengen/src/view/online_game/online_game_screen.dart';
import 'package:tengen/src/view/play/automatch_screen.dart';
import 'package:tengen/src/view/play/play_screen.dart';
import 'package:tengen/src/view/puzzle/puzzle_screen.dart';
import 'package:tengen/src/view/settings/settings_screen.dart';
import 'package:tengen/src/view/user/player_screen.dart';
import 'package:tengen/src/widgets/goban.dart';
import 'package:tengen/src/widgets/ui.dart';

/// The home tab. Your game (or an empty board of the size you would play) fills the top as a
/// tilted backdrop that fades into the page; over it, the size and speed of your next game,
/// what is happening (`Your move against kuro_neko`), Continue and New game, and three tiles.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final currentGame = current?.data?.buildGame();

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
        _gameDetail(game, currentGame),
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
                child: GestureDetector(
                  onTap: current == null
                      ? null
                      : () => pushFullScreen<void>(context, OnlineGameScreen(gameId: current.id)),
                  child: _Backdrop(
                    key: ValueKey(current?.id ?? 0),
                    board: backdropBoard,
                    lastMove: currentGame?.position.lastMove?.point,
                    prefs: prefs,
                  ),
                ),
              ),
              SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: top + 12,
                  bottom: MediaQuery.paddingOf(context).bottom + kFloatingBarClearance + 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NextGameChips(signedIn: signedIn),
                    SizedBox(height: (height * 0.25).clamp(48.0, 300.0)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
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
                    const SizedBox(height: 22),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Wrap(spacing: 10, runSpacing: 10, children: [primary, secondary]),
                    ),
                    const SizedBox(height: 26),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _Tiles(signedIn: signedIn),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

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
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.board, required this.lastMove, required this.prefs, super.key});

  final Board board;
  final Point? lastMove;
  final Preferences prefs;

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
                child: Transform.rotate(
                  angle: -0.14,
                  child: SizedBox.square(
                    dimension: size,
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: Goban(
                          board: board,
                          lastMove: lastMove,
                          theme: prefs.boardTheme,
                          blackStones: prefs.blackStones,
                          whiteStones: prefs.whiteStones,
                          showCoordinates: false,
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
    final text = theme.textTheme.bodyLarge?.copyWith(
      color: selected ? scheme.surface : Colors.white,
      fontWeight: FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        child: Pressable(
          onTap: onTap,
          child: selected
              ? AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: ShapeDecoration(
                    color: scheme.onSurface,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(label, style: text),
                )
              : GlassPanel(
                  radius: 20,
                  tint: Colors.black,
                  opacity: 0.22,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  child: Text(label, style: text),
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
            ? GlassPanel(radius: 30, opacity: 0.6, child: content)
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

/// Puzzles, Learn and Watch, each with where you are.
class _Tiles extends ConsumerWidget {
  const _Tiles({required this.signedIn});

  final bool signedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastPuzzle = ref.watch(lastPuzzleProvider);
    final hub = ref.watch(learningHubProvider).value;
    final done = ref.watch(hubProgressProvider);
    final live = ref.watch(liveGamesProvider(GameListKind.live)).value;

    final topics = hub?.topics.toList() ?? const <HubTopic>[];
    final topicsDone = topics.where((t) => pagesDone(done, t) == t.pages.length).length;
    final tiles = [
      _Tile(
        label: 'Puzzles',
        value: lastPuzzle == null ? 'Start' : 'Resume',
        onTap: lastPuzzle == null
            ? null
            : () => pushFullScreen<void>(context, PuzzleScreen(puzzleId: lastPuzzle.id)),
      ),
      _Tile(label: 'Learn', value: hub == null ? '…' : '$topicsDone/${topics.length}'),
      _Tile(label: 'Watch', value: live == null ? '…' : '${live.length} live'),
    ];
    return Row(
      children: [
        for (final (i, tile) in tiles.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: tile),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: theme.textTheme.headlineMedium?.copyWith(fontSize: 26, height: 1.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
