import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/constants.dart';
import 'package:tengen/src/model/auth/auth_controller.dart';
import 'package:tengen/src/model/go/board.dart';
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
import 'package:tengen/src/view/learn/learn_sheet.dart';
import 'package:tengen/src/view/online_game/online_game_screen.dart';
import 'package:tengen/src/view/play/automatch_screen.dart';
import 'package:tengen/src/view/play/play_screen.dart';
import 'package:tengen/src/view/puzzle/puzzles_sheet.dart';
import 'package:tengen/src/view/settings/settings_screen.dart';
import 'package:tengen/src/view/user/player_screen.dart';
import 'package:tengen/src/view/watch/watch_sheet.dart';
import 'package:tengen/src/widgets/goban.dart';
import 'package:tengen/src/widgets/ui.dart';

/// The home of the app: your current game, Play now, and the rest of the app in four cards.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider).value;
    final signedIn = auth?.isSignedIn ?? false;
    final user = auth?.user;
    final prefs = ref.watch(preferencesProvider);
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
      final settings = ref.read(automatchSettingsProvider);
      ref.read(automatchProvider.notifier).find(settings);
      pushFullScreen<void>(context, const AutomatchScreen());
    }

    final settings = ref.watch(automatchSettingsProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 12, 16, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              kAppName,
                              style: theme.textTheme.headlineSmall?.copyWith(fontSize: 24),
                            ),
                          ),
                          _Avatar(
                            user: user,
                            signedIn: signedIn,
                            onTap: () => showModalBottomSheet<void>(
                              context: context,
                              builder: (_) => const _AccountSheet(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (current != null)
                      Center(
                        child: _GamePill(
                          game: current,
                          myTurn: current.isTurnOf(user!.id),
                          userId: user.id,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                      child: GestureDetector(
                        onTap: current == null
                            ? null
                            : () => pushFullScreen<void>(
                                context,
                                OnlineGameScreen(gameId: current.id),
                              ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x66000000),
                                    blurRadius: 24,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: IgnorePointer(
                                  child: ExcludeSemantics(
                                    child: Goban(
                                      board: currentGame?.board ?? Board.empty(19, 19),
                                      lastMove: currentGame?.position.lastMove?.point,
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
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          20,
                          28,
                          20,
                          20 + MediaQuery.paddingOf(context).bottom,
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: play,
                                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                                    label: const Text('Play now'),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(64, 64),
                                      textStyle: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Tooltip(
                                  message: 'New game',
                                  child: Material(
                                    color: scheme.surfaceContainer,
                                    borderRadius: BorderRadius.circular(18),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(18),
                                      onTap: () => showNewGame(context),
                                      child: const SizedBox.square(
                                        dimension: 64,
                                        child: Icon(Icons.tune_rounded),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              signedIn
                                  ? '${settings.size}×${settings.size} · '
                                        '${settings.speed.label} · ${settings.timeLabel}'
                                  : 'Sign in to play on online-go.com',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 18),
                            _HubCards(signedIn: signedIn, userId: user?.id),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `● Your move · vs kuro_neko 4k`
class _GamePill extends StatelessWidget {
  const _GamePill({required this.game, required this.myTurn, required this.userId});

  final PlayerGame game;
  final bool myTurn;
  final int userId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final opponent = game.black.id == userId ? game.white : game.black;
    return Material(
      color: scheme.surfaceContainer,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => pushFullScreen<void>(context, OnlineGameScreen(gameId: game.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: myTurn ? scheme.primary : scheme.onSurfaceVariant,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  '${myTurn ? 'Your move' : 'Waiting'} · vs ${opponent.username} '
                  '${opponent.rankLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: myTurn ? scheme.primary : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
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

/// Puzzles, Learn, Watch and My games.
class _HubCards extends ConsumerWidget {
  const _HubCards({required this.signedIn, required this.userId});

  final bool signedIn;
  final int? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastPuzzle = ref.watch(lastPuzzleProvider);
    final hub = ref.watch(learningHubProvider).value;
    final done = ref.watch(hubProgressProvider);
    final live = ref.watch(liveGamesProvider(GameListKind.live)).value;
    final games = signedIn ? ref.watch(activeGamesProvider).value : null;

    final topics = hub?.topics.toList() ?? const <HubTopic>[];
    final next = topics.where((t) => pagesDone(done, t) < t.pages.length).firstOrNull;
    final topicsDone = topics.where((t) => pagesDone(done, t) == t.pages.length).length;
    final waiting = games?.where((g) => g.isTurnOf(userId ?? 0)).length ?? 0;

    final cards = [
      NavCard(
        icon: Icons.extension_outlined,
        title: 'Puzzles',
        subtitle: lastPuzzle?.title ?? 'Life & death, tesuji',
        onTap: () => showTengenSheet<void>(context, const PuzzlesSheet()),
      ),
      NavCard(
        icon: Icons.school_outlined,
        title: 'Learn',
        subtitle: hub == null
            ? 'The OGS course'
            : next == null
            ? 'Course completed'
            : '${next.title} · $topicsDone / ${topics.length}',
        onTap: () => showTengenSheet<void>(context, const LearnSheet()),
      ),
      NavCard(
        icon: Icons.live_tv_rounded,
        title: 'Watch',
        subtitle: live == null ? 'Top games live' : '${live.length} top games live',
        onTap: () => showTengenSheet<void>(context, const WatchSheet()),
      ),
      NavCard(
        icon: Icons.layers_outlined,
        title: 'My games',
        subtitle: !signedIn
            ? 'Sign in to see them'
            : games == null
            ? 'Your OGS games'
            : waiting > 0
            ? '$waiting waiting for you'
            : (games.isEmpty ? 'No ongoing games' : '${games.length} ongoing'),
        onTap: () =>
            signedIn ? pushFullScreen<void>(context, const MyGamesScreen()) : showSignIn(context),
      ),
    ];
    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: cards[row * 2]),
              const SizedBox(width: 14),
              Expanded(child: cards[row * 2 + 1]),
            ],
          ),
        ],
      ],
    );
  }
}

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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.signedIn, required this.onTap});

  final OgsUser? user;
  final bool signedIn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = signedIn ? user!.username : '';
    final icon = signedIn ? user!.iconUrl : null;
    return Tooltip(
      message: signedIn ? name : 'Account',
      child: Material(
        color: scheme.surfaceContainer,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: 44,
            child: icon != null
                ? Image.network(
                    icon,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _initial(context, name),
                  )
                : signedIn
                ? _initial(context, name)
                : const Icon(Icons.person_outline_rounded),
          ),
        ),
      ),
    );
  }

  Widget _initial(BuildContext context, String name) => Center(
    child: Text(
      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
      style: Theme.of(context).textTheme.titleMedium,
    ),
  );
}

/// Your account and the rest of the app.
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
