import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/auth/auth_controller.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/offline_game/offline_game_controller.dart';
import 'package:tengen/src/model/ogs/game_data.dart';
import 'package:tengen/src/model/ogs/ogs_repository.dart';
import 'package:tengen/src/model/ogs/ogs_socket_provider.dart';
import 'package:tengen/src/model/ogs/user.dart';
import 'package:tengen/src/model/online_game/automatch_controller.dart';
import 'package:tengen/src/network/socket.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/auth/sign_in_screen.dart';
import 'package:tengen/src/view/offline_game/offline_game_screen.dart';
import 'package:tengen/src/view/online_game/online_game_screen.dart';
import 'package:tengen/src/view/play/play_screen.dart';
import 'package:tengen/src/view/user/player_screen.dart';
import 'package:tengen/src/widgets/board_thumbnail.dart';
import 'package:tengen/src/widgets/list_section.dart';
import 'package:tengen/src/widgets/player_bar.dart';

/// The OGS quick match grid: speeds in rows, board sizes in columns.
const _quickSizes = [9, 13, 19];

String _greeting(DateTime now) => switch (now.hour) {
  < 5 => 'Good night',
  < 12 => 'Good morning',
  < 18 => 'Good afternoon',
  _ => 'Good evening',
};

class HomeTabScreen extends ConsumerWidget {
  const HomeTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.value?.user;
    final signedIn = auth.value?.isSignedIn ?? false;
    final connected = ref.watch(socketStatusProvider).value == SocketStatus.connected;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Text(
          signedIn ? '${_greeting(DateTime.now())}, ${user!.username}' : 'Welcome to Tengen',
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: signedIn
                ? GestureDetector(
                    onTap: () => pushInTab<void>(context, PlayerScreen(playerId: user.id)),
                    child: Badge(
                      smallSize: 10,
                      backgroundColor: connected ? Colors.green : Colors.orange,
                      alignment: AlignmentDirectional.bottomEnd,
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        foregroundImage: user!.iconUrl != null ? NetworkImage(user.iconUrl!) : null,
                        child: Text(user.username.characters.first.toUpperCase()),
                      ),
                    ),
                  )
                : TextButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in'),
                    onPressed: () => pushFullScreen<void>(context, const SignInScreen()),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => pushFullScreen<void>(context, const PlayScreen()),
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Play'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(activeGamesProvider)
            ..invalidate(authProvider);
          if (user != null && signedIn) {
            ref
              ..invalidate(playerProvider(user.id))
              ..invalidate(playerGamesProvider(user.id));
          }
          await ref.read(activeGamesProvider.future).catchError((_) => <PlayerGame>[]);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            if (auth is AsyncError)
              const _Notice(
                icon: Icons.cloud_off,
                text: 'Could not reach online-go.com. You can still play offline.',
              ),
            if (signedIn) ...[
              _StatCards(userId: user!.id),
              _OngoingGames(userId: user.id),
            ] else if (auth is AsyncData)
              const _SignInCard(),
            const SectionHeader('Quick pairing'),
            _QuickPairingGrid(signedIn: signedIn),
            if (signedIn) _RecentGames(userId: user!.id),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _SignInCard extends StatelessWidget {
  const _SignInCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Play Go online', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Sign in with your online-go.com account to play rated games, follow your games '
            'and chat.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              FilledButton(
                onPressed: () => pushFullScreen<void>(context, const SignInScreen()),
                child: const Text('Sign in'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => pushFullScreen<void>(
                  context,
                  const OfflineGameScreen(setup: OfflineGameSetup()),
                ),
                child: const Text('Play the computer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Rating, rank and recent results, like the rating cards of the lichess home.
class _StatCards extends ConsumerWidget {
  const _StatCards({required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider(userId)).value;
    final games = ref.watch(playerGamesProvider(userId)).value;
    final wins = games?.where((g) => g.winner != null && g.winner == _colorIn(g, userId)).length;
    final losses = games?.where((g) => g.winner != null && g.winner != _colorIn(g, userId)).length;
    final dev = player?.deviation;
    final provisional = dev != null && dev >= provisionalDeviation;

    return SizedBox(
      height: 124,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        children: [
          _StatCard(
            title: 'Rating',
            icon: Icons.show_chart,
            value: player?.rating == null
                ? '–'
                : '${player!.rating!.round()}${provisional ? '?' : ''}',
          ),
          _StatCard(
            title: 'Rank',
            icon: Icons.military_tech_outlined,
            value: player == null ? '–' : player.rankLabel.ifEmpty('–'),
          ),
          _StatCard(
            title: 'Last ${games?.length ?? 0} games',
            icon: Icons.emoji_events_outlined,
            value: wins == null ? '–' : '$wins W · $losses L',
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.icon, required this.value});

  final String title;
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 124,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: theme.textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Icon(icon, color: theme.colorScheme.onSurfaceVariant),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

StoneColor? _colorIn(PlayerGame g, int userId) =>
    g.black.id == userId ? StoneColor.black : (g.white.id == userId ? StoneColor.white : null);

/// The ongoing games, as cards with a preview of the board.
class _OngoingGames extends ConsumerWidget {
  const _OngoingGames({required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final games = ref.watch(activeGamesProvider).value;
    if (games == null || games.isEmpty) return const SizedBox.shrink();
    final sorted = [
      ...games.where((g) => g.isTurnOf(userId)),
      ...games.where((g) => !g.isTurnOf(userId)),
    ];
    final theme = Theme.of(context);
    final waiting = sorted.where((g) => g.isTurnOf(userId)).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          waiting > 0
              ? 'Your turn in $waiting ${waiting == 1 ? 'game' : 'games'}'
              : 'Ongoing games',
        ),
        SizedBox(
          height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final g = sorted[i];
              final mine = _colorIn(g, userId);
              final opponent = mine == StoneColor.black ? g.white : g.black;
              final game = g.data?.buildGame();
              final myTurn = g.isTurnOf(userId);
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => pushFullScreen<void>(context, OnlineGameScreen(gameId: g.id)),
                child: SizedBox(
                  width: 136,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (game != null)
                        BoardThumbnail(
                          board: game.board,
                          size: 136,
                          lastMove: game.position.lastMove?.point,
                        )
                      else
                        const SizedBox.square(dimension: 136),
                      const SizedBox(height: 6),
                      Text(
                        opponent.username,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        myTurn ? 'Your move' : 'Waiting',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: myTurn
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: myTurn ? FontWeight.w700 : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _QuickPairingGrid extends ConsumerWidget {
  const _QuickPairingGrid({required this.signedIn});

  final bool signedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final searching = ref.watch(automatchProvider);
    Widget tile({
      required String top,
      required String middle,
      required String bottom,
      required VoidCallback onTap,
      bool selected = false,
    }) => Material(
      color: selected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          // Scales down rather than overflowing with large fonts or narrow screens.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(top, style: theme.textTheme.titleLarge, maxLines: 1),
                Text(middle, style: theme.textTheme.titleSmall, maxLines: 1),
                Text(
                  bottom,
                  maxLines: 1,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final saved = ref.watch(automatchSettingsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.3,
        children: [
          for (final speed in GameSpeed.values)
            for (final size in _quickSizes)
              Builder(
                builder: (context) {
                  final preset = saved.copyWith(size: size, speed: speed);
                  return tile(
                    top: '$size×$size',
                    middle: speed.shortLabel,
                    bottom: preset.timeLabel,
                    selected:
                        searching is AutomatchSearching &&
                        searching.settings.size == size &&
                        searching.settings.speed == speed,
                    onTap: () {
                      if (!signedIn) {
                        pushFullScreen<void>(context, const SignInScreen());
                      } else if (searching is AutomatchSearching) {
                        ref.read(automatchProvider.notifier).cancel();
                      } else {
                        ref.read(automatchSettingsProvider.notifier).update(preset);
                        ref.read(automatchProvider.notifier).find(preset);
                      }
                    },
                  );
                },
              ),
        ],
      ),
    );
  }
}

/// The last finished games of the player.
class _RecentGames extends ConsumerWidget {
  const _RecentGames({required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final games = ref.watch(playerGamesProvider(userId));
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Recent games',
          onMore: () => pushInTab<void>(context, PlayerScreen(playerId: userId)),
        ),
        switch (games) {
          AsyncData(:final value) when value.isEmpty => const ListTile(
            title: Text('No finished games yet'),
          ),
          AsyncData(:final value) => Column(
            children: [
              for (final g in value.take(10))
                Builder(
                  builder: (context) {
                    final mine = _colorIn(g, userId);
                    final opponent = mine == StoneColor.black ? g.white : g.black;
                    final won = g.winner != null && g.winner == mine;
                    final lost = g.winner != null && g.winner != mine;
                    final (label, color) = won
                        ? ('W', Colors.green.shade600)
                        : lost
                        ? ('L', scheme.error)
                        : ('–', scheme.outline);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                      leading: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          label,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          if (mine != null) ...[
                            StoneIcon(mine, size: 12),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text('vs ${opponent.username}', overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            opponent.rankLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        [
                          '${g.width}×${g.height}',
                          if (g.outcome != null && g.outcome!.isNotEmpty) g.outcome!,
                          if (g.ended != null)
                            MaterialLocalizations.of(context).formatShortDate(g.ended!.toLocal()),
                        ].join(' · '),
                      ),
                      onTap: () => pushFullScreen<void>(context, OnlineGameScreen(gameId: g.id)),
                    );
                  },
                ),
            ],
          ),
          AsyncError() => const ListTile(
            leading: Icon(Icons.error_outline),
            title: Text('Could not load your games'),
          ),
          _ => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        },
      ],
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
