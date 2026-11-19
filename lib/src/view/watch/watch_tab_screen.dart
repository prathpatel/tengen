import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/ogs/chat_rooms.dart';
import 'package:tengen/src/model/ogs/game_data.dart';
import 'package:tengen/src/model/ogs/ogs_repository.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/chat/chat_room_screen.dart';
import 'package:tengen/src/view/chat/chat_rooms_screen.dart';
import 'package:tengen/src/view/online_game/online_game_screen.dart';
import 'package:tengen/src/widgets/game_tiles.dart';
import 'package:tengen/src/widgets/list_section.dart';

/// Live and correspondence games on online-go.com, and the chat rooms.
class WatchTabScreen extends ConsumerWidget {
  const WatchTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveGamesProvider(GameListKind.live));
    final corr = ref.watch(liveGamesProvider(GameListKind.correspondence));

    Widget games(AsyncValue<List<GameListEntry>> games, GameListKind kind, int count) =>
        switch (games) {
          AsyncData(:final value) when value.isEmpty => const ListTile(
            title: Text('No games right now'),
          ),
          AsyncData(:final value) => CardSection(
            children: [
              for (final entry in value.take(count))
                LiveGameTile(
                  entry: entry,
                  onTap: () => pushFullScreen<void>(context, OnlineGameScreen(gameId: entry.id)),
                ),
            ],
          ),
          AsyncError() => ListTile(
            leading: const Icon(Icons.cloud_off),
            title: const Text('Could not load the games'),
            trailing: TextButton(
              onPressed: () => ref.invalidate(liveGamesProvider(kind)),
              child: const Text('Retry'),
            ),
          ),
          _ => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        };

    return Scaffold(
      appBar: AppBar(title: const Text('Watch')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(liveGamesProvider(GameListKind.live))
            ..invalidate(liveGamesProvider(GameListKind.correspondence));
          await ref
              .read(liveGamesProvider(GameListKind.live).future)
              .catchError((_) => <GameListEntry>[]);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            SectionHeader(
              'Top live games',
              onMore: () => pushInTab<void>(context, const GameListScreen(kind: GameListKind.live)),
            ),
            games(live, GameListKind.live, 5),
            SectionHeader(
              'Chat rooms',
              onMore: () => pushInTab<void>(context, const ChatRoomsScreen()),
            ),
            CardSection(
              children: [
                for (final room in globalChatRooms.take(4))
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    leading: Text(room.flag, style: const TextStyle(fontSize: 24)),
                    title: Text(room.name),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => pushInTab<void>(context, ChatRoomScreen(room: room)),
                  ),
              ],
            ),
            SectionHeader(
              'Correspondence',
              onMore: () =>
                  pushInTab<void>(context, const GameListScreen(kind: GameListKind.correspondence)),
            ),
            games(corr, GameListKind.correspondence, 3),
          ],
        ),
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
      appBar: AppBar(title: Text('${kind.label} games')),
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
