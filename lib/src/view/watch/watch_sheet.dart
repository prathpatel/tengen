import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/ogs/chat_rooms.dart';
import 'package:tengen/src/model/ogs/game_data.dart';
import 'package:tengen/src/model/ogs/game_preview.dart';
import 'package:tengen/src/model/ogs/ogs_repository.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/chat/chat_room_screen.dart';
import 'package:tengen/src/view/chat/chat_rooms_screen.dart';
import 'package:tengen/src/view/online_game/online_game_screen.dart';
import 'package:tengen/src/widgets/board_thumbnail.dart';
import 'package:tengen/src/widgets/game_tiles.dart';
import 'package:tengen/src/widgets/segmented_choice.dart';
import 'package:tengen/src/widgets/ui.dart';

/// The top games being played on OGS, with their boards, and the chat rooms, in a sheet over
/// the home screen.
class WatchSheet extends ConsumerStatefulWidget {
  const WatchSheet({this.page = false, super.key});

  /// Shown as a tab of the app rather than in a sheet: clear of the status bar and of the
  /// floating tab bar.
  final bool page;

  @override
  ConsumerState<WatchSheet> createState() => _WatchSheetState();
}

class _WatchSheetState extends ConsumerState<WatchSheet> {
  GameListKind _kind = GameListKind.live;

  /// The boards shown; each one follows its game.
  static const _shown = 6;

  @override
  Widget build(BuildContext context) {
    final games = ref.watch(liveGamesProvider(_kind));
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(liveGamesProvider(_kind));
        await ref.read(liveGamesProvider(_kind).future).catchError((_) => <GameListEntry>[]);
      },
      child: ListView(
        padding: tabPagePadding(context, page: widget.page),
        children: [
          SheetTitle(
            'Watch',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: scheme.error, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  'Updated live',
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 20, 14),
            child: SegmentedChoice<GameListKind>(
              choices: const [
                Choice(GameListKind.live, 'Top live'),
                Choice(GameListKind.correspondence, 'Correspondence'),
              ],
              selected: _kind,
              onChanged: (k) => setState(() => _kind = k),
            ),
          ),
          switch (games) {
            AsyncData(:final value) when value.isEmpty => const ListTile(
              title: Text('No games right now'),
            ),
            AsyncData(:final value) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 600 ? 3 : 2;
                  final width = (constraints.maxWidth - 14 * (columns - 1)) / columns;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 18,
                    children: [
                      for (final g in value.take(_shown))
                        SizedBox(
                          width: width,
                          child: _GameCard(entry: g, size: width),
                        ),
                    ],
                  );
                },
              ),
            ),
            AsyncError() => ListTile(
              leading: const Icon(Icons.cloud_off),
              title: const Text('Could not load the games'),
              trailing: TextButton(
                onPressed: () => ref.invalidate(liveGamesProvider(_kind)),
                child: const Text('Retry'),
              ),
            ),
            _ => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          },
          if ((games.value?.length ?? 0) > _shown)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 20, 0),
              child: OutlinedButton(
                onPressed: () => pushFullScreen<void>(context, GameListScreen(kind: _kind)),
                child: Text('All ${games.value!.length} games'),
              ),
            ),
          SectionLabel(
            'Chat rooms',
            padding: const EdgeInsets.fromLTRB(16, 26, 12, 6),
            trailing: TextButton(
              onPressed: () => pushFullScreen<void>(context, const ChatRoomsScreen()),
              child: const Text('All rooms'),
            ),
          ),
          for (final room in globalChatRooms.take(4))
            InkWell(
              onTap: () => pushFullScreen<void>(context, ChatRoomScreen(room: room)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        room.country?.toUpperCase() ??
                            (room.name.toLowerCase() == 'help' ? '?' : room.name[0].toUpperCase()),
                        style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Text(room.name, style: theme.textTheme.titleMedium)),
                    Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A game being played: its board, following the moves, and the players.
class _GameCard extends ConsumerWidget {
  const _GameCard({required this.entry, required this.size});

  final GameListEntry entry;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final game = ref.watch(gamePreviewProvider(entry.id)).value;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => pushFullScreen<void>(context, OnlineGameScreen(gameId: entry.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BoardThumbnail(
            board: game?.board ?? Board.empty(entry.width, entry.height),
            size: size,
            lastMove: game?.position.lastMove?.point,
          ),
          const SizedBox(height: 8),
          Text(
            '${entry.black.username} vs ${entry.white.username}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
          Text(
            [
              entry.black.rankLabel,
              entry.white.rankLabel,
              'move ${game?.moveCount ?? entry.moveNumber}',
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// The full list of ongoing public games of one kind.
class GameListScreen extends ConsumerWidget {
  const GameListScreen({required this.kind, super.key});

  final GameListKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final games = ref.watch(liveGamesProvider(kind));
    return Scaffold(
      appBar: TopBar(title: '${kind.label} games'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(liveGamesProvider(kind));
          await ref.read(liveGamesProvider(kind).future).catchError((_) => <GameListEntry>[]);
        },
        child: switch (games) {
          AsyncData(:final value) => ListView.separated(
            itemCount: value.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
            itemBuilder: (context, i) => LiveGameTile(
              entry: value[i],
              onTap: () => pushFullScreen<void>(context, OnlineGameScreen(gameId: value[i].id)),
            ),
          ),
          AsyncError(:final error) => ListView(
            children: [ListTile(title: Text('Could not load the games: $error'))],
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}
