import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/constants.dart';
import 'package:tengen/src/model/auth/auth_controller.dart';
import 'package:tengen/src/model/offline_game/offline_game_controller.dart';
import 'package:tengen/src/model/ogs/game_data.dart';
import 'package:tengen/src/model/ogs/ogs_repository.dart';
import 'package:tengen/src/model/ogs/ogs_socket_provider.dart';
import 'package:tengen/src/model/ogs/user.dart';
import 'package:tengen/src/network/socket.dart';
import 'package:tengen/src/tab_scaffold.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/auth/sign_in_screen.dart';
import 'package:tengen/src/view/offline_game/offline_game_screen.dart';
import 'package:tengen/src/view/online_game/online_game_screen.dart';
import 'package:tengen/src/view/user/player_screen.dart';
import 'package:tengen/src/widgets/game_tiles.dart';

class HomeTabScreen extends ConsumerWidget {
  const HomeTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final status = ref.watch(socketStatusProvider).value;
    final signedIn = auth.value?.isSignedIn ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text(kAppName),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Tooltip(
              message: status == SocketStatus.connected
                  ? 'Connected to $kOgsHost'
                  : 'Connecting to $kOgsHost…',
              child: Icon(
                Icons.circle,
                size: 12,
                color: status == SocketStatus.connected ? Colors.green : Colors.orange,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activeGamesProvider);
          await ref.read(activeGamesProvider.future).catchError((_) => <PlayerGame>[]);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            switch (auth) {
              AsyncData(:final value) when value.isSignedIn => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileCard(user: value.user),
                  _ActiveGames(userId: value.user.id),
                ],
              ),
              AsyncLoading() => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              AsyncError() => Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_off),
                  title: const Text('Could not reach online-go.com'),
                  subtitle: const Text('You can still play offline.'),
                  trailing: TextButton(
                    onPressed: () => ref.invalidate(authProvider),
                    child: const Text('Retry'),
                  ),
                ),
              ),
              _ => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Play Go online', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      const Text(
                        'Sign in with your online-go.com account to play rated games, '
                        'follow your correspondence games and find opponents.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.login),
                        label: const Text('Sign in'),
                        onPressed: () => pushFullScreen<void>(context, const SignInScreen()),
                      ),
                    ],
                  ),
                ),
              ),
            },
            const _SectionTitle('Quick start'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.75,
                children: [
                  _QuickTile(
                    icon: Icons.smart_toy_outlined,
                    title: 'Play the computer',
                    subtitle: '9×9 · you play black',
                    onTap: () => pushFullScreen<void>(
                      context,
                      const OfflineGameScreen(setup: OfflineGameSetup()),
                    ),
                  ),
                  _QuickTile(
                    icon: Icons.people_outline,
                    title: 'Pass and play',
                    subtitle: '13×13 on this device',
                    onTap: () => pushFullScreen<void>(
                      context,
                      const OfflineGameScreen(
                        setup: OfflineGameSetup(opponent: OfflineOpponent.human, size: 13),
                      ),
                    ),
                  ),
                  _QuickTile(
                    icon: Icons.bolt_outlined,
                    title: 'Play online',
                    subtitle: signedIn ? 'Find an opponent' : 'Sign in first',
                    onTap: () => ref.read(currentTabProvider.notifier).current = BottomTab.play,
                  ),
                  _QuickTile(
                    icon: Icons.live_tv_outlined,
                    title: 'Watch',
                    subtitle: 'Top live games',
                    onTap: () => ref.read(currentTabProvider.notifier).current = BottomTab.watch,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

class _ActiveGames extends ConsumerWidget {
  const _ActiveGames({required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final games = ref.watch(activeGamesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Your games'),
        switch (games) {
          AsyncData(:final value) when value.isEmpty => const ListTile(
            title: Text('No ongoing games'),
            subtitle: Text('Start one from the Play tab.'),
          ),
          AsyncData(:final value) => Column(
            children: [
              for (final g in [
                ...value.where((g) => g.isTurnOf(userId)),
                ...value.where((g) => !g.isTurnOf(userId)),
              ])
                ListTile(
                  title: PlayersTitle(black: g.black, white: g.white),
                  subtitle: Text('${g.width}×${g.height}${g.name.isEmpty ? '' : ' · ${g.name}'}'),
                  trailing: g.isTurnOf(userId)
                      ? Chip(
                          label: const Text('Your move'),
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        )
                      : null,
                  onTap: () => pushFullScreen<void>(context, OnlineGameScreen(gameId: g.id)),
                ),
            ],
          ),
          AsyncError(:final error) => ListTile(
            leading: const Icon(Icons.error_outline),
            title: const Text('Could not load your games'),
            subtitle: Text('$error'),
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

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});

  final OgsUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rank = user.rankLabel;
    return Card(
      elevation: 0,
      color: scheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => pushFullScreen<void>(context, PlayerScreen(playerId: user.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: scheme.primary,
                foregroundImage: user.iconUrl != null ? NetworkImage(user.iconUrl!) : null,
                child: Text(
                  user.username.characters.first.toUpperCase(),
                  style: theme.textTheme.titleLarge?.copyWith(color: scheme.onPrimary),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      rank.isEmpty ? 'online-go.com' : 'Rank $rank · online-go.com',
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: scheme.secondaryContainer, shape: BoxShape.circle),
                child: Icon(icon, color: scheme.onSecondaryContainer),
              ),
              const Spacer(),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
