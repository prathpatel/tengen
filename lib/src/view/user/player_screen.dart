import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/ogs/ogs_repository.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/online_game/online_game_screen.dart';
import 'package:tengen/src/widgets/game_tiles.dart';

/// A player's profile and recent games.
class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({required this.playerId, super.key});

  final int playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider(playerId));
    final games = ref.watch(playerGamesProvider(playerId));
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(player.value?.username ?? 'Player')),
      body: ListView(
        children: [
          switch (player) {
            AsyncData(:final value) => ListTile(
              leading: CircleAvatar(
                backgroundImage: value.iconUrl != null ? NetworkImage(value.iconUrl!) : null,
                child: value.iconUrl == null ? Text(value.username.characters.first) : null,
              ),
              title: Text(value.displayName, style: theme.textTheme.titleLarge),
              subtitle: Text(
                [
                  if (value.rating != null) 'Rating ${value.rating!.round()}',
                  if (value.country != null && value.country != 'un') value.country!.toUpperCase(),
                  if (value.isBot) 'Bot',
                ].join(' · '),
              ),
            ),
            AsyncError(:final error) => ListTile(title: Text('Could not load the player: $error')),
            _ => const LinearProgressIndicator(),
          },
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Recent games',
              style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
          switch (games) {
            AsyncData(:final value) when value.isEmpty => const ListTile(title: Text('No games')),
            AsyncData(:final value) => Column(
              children: [
                for (final g in value)
                  ListTile(
                    title: PlayersTitle(black: g.black, white: g.white, winner: g.winner),
                    subtitle: Text(
                      [
                        '${g.width}×${g.height}',
                        if (g.outcome != null && g.outcome!.isNotEmpty) g.outcome!,
                        if (g.ended != null)
                          MaterialLocalizations.of(context).formatShortDate(g.ended!),
                      ].join(' · '),
                    ),
                    onTap: () => pushFullScreen<void>(context, OnlineGameScreen(gameId: g.id)),
                  ),
              ],
            ),
            AsyncError(:final error) => ListTile(title: Text('Could not load the games: $error')),
            _ => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          },
        ],
      ),
    );
  }
}
