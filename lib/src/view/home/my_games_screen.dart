import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/auth/auth_controller.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/ogs/game_data.dart';
import 'package:tengen/src/model/ogs/ogs_repository.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/online_game/online_game_screen.dart';
import 'package:tengen/src/widgets/board_thumbnail.dart';
import 'package:tengen/src/widgets/game_result_tag.dart';
import 'package:tengen/src/widgets/ui.dart';

/// Your ongoing games on OGS, the ones waiting for your move first, then your last results.
class MyGamesScreen extends ConsumerWidget {
  const MyGamesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value?.user;
    if (user == null) return const Scaffold(appBar: TopBar(title: 'My games'));
    final active = ref.watch(activeGamesProvider);
    final recent = ref.watch(playerGamesProvider(user.id));
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    StoneColor? colorIn(PlayerGame g) => g.black.id == user.id
        ? StoneColor.black
        : (g.white.id == user.id ? StoneColor.white : null);

    Widget ongoing(PlayerGame g) {
      final opponent = colorIn(g) == StoneColor.black ? g.white : g.black;
      final game = g.data?.buildGameCached();
      final myTurn = g.isTurnOf(user.id);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: SoftCard(
          padding: const EdgeInsets.all(12),
          onTap: () => pushFullScreen<void>(context, OnlineGameScreen(gameId: g.id)),
          child: Row(
            children: [
              if (game != null)
                BoardThumbnail(board: game.board, size: 72, lastMove: game.position.lastMove?.point)
              else
                const SizedBox.square(dimension: 72),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'vs ${opponent.username} ${opponent.rankLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        '${g.width}×${g.height}',
                        if (game != null) 'move ${game.moveCount}',
                      ].join(' · '),
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Tag(
                myTurn ? 'Your move' : 'Waiting',
                background: myTurn ? scheme.primary : null,
                foreground: myTurn ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: const TopBar(title: 'My games'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(activeGamesProvider)
            ..invalidate(playerGamesProvider(user.id));
          await ref.read(activeGamesProvider.future).catchError((_) => <PlayerGame>[]);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            switch (active) {
              AsyncData(:final value) when value.isEmpty => const SectionLabel('No ongoing games'),
              AsyncData(:final value) => Column(
                children: [
                  SectionLabel(
                    value.any((g) => g.isTurnOf(user.id))
                        ? 'Your move · ${value.where((g) => g.isTurnOf(user.id)).length}'
                        : 'Ongoing',
                  ),
                  for (final g in [
                    ...value.where((g) => g.isTurnOf(user.id)),
                    ...value.where((g) => !g.isTurnOf(user.id)),
                  ])
                    ongoing(g),
                ],
              ),
              AsyncError() => const ListTile(title: Text('Could not load your games')),
              _ => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            },
            const SectionLabel('Recent games'),
            switch (recent) {
              AsyncData(:final value) when value.isEmpty => const ListTile(
                title: Text('No finished games yet'),
              ),
              AsyncData(:final value) => Column(
                children: [
                  for (final g in value.take(20))
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                      title: Text(
                        'vs ${(colorIn(g) == StoneColor.black ? g.white : g.black).username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          '${g.width}×${g.height}',
                          if (g.ended != null)
                            MaterialLocalizations.of(context).formatShortDate(g.ended!.toLocal()),
                        ].join(' · '),
                      ),
                      trailing: GameResultTag(game: g, playerId: user.id),
                      onTap: () => pushFullScreen<void>(context, OnlineGameScreen(gameId: g.id)),
                    ),
                ],
              ),
              AsyncError() => const ListTile(title: Text('Could not load your games')),
              _ => const SizedBox.shrink(),
            },
          ],
        ),
      ),
    );
  }
}
