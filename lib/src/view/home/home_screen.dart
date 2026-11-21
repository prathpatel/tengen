import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/constants.dart';
import 'package:tengen/src/model/auth/auth_controller.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/ogs/game_data.dart';
import 'package:tengen/src/model/ogs/ogs_repository.dart';
import 'package:tengen/src/model/ogs/user.dart';
import 'package:tengen/src/model/online_game/automatch_controller.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/auth/sign_in_screen.dart';
import 'package:tengen/src/view/home/my_games_screen.dart';
import 'package:tengen/src/view/online_game/online_game_screen.dart';
import 'package:tengen/src/view/play/automatch_screen.dart';
import 'package:tengen/src/view/play/play_screen.dart';
import 'package:tengen/src/view/shell_tab.dart';
import 'package:tengen/src/widgets/board_thumbnail.dart';
import 'package:tengen/src/widgets/segmented_choice.dart';
import 'package:tengen/src/widgets/ui.dart';

/// Who to play: someone near your rank (the OGS automatch), the computer (the OGS bots), or a
/// game on this phone.
enum _Opponent { online, computer, phone }

enum _Section { play, games, history }

/// The home tab: Play (board, time and opponent, then Find a game), My games and History.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  _Section _section = _Section.play;
  _Opponent _opponent = _Opponent.online;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider).value;
    final signedIn = auth?.isSignedIn ?? false;
    final user = signedIn ? auth!.user : null;
    final games = signedIn ? ref.watch(activeGamesProvider).value : null;
    final waiting = games?.where((g) => g.isTurnOf(user!.id)).length ?? 0;
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: top + 8),
          PageHeader(
            kAppName,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: AccountAvatar(
                  user: user,
                  size: 34,
                  onTap: () => ref.read(shellTabProvider.notifier).select(ShellTab.profile),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: SegmentedChoice<_Section>(
              choices: [
                const Choice(_Section.play, 'Play'),
                Choice(_Section.games, waiting > 0 ? 'My games · $waiting' : 'My games'),
                const Choice(_Section.history, 'History'),
              ],
              selected: _section,
              onChanged: (s) => setState(() => _section = s),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: switch (_section) {
                _Section.play => _PlayPane(
                  key: const ValueKey(_Section.play),
                  user: user,
                  waiting: waiting,
                  opponent: _opponent,
                  onOpponent: (o) => setState(() => _opponent = o),
                  onShowGames: () => setState(() => _section = _Section.games),
                ),
                _Section.games => _GamesPane(key: const ValueKey(_Section.games), user: user),
                _Section.history => _HistoryPane(key: const ValueKey(_Section.history), user: user),
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Board, time and opponent, then the button that starts.
class _PlayPane extends ConsumerWidget {
  const _PlayPane({
    required this.user,
    required this.waiting,
    required this.opponent,
    required this.onOpponent,
    required this.onShowGames,
    super.key,
  });

  final OgsUser? user;
  final int waiting;
  final _Opponent opponent;
  final ValueChanged<_Opponent> onOpponent;
  final VoidCallback onShowGames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = ref.watch(automatchSettingsProvider);
    void set(AutomatchSettings s) => ref.read(automatchSettingsProvider.notifier).update(s);
    final signedIn = user != null;
    final online = opponent != _Opponent.phone;

    final ranking = user?.ranking;
    final range = ranking == null
        ? 'Rated'
        : 'Rated · ${rankLabelFor(ranking + settings.upperRankDiff)} to '
              '${rankLabelFor(ranking - settings.lowerRankDiff)}';

    void start() {
      if (online && !signedIn) {
        showSignIn(context);
        return;
      }
      switch (opponent) {
        case _Opponent.online:
          ref.read(automatchProvider.notifier).find(settings);
          pushFullScreen<void>(context, const AutomatchScreen());
        case _Opponent.computer:
          showNewGame(context, tab: PlayTab.computer);
        case _Opponent.phone:
          showNewGame(context, tab: PlayTab.offline);
      }
    }

    final options = [
      (_Opponent.online, Icons.people_outline_rounded, 'Someone near my rank', range),
      (_Opponent.computer, Icons.smart_toy_outlined, 'Computer', 'KataGo, choose a level'),
      (
        _Opponent.phone,
        Icons.phone_android_rounded,
        'On this phone',
        'Beginner bot or pass and play',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              if (waiting > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Material(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onShowGames,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Icon(Icons.timer_outlined, size: 20, color: scheme.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                waiting == 1
                                    ? 'Your move in 1 game'
                                    : 'Your move in $waiting games',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: scheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: scheme.onPrimaryContainer),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const SectionLabel('Board', padding: EdgeInsets.fromLTRB(16, 16, 16, 8)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ChoiceTiles<int>(
                  options: const [
                    TileOption(9, '9×9'),
                    TileOption(13, '13×13'),
                    TileOption(19, '19×19'),
                  ],
                  selected: settings.size,
                  onChanged: (v) => set(settings.copyWith(size: v)),
                ),
              ),
              if (opponent == _Opponent.online) ...[
                const SectionLabel('Time'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ChoiceTiles<GameSpeed>(
                    options: [
                      for (final s in GameSpeed.values)
                        TileOption(
                          s,
                          s.shortLabel,
                          detail: quickMatchTime(
                            settings.size,
                            s,
                            settings.system,
                          ).split(' + ').first,
                        ),
                    ],
                    selected: settings.speed,
                    onChanged: (v) => set(settings.copyWith(speed: v)),
                  ),
                ),
              ],
              const SectionLabel('Opponent'),
              Group(
                children: [
                  for (final (value, icon, title, subtitle) in options)
                    GroupRow(
                      leading: Icon(
                        icon,
                        size: 22,
                        color: value == opponent ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                      title: title,
                      subtitle: value != _Opponent.phone && !signedIn
                          ? 'Sign in to online-go.com'
                          : subtitle,
                      trailing: RadioMark(selected: value == opponent),
                      onTap: () => onOpponent(value),
                    ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: FilledButton(
            onPressed: start,
            child: Text(switch ((opponent, signedIn)) {
              (_Opponent.phone, _) => 'Set up the game',
              (_, false) => 'Sign in to play',
              (_Opponent.online, true) => 'Find a game',
              (_Opponent.computer, true) => 'Choose a computer',
            }),
          ),
        ),
      ],
    );
  }
}

/// Your ongoing games, the ones waiting for your move first.
class _GamesPane extends ConsumerWidget {
  const _GamesPane({required this.user, super.key});

  final OgsUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = user;
    if (me == null) return const _SignInNote('Sign in to see your games on online-go.com.');
    final active = ref.watch(activeGamesProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(activeGamesProvider);
        await ref.read(activeGamesProvider.future).catchError((_) => <PlayerGame>[]);
      },
      child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        children: [
          switch (active) {
            AsyncData(:final value) when value.isEmpty => const _Note(
              'No ongoing games. Start one from Play.',
            ),
            AsyncData(:final value) => Group(
              children: [
                for (final g in [
                  ...value.where((g) => g.isTurnOf(me.id)),
                  ...value.where((g) => !g.isTurnOf(me.id)),
                ])
                  _OngoingRow(game: g, userId: me.id),
              ],
            ),
            AsyncError() => const _Note('Could not load your games.'),
            _ => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          },
        ],
      ),
    );
  }
}

class _OngoingRow extends StatelessWidget {
  const _OngoingRow({required this.game, required this.userId});

  final PlayerGame game;
  final int userId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final opponent = game.black.id == userId ? game.white : game.black;
    final built = game.data?.buildGameCached();
    final myTurn = game.isTurnOf(userId);
    final clock = game.data?.clock;
    final left = clock == null || built == null
        ? null
        : '${clock.read(built.toMove, DateTime.now()).label} left';
    return GroupRow(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: built == null
            ? SizedBox.square(dimension: 46, child: ColoredBox(color: scheme.surfaceContainerHigh))
            : BoardThumbnail(
                board: built.board,
                size: 46,
                lastMove: built.position.lastMove?.point,
              ),
      ),
      title: '${opponent.username} ${opponent.rankLabel}'.trim(),
      subtitle: [
        if (myTurn) 'Your move' else 'Their move',
        ?left,
        '${game.width}×${game.height}',
      ].join(' · '),
      trailing: myTurn
          ? Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
            )
          : null,
      onTap: () => pushFullScreen<void>(context, OnlineGameScreen(gameId: game.id)),
    );
  }
}

/// Your record and your finished games.
class _HistoryPane extends ConsumerWidget {
  const _HistoryPane({required this.user, super.key});

  final OgsUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = user;
    if (me == null) return const _SignInNote('Sign in to see your record and finished games.');
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final player = ref.watch(playerProvider(me.id)).value;
    final stats = ref.watch(playerStatsProvider(me.id)).value;
    final recent = ref.watch(playerGamesProvider(me.id));
    Widget stat(String label, String value, {bool first = false}) => Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          border: first ? null : Border(left: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(value, maxLines: 1, style: theme.textTheme.headlineSmall),
          ],
        ),
      ),
    );
    final losses = stats == null ? null : (stats.games - stats.wins).clamp(0, stats.games);
    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                stat('Rank', (player ?? me).rankLabel, first: true),
                stat('Rating', player?.rating == null ? '–' : '${player!.rating!.round()}'),
                stat('Won', stats == null ? '…' : '${stats.wins}–$losses'),
              ],
            ),
          ),
        ),
        SectionLabel(
          'Finished games',
          trailing: TextButton(
            onPressed: () => pushFullScreen<void>(context, const MyGamesScreen()),
            child: const Text('See all'),
          ),
        ),
        switch (recent) {
          AsyncData(:final value) when value.isEmpty => const _Note('No finished games yet.'),
          AsyncData(:final value) => Group(
            children: [for (final g in value.take(20)) _FinishedRow(game: g, userId: me.id)],
          ),
          AsyncError() => const _Note('Could not load your games.'),
          _ => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
        },
      ],
    );
  }
}

class _FinishedRow extends StatelessWidget {
  const _FinishedRow({required this.game, required this.userId});

  final PlayerGame game;
  final int userId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final opponent = game.black.id == userId ? game.white : game.black;
    final mine = game.black.id == userId ? StoneColor.black : StoneColor.white;
    final winner = game.winner;
    final (Color bg, Color fg, String letter) = switch (winner) {
      null => (scheme.surfaceContainerHigh, scheme.onSurfaceVariant, '–'),
      final w when w == mine => (scheme.secondaryContainer, scheme.secondary, 'W'),
      _ => (scheme.errorContainer, scheme.error, 'L'),
    };
    return GroupRow(
      leading: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Text(letter, style: theme.textTheme.titleSmall?.copyWith(color: fg)),
      ),
      title: 'vs ${opponent.username} ${opponent.rankLabel}'.trim(),
      subtitle: [
        '${game.width}×${game.height}',
        if (game.outcome case final o? when o.isNotEmpty) o,
        if (game.ended case final e?) _ago(context, e),
      ].join(' · '),
      onTap: () => pushFullScreen<void>(context, OnlineGameScreen(gameId: game.id)),
    );
  }
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

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

class _SignInNote extends StatelessWidget {
  const _SignInNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
    children: [
      Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 14),
      FilledButton(onPressed: () => showSignIn(context), child: const Text('Sign in')),
    ],
  );
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

/// Your avatar (or a person icon when signed out) on the accent color.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({required this.user, required this.onTap, this.size = 34, super.key});

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
          ? Icon(Icons.person_outline_rounded, size: size * 0.55, color: scheme.onPrimary)
          : Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w600,
                fontSize: size * 0.44,
              ),
            ),
    );
    return Semantics(
      button: true,
      label: user == null ? 'Account' : name,
      excludeSemantics: true,
      child: Tooltip(
        message: user == null ? 'Account' : name,
        child: GestureDetector(
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
